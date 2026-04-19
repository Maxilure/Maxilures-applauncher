#!/bin/bash

# sys_usage.sh - File Exchange Version
# Outputs JSON to /tmp/quickshell_sys_metrics for Quickshell to read

CACHE_FILE="/tmp/quickshell_sys_usage"
METRICS_FILE="/tmp/quickshell_sys_metrics"
DEBUG_LOG="/tmp/qs_sys_debug.log"

exec 2>> "$DEBUG_LOG"

# 1. CPU
read -r _ u n s i io irq sirq st _ < /proc/stat
total=$((u + n + s + i + io + irq + sirq + st))
idle=$((i + io))

if [ -f "$CACHE_FILE" ]; then
    read -r last_total last_idle < "$CACHE_FILE"
    diff_total=$((total - last_total))
    diff_idle=$((idle - last_idle))
    
    if [ "$diff_total" -gt 0 ]; then
        CPU=$((100 * (diff_total - diff_idle) / diff_total))
    else
        CPU=0
    fi
else
    CPU=0
fi
echo "$total $idle" > "$CACHE_FILE"

# 2. RAM
RAM=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}')

# 3. GPU
GPU=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0)

# 4. Final JSON output to FILE
# We use a temporary file and 'mv' to ensure the write is atomic
echo "{\"cpu\": ${CPU:-0}, \"ram\": ${RAM:-0}, \"gpu\": ${GPU:-0}}" > "${METRICS_FILE}.tmp"
mv "${METRICS_FILE}.tmp" "${METRICS_FILE}"
