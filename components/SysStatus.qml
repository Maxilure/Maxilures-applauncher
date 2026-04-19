import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Effects

Item {
    id: root
    width: sysRow.width
    height: 48
    
    property int cpu: 0
    property int ram: 0
    property int gpu: 0
    
    Process {
        id: usageFetcher
        command: ["/bin/bash", "/home/user/.config/quickshell/sys_usage.sh"]
        onExited: metricsFile.reload()
    }
    
    FileView {
        id: metricsFile
        path: "/tmp/quickshell_sys_metrics"
        onLoaded: {
            try {
                let content = (typeof text === "function") ? text() : text;
                if (content && content.trim().length > 0) {
                    let parsed = JSON.parse(content);
                    root.cpu = parsed.cpu;
                    root.ram = parsed.ram;
                    root.gpu = parsed.gpu;
                }
            } catch (e) {
                console.log("[SysStatus] Metrics Parse Error:", e);
            }
        }
    }
    
    Timer {
        id: pollTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: usageFetcher.running = true
    }
    
    Row {
        id: sysRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -7
        spacing: 0 // Spacing handled by unit widths
        
        // --- CPU ---
        Item {
            width: 90; height: 32; anchors.verticalCenter: parent.verticalCenter
            Row {
                anchors.centerIn: parent
                spacing: 8
                Item {
                    width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                    Image { id: cpuIconBase; anchors.fill: parent; sourceSize: Qt.size(40, 40); visible: false; source: "file:///home/user/.config/quickshell/assets/cpu-icon.svg" }
                    MultiEffect { anchors.fill: parent; source: cpuIconBase; colorization: 1.0; colorizationColor: Theme.primaryText }
                }
                Item {
                    width: 44; height: 24; anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.cpu + "%"
                        anchors.centerIn: parent
                        color: Theme.primaryText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold
                    }
                }
            }
        }
        
        // --- RAM ---
        Item {
            width: 90; height: 32; anchors.verticalCenter: parent.verticalCenter
            Row {
                anchors.centerIn: parent
                spacing: 8
                Item {
                    width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                    Image { id: ramIconBase; anchors.fill: parent; sourceSize: Qt.size(40, 40); visible: false; source: "file:///home/user/.config/quickshell/assets/ram-icon.svg" }
                    MultiEffect { anchors.fill: parent; source: ramIconBase; colorization: 1.0; colorizationColor: Theme.primaryText }
                }
                Item {
                    width: 44; height: 24; anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.ram + "%"
                        anchors.centerIn: parent
                        color: Theme.primaryText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold
                    }
                }
            }
        }
        
        // --- GPU ---
        Item {
            width: 90; height: 32; anchors.verticalCenter: parent.verticalCenter
            Row {
                anchors.centerIn: parent
                spacing: 8
                Item {
                    width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                    Image { id: gpuIconBase; anchors.fill: parent; sourceSize: Qt.size(40, 40); visible: false; source: "file:///home/user/.config/quickshell/assets/gpu-icon.svg" }
                    MultiEffect { anchors.fill: parent; source: gpuIconBase; colorization: 1.0; colorizationColor: Theme.primaryText }
                }
                Item {
                    width: 44; height: 24; anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.gpu + "%"
                        anchors.centerIn: parent
                        color: Theme.primaryText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
