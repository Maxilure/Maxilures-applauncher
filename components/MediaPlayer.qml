import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick.Effects

Item {
    id: root
    
    // Universal Proximity Interface (Linked from LauncherWindow)
    property real relativeMouseX: -1000
    
    // --- RIPPLE STATE ---
    property real rippleX: 0
    property real rippleY: 0
    property real rippleProgress: 0.0
    property real maxRadius: 0
    property real shimmerTime: 0.0
    
    NumberAnimation on shimmerTime { from: 0.0; to: 1.0; duration: 3000; loops: Animation.Infinite }
    
    // --- TRANSITION STATE ---
    property int swipeDirection: 0 // -1: prev, 1: next
    
    property string oldTitle: ""
    property string oldArtist: ""
    property string oldArt: ""
    
    // Animation driver properties
    property real mainOffset: 0
    property real oldOffset: 0
    property real mainOpacity: 1
    property real oldOpacity: 0
    
    function triggerSwipe(dir) {
        if (!activePlayer) return;

        // Snapshot old state
        oldTitle = activePlayer.trackTitle || "No Title"
        oldArtist = activePlayer.trackArtist || ""
        oldArt = activePlayer.trackArtUrl || ""
        
        root.swipeDirection = dir;
        
        if (dir === 1) {
            if (activePlayer.canGoNext) activePlayer.next();
            else root.swipeDirection = 0; // Cancel if not allowed
        } else {
            if (activePlayer.canGoPrevious) activePlayer.previous();
            else root.swipeDirection = 0; // Cancel if not allowed
        }
        // Animation now handled by property change connections
    }

    Connections {
        target: Theme
        function onColorExtractionChanged() {
            if (Theme._loadedOnce && Theme.colorExtraction && activePlayer && activePlayer.trackArtUrl) {
                root.extractColor(activePlayer.trackArtUrl);
            }
        }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            if (root.swipeDirection !== 0 && root.oldTitle !== root.activePlayer.trackTitle) {
                swipeAnim.restart();
            } else {
                root.swipeDirection = 0; // Reset if no change
            }
        }
        
        function onTrackArtUrlChanged() {
            if (activePlayer && activePlayer.trackArtUrl && Theme._loadedOnce && Theme.colorExtraction) {
                root.extractColor(activePlayer.trackArtUrl);
            }
        }
    }

    Process {
        id: beatProbe
        command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
        running: Theme.launcherVisible && activePlayer && activePlayer.playbackStatus === Mpris.Playing && Theme.vizMode === 0
        
        onRunningChanged: {
            if (!running) {
                Theme.spectrum = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
                Theme.beatIntensity = 0;
            }
        }

        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                let clean = data.trim();
                if (clean.length === 0) return;
                
                let parts = clean.split(/[\s;\x00]+/);
                if (parts.length >= 36) {
                    let newSpec = [];
                    let bassTotal = 0;
                    for (let i = 0; i < 36; i++) {
                        let v = parseInt(parts[i]);
                        let val = Math.max(0.0, Math.min(1.0, (isNaN(v) ? 0 : v) / 100.0));
                        // Boost low-end sensitivity for visual pop
                        let boosted = Math.pow(val, 0.65);
                        newSpec.push(boosted);
                        if (i < 5) bassTotal += boosted; 
                    }
                    Theme.spectrum = newSpec;
                    Theme.beatIntensity = Math.pow(bassTotal / 5.0, 1.5);
                }
            }
        }
    }

    // --- CHAMELEON MODE (Color Extraction) ---
    Process {
        id: colorExtractor
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text || "";
                let lines = out.split("\n");
                let candidates = [];
                
                // UNIVERSAL PARSER: Matches (r,g,b), gray(v), or simply numeric clusters (V1,V2,V3)
                // Also detects if the output is 16-bit (0-65535) vs 8-bit (0-255)
                for (let line of lines) {
                    let match = line.match(/^\s*(\d+):.*?\(([^)]+)\)/); // Match count + parentheses content
                    if (match) {
                        let count = parseInt(match[1]);
                        let parts = match[2].split(",").map(p => parseFloat(p.trim()));
                        
                        // Handle Gray Scale images (will have only 1 part in some Magick versions)
                        if (parts.length === 1) parts = [parts[0], parts[0], parts[0]];
                        
                        if (parts.length >= 3) {
                            // Normalize 16-bit (Magick default for some PNGs/Grays) to 0.0-1.0
                            let norm = parts.map(p => p > 255 ? p / 65535 : p / 255);
                            candidates.push({ 
                                color: Qt.rgba(norm[0], norm[1], norm[2], 1.0),
                                count: count
                            });
                        }
                    }
                }
                
                if (candidates.length > 0) {
                    candidates.sort((a,b) => b.count - a.count);
                    let maxCount = candidates[0].count;

                    // GLOBAL SATURATION CHECK: Is the art collectively muted?
                    let topC = Math.min(5, candidates.length);
                    let totalS = 0; let totalW = 0;
                    for (let i = 0; i < topC; i++) {
                        totalS += candidates[i].color.hsvSaturation * candidates[i].count;
                        totalW += candidates[i].count;
                    }
                    let globalSat = totalS / totalW;
                    let isGloballyNeutral = globalSat < 0.18;

                    // GLOBAL ATMOSPHERE CHECK: Is this High-Key (White) or Dark-Mood (Black)?
                    let totalV = 0; let totalW2 = 0;
                    for (let i = 0; i < topC; i++) {
                        totalV += candidates[i].color.hsvValue * candidates[i].count;
                        totalW2 += candidates[i].count;
                    }
                    let globalVal = totalV / totalW2;
                    let isGloballyDark = globalVal < 0.25;
                    let isGloballyBright = globalVal > 0.70;

                    // ACCENT 1: CORE (The Primary Subject)
                    let best1 = candidates[0].color;
                    let maxScore1 = -1;
                    for (let i = 0; i < Math.min(15, candidates.length); i++) {
                        let c = candidates[i].color;
                        let dominance = candidates[i].count / maxCount;
                        
                        let isExtremeNeutral = (c.hsvValue > 0.92 && c.hsvSaturation < 0.15) || 
                                             (c.hsvValue < 0.04 && c.hsvSaturation < 0.15);
                                             
                        // DOMINANCE-LED NEUTRALITY: If a color is overwhelmingly frequent, it WINS.
                        let neutralPenalty = 1.0;
                        if (isExtremeNeutral) {
                            if (dominance > 0.7) neutralPenalty = 1.0; // Overwhelming background IS the theme.
                            else if (isGloballyBright && c.hsvValue > 0.9) neutralPenalty = 0.4;
                            else if (isGloballyDark && c.hsvValue < 0.1) neutralPenalty = 0.2;
                            else neutralPenalty = 0.01;
                        }
                        
                        let brightnessPenalty = (isGloballyDark && c.hsvValue > 0.7) ? 0.3 : 1.0;
                        
                        // SCORE RECALIBRATION: Dominance is now exponential. 
                        // If White is 90%, it will now beat a vibrant 5% subject.
                        let score = (c.hsvSaturation + 0.1) * (c.hsvValue * 0.4 + 0.6) * Math.pow(dominance + 1.0, 4) * neutralPenalty * brightnessPenalty;
                        
                        if (score > maxScore1) {
                            maxScore1 = score;
                            best1 = c;
                        }
                    }
                    
                    // ACCENT 2: HIGHLIGHT (Vibrant Offset)
                    let best2 = best1;
                    let maxScore2 = -1;
                    for (let i = 0; i < candidates.length; i++) {
                        let c = candidates[i].color;
                        let dominance = candidates[i].count / maxCount;
                        let hDiff = Math.abs(c.hsvHue - best1.hsvHue);
                        if (hDiff > 0.5) hDiff = 1.0 - hDiff;
                        
                        let isExtremeNeutral = (c.hsvValue > 0.95 && c.hsvSaturation < 0.05) || (c.hsvValue < 0.03);
                        let neutralPenalty = isExtremeNeutral ? 0.01 : 1.0;
                        
                        let dist = hDiff * 2.0 + Math.abs(c.hsvSaturation - best1.hsvSaturation) + Math.abs(c.hsvValue - best1.hsvValue);
                        let score = (c.hsvSaturation + 0.4) * (c.hsvValue + 0.1) * (dist + 0.1) * (dominance + 0.1) * neutralPenalty;
                        
                        if (score > maxScore2) {
                            maxScore2 = score;
                            best2 = c;
                        }
                    }
                    
                    // ACCENT 3: ATMOSPHERE (Ambient Depth)
                    let best3 = best1;
                    let maxScore3 = -1;
                    for (let i = 0; i < candidates.length; i++) {
                        let c = candidates[i].color;
                        let dominance = candidates[i].count / maxCount;
                        let d1 = Math.abs(c.hsvHue - best1.hsvHue); if (d1 > 0.5) d1 = 1.0 - d1;
                        let d2 = Math.abs(c.hsvHue - best2.hsvHue); if (d2 > 0.5) d2 = 1.0 - d2;
                        
                        let dist = d1 + d2;
                        // ADAPTIVE ATMOSPHERE: If high-key art, favor high-key environment colors.
                        let scoreFactor = isGloballyBright ? (c.hsvValue + 0.5) : (1.5 - c.hsvValue);
                        let score = scoreFactor * (c.hsvSaturation + 0.1) * (dominance + 0.5) * (dist + 0.1);
                        
                        if (score > maxScore3) {
                            maxScore3 = score;
                            best3 = c;
                        }
                    }
                    
                    // --- VIBE GUARD & NEUTRAL MODE ---
                    let isNeutral = isGloballyNeutral || best1.hsvSaturation < 0.18;
                    
                    let targetS = isNeutral ? best1.hsvSaturation : Math.max(0.40, best1.hsvSaturation);
                    let targetV = isNeutral ? Math.max(0.40, best1.hsvValue) : Math.max(0.60, best1.hsvValue);
                    
                    // --- EYE COMFORT CAP ---
                    // Lowering brightness ceiling for better "Dark Mode" integration.
                    if (targetV > 0.85) targetV = 0.85;
                    if (isNeutral && targetS < 0.04 && targetV > 0.75) targetS = 0.04; 
                    
                    if (Theme.colorExtraction) {
                        Theme.accent = Qt.hsva(best1.hsvHue, targetS, targetV, 1.0);
                        Theme.accent2 = Qt.hsva(best2.hsvHue, targetS, Math.max(0, targetV - 0.15), 1.0);
                        Theme.accent3 = Qt.hsva(best3.hsvHue, Math.max(0.2, targetS - 0.1), Math.max(0.1, targetV - 0.35), 1.0);
                    }
                } else {
                    // Fail-safe: If extraction fails entirely, reset to default neutral teal
                    Theme.accent = "#24708b";
                    Theme.accent2 = "#3a9fb6";
                    Theme.accent3 = "#1a4f5f";
                }
            }
        }
    }

    Timer {
        id: colorTimer
        interval: 150
        repeat: false
        property string pendingUrl: ""
        onTriggered: {
            if (!pendingUrl) return;
            let path = decodeURIComponent(pendingUrl.replace("file://", ""));
            // --- DOMINANT VIBRANCY EXTRACTION ---
            colorExtractor.command = ["sh", "-c", `magick "${path}" -resize 50x50 -gravity Center -crop 70%x70%+0+0 +dither -colors 16 -format "%c" histogram:info: | sort -nr`];
            colorExtractor.running = true;
        }
    }

    function extractColor(url) {
        colorExtractor.running = false; // Kill any current scan
        if (!url) {
            Theme.accent = "#24708b";
            Theme.accent2 = "#3a9fb6";
            return;
        }
        
        let urlStr = url.toString();
        colorTimer.pendingUrl = urlStr;
        colorTimer.restart(); // Debounce and recycle
    }

    // --- PLAYER FILTER LOGIC ---
    property var browserWhitelist: ["waterfox", "firefox", "chrome", "chromium", "brave", "mozilla"]
    
    function isAllowedPlayer(player) {
        if (!player) return false;
        let pName = (player.playerName || "").toLowerCase();
        let pId = (player.identity || "").toLowerCase();
        return browserWhitelist.some(allowed => pName.includes(allowed) || pId.includes(allowed));
    }

    property var allPlayers: {
        let players = Mpris.players.values;
        return players.filter(p => isAllowedPlayer(p));
    }
    
    property int currentPlayerIndex: 0
    property var activePlayer: (allPlayers && allPlayers.length > 0) ? allPlayers[Math.min(currentPlayerIndex, allPlayers.length - 1)] : null
    
    onActivePlayerChanged: {
        if (activePlayer && Theme._loadedOnce && Theme.colorExtraction) {
            root.extractColor(activePlayer.trackArtUrl);
        } else if (!activePlayer) {
            Theme.accent = "#24708b"; // Reset to default teal
            Theme.accent2 = "#3a9fb6";
            Theme.accent3 = "#1a4f5f";
        }
    }
    
    // --- PROXIMITY STATE ---
    property real hoverX: -1000

    // --- ANIMATIONS ---
    NumberAnimation {
        id: rippleAnim
        target: root; property: "rippleProgress"; from: 0.0; to: 1.0; duration: 800; easing.type: Easing.OutCubic
        onFinished: root.rippleProgress = 0.0
    }

    // THE KINETIC OFFSET ENGINE
    ParallelAnimation {
        id: swipeAnim
        
        // --- 1. ATOMIC RESET ---
        PropertyAction { target: atmosphericBackdrop; property: "opacity"; value: 0 }
        PropertyAction { target: oldAtmosphericBackdrop; property: "opacity"; value: 0.4 }
        PropertyAction { target: oldArtBox; property: "opacity"; value: 1.0 }
        PropertyAction { target: root; property: "oldOpacity"; value: 1.0 }
        PropertyAction { target: root; property: "mainOpacity"; value: 1.0 }
        PropertyAction { target: mainContent; property: "opacity"; value: 1.0 }
        
        // --- 2. THE TRANSITIONS ---
        // Aura Cross-Fade (STAGGERED Reveal)
        SequentialAnimation {
            PauseAnimation { duration: 500 }
            NumberAnimation { target: oldAtmosphericBackdrop; property: "opacity"; from: 0.4; to: 0; duration: 600; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 500 }
            NumberAnimation { target: atmosphericBackdrop; property: "opacity"; from: 0; to: 0.4; duration: 600; easing.type: Easing.InOutSine }
        }
        
        // Main Content (New data reveals behind immediately)
        NumberAnimation { target: root; property: "mainOffset"; from: root.swipeDirection * 150; to: 0; duration: 550; easing.type: Easing.OutQuart }
        
        // Old Content (Old metadata dissolves on top)
        NumberAnimation { target: root; property: "oldOpacity"; from: 1.0; to: 0; duration: 500; easing.type: Easing.InSine }
        NumberAnimation { target: root; property: "oldOffset"; from: 0; to: -root.swipeDirection * 150; duration: 500; easing.type: Easing.InSine }
        
        // Staggered Artbox Delay
        SequentialAnimation {
            PauseAnimation { duration: 500 } 
            NumberAnimation { target: oldArtBox; property: "opacity"; from: 1.0; to: 0; duration: 400; easing.type: Easing.InOutSine }
        }
        
        onFinished: root.swipeDirection = 0
    }

    function nextPlayer() { triggerSwipe(1) }
    function prevPlayer() { triggerSwipe(-1) }
    
    property bool hasPlayer: activePlayer !== null
    visible: hasPlayer
    height: hasPlayer ? 140 : 0
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    
    Rectangle {
        id: bgRect
        anchors.fill: parent
        anchors.topMargin: 8; anchors.bottomMargin: 8
        color: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.6)
        radius: Theme.borderRadius; clip: true
        
        // --- MASTER CLIPPING CONTAINER (Masks everything to the inner border) ---
        Item {
            anchors.fill: parent; anchors.margins: 3; clip: true

            // --- 1a. THE LIVING AURA ---
            Item {
                id: atmosphericBackdrop
                anchors.fill: parent
                opacity: 0.4
                property real bias: {

                    if (root.relativeMouseX < -900) return 0.5;
                    let centerOffset = root.relativeMouseX - (width / 2);
                    let normalized = centerOffset / 400; 
                    return Math.max(0.0, Math.min(1.0, 0.5 + normalized));
                }
                Behavior on bias { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                


                Item {
                    id: auraMask
                    anchors.fill: parent; layer.enabled: true; layer.smooth: true; visible: false
                    Rectangle { anchors.fill: parent; radius: Math.round(bgRect.radius - 3); color: "black" }
                }
                Image {
                    id: auraImage; anchors.fill: parent; anchors.horizontalCenterOffset: (atmosphericBackdrop.bias - 0.5) * 120 
                    source: activePlayer ? activePlayer.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; visible: false
                }
                MultiEffect {
                    anchors.fill: parent; source: auraImage; autoPaddingEnabled: false; blurEnabled: true; blur: 0.3; saturation: 0.5
                    brightness: {
                        let base = -0.4; let intensity = Math.abs(atmosphericBackdrop.bias - 0.5) * 0.4;
                        return base + intensity; 
                    }
                    maskEnabled: true; maskSource: auraMask
                }
            }

            // --- 1b. THE GHOST AURA (Dissolves on Top - DELAYED) ---
            Item {
                id: oldAtmosphericBackdrop
                anchors.fill: parent; z: 2 
                opacity: 0
                visible: opacity > 0
                property real bias: atmosphericBackdrop.bias
                Item {
                    id: oldAuraMask
                    anchors.fill: parent; layer.enabled: true; layer.smooth: true; visible: false
                    Rectangle { anchors.fill: parent; radius: Math.round(bgRect.radius - 3); color: "black" }
                }
                Image {
                    id: oldAuraImage; anchors.fill: parent
                    anchors.horizontalCenterOffset: (oldAtmosphericBackdrop.bias - 0.5) * 120 
                    source: root.oldArt; fillMode: Image.PreserveAspectCrop; visible: false
                }
                MultiEffect {
                    anchors.fill: parent; source: oldAuraImage; autoPaddingEnabled: false
                    blurEnabled: true; blur: 0.3; saturation: 0.5
                    brightness: {
                        let base = -0.4; let intensity = Math.abs(oldAtmosphericBackdrop.bias - 0.5) * 0.4;
                        return base + intensity; 
                    }

                    maskEnabled: true; maskSource: oldAuraMask
                }
            }



            // --- 1c. PROXIMITY GESTURE GLOWS ---
            Item {
                anchors.fill: parent; z: 5; clip: true
                
                // Left Edge Glow (Previous)
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: parent.width * 0.15
                    radius: Theme.borderRadius - 3
                    opacity: {
                        if (root.hoverX < -500 || root.hoverX > (width + 16)) return 0;
                        let localX = root.hoverX - 16;
                        return (1.0 - (localX / width)) * 0.3;
                    }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Right Edge Glow (Next)
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: parent.width * 0.15
                    radius: Theme.borderRadius - 3
                    opacity: {
                        let containerWidth = parent.width;
                        let startX = containerWidth * 0.85;
                        let localX = root.hoverX - (root.width - containerWidth - 3); 
                        if (localX < startX) return 0;
                        return ((localX - startX) / (containerWidth * 0.15)) * 0.3; 
                    }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4) }
                    }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            // --- 2. RIPPLE SHADER LAYER ---
            ShaderEffect {
                x: root.rippleX - width / 2; y: root.rippleY - height / 2; width: root.maxRadius * 2; height: width; z: 10
                fragmentShader: "ripple2.frag.qsb"
                property real uAlpha: rippleAnim.running ? 0.3 : 0.0; property real uProgress: root.rippleProgress
                property real uTime: root.shimmerTime; property color uColor: Theme.text
            }
        }

        // --- 3. GHOST GESTURE LAYER ---
        MouseArea {
            id: gesturalLayer; anchors.fill: parent; hoverEnabled: true; z: 500
            onPositionChanged: (mouse) => root.hoverX = mouse.x
            onExited: root.hoverX = -1000
            onClicked: (mouse) => {
                if (!root.activePlayer) return;
                let dw = Math.max(mouse.x, width - mouse.x);
                let dh = Math.max(mouse.y, height - mouse.y);
                root.maxRadius = Math.sqrt(dw*dw + dh*dh);
                root.rippleX = mouse.x; root.rippleY = mouse.y;
                let ratio = mouse.x / width;
                if (ratio < 0.15) {
                    root.triggerSwipe(-1);
                } else if (ratio > 0.85) {
                    root.triggerSwipe(1);
                } else {
                    if (activePlayer.canControl) {
                        activePlayer.togglePlaying();
                    }
                }
                rippleAnim.restart();
            }
        }

        // --- 4. THE GHOST ART (Dissolves on Top - INDEPENDENT DELAY) ---
        Item {
            id: oldArtBox
            width: 95; height: 95; x: 16; y: 14.5; z: 6
            opacity: 0 // Controlled by swipeAnim
            Image { anchors.fill: parent; source: root.oldArt; fillMode: Image.PreserveAspectCrop }
        }

        // --- 5. THE GHOST METADATA (Dissolves on Top - IMMEDIATE) ---
        Item {
            id: oldContent
            anchors.fill: parent
            opacity: root.oldOpacity
            z: 5 
            
            Item {
                width: parent.width - 131 - 16; height: parent.height; x: 131; clip: true
                Column {
                    width: parent.width; x: root.oldOffset; anchors.verticalCenter: parent.verticalCenter
                    Text { 
                        width: parent.width; text: root.oldTitle; color: Theme.primaryText; font.pixelSize: 20; opacity: 1.0; elide: Text.ElideRight 
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.5; shadowBlur: 0.1; shadowVerticalOffset: 2 }
                    }
                    Text { 
                        width: parent.width; text: root.oldArtist; color: Theme.secondaryText; font.pixelSize: 14; opacity: 1.0; elide: Text.ElideRight 
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.5; shadowBlur: 0.1; shadowVerticalOffset: 2 }
                    }
                }
            }
        }

        // --- 6. MAIN CONTENT ---
        Item {
            id: mainContent
            anchors.fill: parent
            opacity: root.mainOpacity
            
            Rectangle {
                width: 95; height: 95; x: 16; y: 14.5; color: Qt.rgba(0,0,0,0.2); radius: 8; clip: true
                Image {
                    id: artImage; anchors.fill: parent
                    source: activePlayer ? activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                }
            }
            
            Item {
                id: metaContainer
                width: parent.width - 131 - 16; height: parent.height; x: 131; clip: true
                Column {
                    id: titlesColumn
                    width: parent.width; x: root.mainOffset; anchors.verticalCenter: parent.verticalCenter
                    
                    // --- SCROLLING TITLE ---
                    Item {
                        width: parent.width; height: 30; clip: true
                        Text {
                            id: scrollTitle
                            text: activePlayer ? activePlayer.trackTitle : ""
                            color: Theme.primaryText; font.pixelSize: 20; font.weight: Font.Bold
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.5; shadowBlur: 0.1; shadowVerticalOffset: 2 }
                            
                            readonly property bool needsScroll: contentWidth > parent.width
                            
                            SequentialAnimation on x {
                                id: titleScrollAnim
                                running: scrollTitle.needsScroll && !swipeAnim.running
                                loops: Animation.Infinite
                                
                                PauseAnimation { duration: 2000 }
                                NumberAnimation { 
                                    from: 0; to: -(scrollTitle.contentWidth - metaContainer.width); 
                                    duration: Math.max(2000, (scrollTitle.contentWidth - metaContainer.width) * 30)
                                    easing.type: Easing.InOutQuad
                                }
                                PauseAnimation { duration: 2000 }
                                
                                // Fade Loop Sequence
                                NumberAnimation { target: scrollTitle; property: "opacity"; from: 1; to: 0; duration: 400 }
                                PropertyAction { target: scrollTitle; property: "x"; value: 0 }
                                NumberAnimation { target: scrollTitle; property: "opacity"; from: 0; to: 1; duration: 400 }
                            }
                            
                            onTextChanged: { x = 0; opacity = 1 }
                            Connections { target: swipeAnim; function onStarted() { scrollTitle.x = 0; scrollTitle.opacity = 1 } }
                        }
                    }

                    // --- SCROLLING ARTIST ---
                    Item {
                        width: parent.width; height: 20; clip: true
                        Text {
                            id: scrollArtist
                            text: activePlayer ? activePlayer.trackArtist : ""
                            color: Theme.secondaryText; font.pixelSize: 14
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.4; shadowBlur: 0.1; shadowVerticalOffset: 1.5 }
                            
                            readonly property bool needsScroll: contentWidth > parent.width
                            
                            SequentialAnimation on x {
                                id: artistScrollAnim
                                running: scrollArtist.needsScroll && !swipeAnim.running
                                loops: Animation.Infinite
                                
                                PauseAnimation { duration: 3000 }
                                NumberAnimation { 
                                    from: 0; to: -(scrollArtist.contentWidth - metaContainer.width); 
                                    duration: Math.max(2000, (scrollArtist.contentWidth - metaContainer.width) * 40)
                                    easing.type: Easing.InOutQuad
                                }
                                PauseAnimation { duration: 2000 }
                                
                                // Fade Loop Sequence
                                NumberAnimation { target: scrollArtist; property: "opacity"; from: 1.0; to: 0; duration: 400 }
                                PropertyAction { target: scrollArtist; property: "x"; value: 0 }
                                NumberAnimation { target: scrollArtist; property: "opacity"; from: 0; to: 1.0; duration: 400 }
                            }
                            
                            onTextChanged: { x = 0; opacity = 1.0 }
                            Connections { target: swipeAnim; function onStarted() { scrollArtist.x = 0; scrollArtist.opacity = 0.6 } }
                        }
                    }
                }
            }
        }

        // --- OVERLAY BORDER ---
        Rectangle {
            anchors.fill: parent; color: "transparent"; border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 1.0)
            border.width: 2; radius: parent.radius; z: 1000; antialiasing: true
        }
    }
}
