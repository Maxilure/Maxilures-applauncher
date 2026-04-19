import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
    id: rootWindow
    color: "transparent"
    
    // --- STATE ENGINE ---
    property bool showNotifications: true
    property bool showMixer: true
    readonly property int coreWidth: 600
    
    onVisibleChanged: {
        Theme.launcherVisible = visible;
        if (visible) {
            appSearch.text = "";
            appSearch.focusSearch();
            appList.resetSelection();
        }
    }
    
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "Applauncher"
    WlrLayershell.layer: WlrLayer.Top
    focusable: true
    
    // Dimmer background covering entire screen
    Rectangle {
        id: dimmer
        anchors.fill: parent
        color: Theme.dimmer
        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onPositionChanged: (mouse) => {
                let local = mapToItem(mediaPlayer, mouse.x, mouse.y);
                mediaPlayer.relativeMouseX = local.x;
            }
        }
    }
    
    // --- MAIN MODULAR SHELL (Input Coordinator) ---
    Item {
        id: modularShell
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width 
        height: outerContainer.height + 100 

        Item {
            id: mainBodyAnchor
            anchors.horizontalCenter: parent.horizontalCenter
            width: rootWindow.coreWidth
            height: mainBody.height
        }

        WorkspaceTab {
            id: workspaceTabs
            anchors.bottom: outerContainer.top
            anchors.bottomMargin: -Theme.borderWidth 
            anchors.horizontalCenter: mainBodyAnchor.horizontalCenter
            z: 500
            onWorkspaceSelected: rootWindow.visible = false
        }

        // 1. GLASS BACKDROP
        Rectangle {
            id: outerContainer
            height: mainBody.height
            anchors.bottom: parent.bottom
            anchors.left: mixerPane.left
            anchors.right: notificationPane.right
            color: Theme.background; radius: Theme.borderRadius
            clip: true // ENABLE CLIPPING FOR STABLE BACKGROUND EFFECT

            Rectangle {
                anchors.fill: parent; radius: Theme.borderRadius
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.7) // Heavier frosted tint
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 0.8 } // Deep industrial-strength diffusion
            }
            Rectangle {
                id: surgeLayer
                anchors.fill: parent; radius: Theme.borderRadius
                opacity: Theme.beatIntensity * 0.15
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 0.5; color: Theme.accent3 }
                    GradientStop { position: 1.0; color: Theme.accent2 }
                }
            }

            // --- STABLE CENTERED VISUALIZER (Internal Path Clip) ---
            Item {
                id: glassWavesContainer; anchors.fill: parent; z: 5
                opacity: Theme.vizMode !== 2 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                
                // --- MANDATORY CORNER MASK (PREVENT LEAKAGE) ---
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource { 
                        sourceItem: Rectangle { 
                            width: glassWavesContainer.width
                            height: glassWavesContainer.height
                            radius: Theme.borderRadius
                            color: "black" 
                        }
                    }
                }
                
                property real vizIntensity: Theme.vizMode === 0 ? 1 : 0
                Behavior on vizIntensity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                
                property real waveHeight: Math.min(180, outerContainer.height * 0.35)
                property real time: 0
                Timer { running: Theme.launcherVisible; repeat: true; interval: 16; onTriggered: { glassWavesContainer.time += 0.016; } }



                Item {
                    id: wavesBottomContainer
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottomMargin: -2
                    height: glassWavesContainer.waveHeight; clip: false // REMOVED INTERNAL CLIP
                    
                    Repeater {
                        model: 200
                        Rectangle {
                            property real centerX: (mainBodyAnchor.x - outerContainer.x) + (mainBodyAnchor.width / 2)
                            x: centerX - (200 * 14 / 2) + (index * 14)
                            width: 10; radius: 5; anchors.bottom: parent.bottom
                            
                            property real distFromCenter: Math.abs(x + width/2 - centerX)
                            property real distFactor: Math.min(1.0, distFromCenter / (outerContainer.width * 1.5))
                            
                            property int specIdx: Math.min(35, Math.floor(distFactor * 35))
                            property real val: (Theme.spectrum[specIdx] || 0) * glassWavesContainer.vizIntensity
                            
                            height: Math.max(0, (8 + val * (parent.height * 1.1) * Math.cos(Math.min(Math.PI / 2, distFactor * Math.PI))) + Math.sin(glassWavesContainer.time * 3.5 - index * 0.25) * 10)
                            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuart } }
                            
                            gradient: Gradient {

                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.3; color: Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.1) }
                                GradientStop { position: 1.0; color: Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.5) }
                            }
                        }
                    }
                }
            }
        }

        // --- GLOBAL UI READABILITY SCRIM REMOVED ---

        // 2. AUDIO MIXER WING
        Item {
            id: mixerPane
            width: rootWindow.showMixer ? 340 : 0
            anchors.right: mainBodyWrapper.left
            anchors.top: outerContainer.top; anchors.bottom: outerContainer.bottom
            opacity: width > 0 ? 1 : 0; clip: true; z: 110
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
            Behavior on opacity { NumberAnimation { duration: 300 } }
            
            // High-Legibility Wing Backplate
            Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.4); radius: Theme.borderRadius }
            
            AudioMixer { anchors { fill: parent; topMargin: 16; leftMargin: 24; rightMargin: 24; bottomMargin: 10 } }
            Rectangle { anchors.right: parent.right; height: parent.height - 40; anchors.verticalCenter: parent.verticalCenter; width: 1; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.2) }
        }

        // 3. MAIN LAUNCHER HUB
        Item {
            id: mainBodyWrapper
            width: rootWindow.coreWidth
            anchors.horizontalCenter: mainBodyAnchor.horizontalCenter
            anchors.top: outerContainer.top; anchors.bottom: outerContainer.bottom
            z: 110

            Item {
                id: mainBody; width: rootWindow.coreWidth; height: columnLayout.height + 10
                Column {
                    id: columnLayout; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24; topMargin: 16 }
                    Item {
                        width: parent.width; height: appSearch.height
                        Rectangle { 
                            anchors.fill: parent; color: Qt.rgba(0,0,0,0.3); radius: 16
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blur: 0.4 } 
                        }
                        AppSearch { id: appSearch; width: parent.width; anchors.horizontalCenter: parent.horizontalCenter; targetWindow: rootWindow; onActivate: appList.launchSelected(); onUpPressed: appList.moveUp(); onDownPressed: appList.moveDown(); onEscapePressed: rootWindow.visible = false; onTextChanged: appList.searchTerm = text }
                    }
                    Rectangle { width: parent.width - 8; height: 1; anchors.horizontalCenter: parent.horizontalCenter; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3) }
                    Item { width: 1; height: 10 }
                    Item {
                        width: parent.width; height: 314
                        Rectangle { 
                            anchors.fill: parent; color: Qt.rgba(0,0,0,0.3); radius: 16
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blur: 0.4 } 
                        }
                        AppList { id: appList; width: parent.width; height: parent.height; onLaunched: rootWindow.visible = false }
                    }
                    Item { width: 1; height: 10 }
                    Rectangle { width: parent.width - 8; height: 1; anchors.horizontalCenter: parent.horizontalCenter; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3); visible: mediaPlayer.visible }
                    Item { width: 1; height: 10 }
                    MediaPlayer { id: mediaPlayer; width: parent.width; anchors.horizontalCenter: parent.horizontalCenter; property real relativeMouseX: -1000 }
                    Item {
                        id: footer; width: parent.width; height: 48
                        Rectangle { 
                            anchors.fill: parent; anchors.bottomMargin: 8; color: Qt.rgba(0,0,0,0.35); radius: 16
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blur: 0.4 }
                        }
                        function getHijriDate(date) {
                            let jd; let year = date.getFullYear(); let month = date.getMonth() + 1; let day = date.getDate();
                            if ((year > 1582) || ((year == 1582) && (month > 10)) || ((year == 1582) && (month == 10) && (day > 14))) { jd = Math.floor((1461 * (year + 4800 + Math.floor((month - 14) / 12))) / 4) + Math.floor((367 * (month - 2 - 12 * (Math.floor((month - 14) / 12)))) / 12) - Math.floor((3 * (Math.floor((year + 4900 + Math.floor((month - 14) / 12)) / 100))) / 4) + day - 32075; }
                            else { jd = 367 * year - Math.floor((7 * (year + 5001 + Math.floor((month - 9) / 7))) / 4) + Math.floor((275 * month) / 9) + day + 1729777; }
                            let l = jd - 1948440 + 10632; let n = Math.floor((l - 1) / 10631); l = l - 10631 * n + 354; let j = (Math.floor((10985 - l) / 5316)) * (Math.floor((50 * l) / 17719)) + (Math.floor(l / 5670)) * (Math.floor((43 * l) / 15238)); l = l - (Math.floor((30 - j) / 15)) * (Math.floor((17719 * j) / 50)) - (Math.floor(j / 16)) * (Math.floor((15238 * j) / 43)) + 29; let m = Math.floor((24 * l) / 709); let d_h = l - Math.floor((709 * m) / 24); let y_h = 30 * n + j - 30;
                            const months = ["محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]; const toArabic = (n) => n.toString().replace(/\d/g, d => "٠١٢٣٤٥٦٧٨٩"[d]); return toArabic(d_h) + " " + months[m - 1] + " " + toArabic(y_h);
                        }
                        function updateMetrics() { let d = new Date(); timeText12.text = Qt.formatTime(d, "h:mm AP"); timeText24.text = Qt.formatTime(d, "hh:mm"); dateTextG.text = Qt.formatDate(d, "ddd, MMM d"); dateTextH.text = getHijriDate(d); }
                        Timer { interval: 1000; running: true; repeat: true; onTriggered: footer.updateMetrics() }
                        Component.onCompleted: footer.updateMetrics()
                        Item {
                            id: dateContainer; width: 140; height: 20; anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -5; property bool hovered: false
                            Text { id: dateTextG; color: Theme.secondaryText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; opacity: dateContainer.hovered ? 0 : 1; Behavior on opacity { NumberAnimation { duration: 250 } } }
                            Text { id: dateTextH; color: Theme.secondaryText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; opacity: dateContainer.hovered ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 250 } } }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: dateContainer.hovered = true; onExited: dateContainer.hovered = false }
                        }
                        Item {
                            id: timeContainer; width: 100; height: 20; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -5; property bool hovered: false
                            Text { id: timeText12; anchors.right: parent.right; color: Theme.secondaryText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; opacity: timeContainer.hovered ? 0 : 1; Behavior on opacity { NumberAnimation { duration: 250 } } }
                            Text { id: timeText24; anchors.right: parent.right; color: Theme.secondaryText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; opacity: timeContainer.hovered ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 250 } } }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: timeContainer.hovered = true; onExited: timeContainer.hovered = false }
                        }
                        SysStatus { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // 4. NOTIFICATIONS WING
        Item {
            id: notificationPane
            width: rootWindow.showNotifications ? 340 : 0
            anchors.left: mainBodyWrapper.right
            anchors.top: outerContainer.top; anchors.bottom: outerContainer.bottom
            opacity: width > 0 ? 1 : 0; clip: true; z: 110
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
            Behavior on opacity { NumberAnimation { duration: 300 } }
            
            // High-Legibility Wing Backplate
            Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.4); radius: Theme.borderRadius }
            
            Rectangle { anchors.left: parent.left; height: parent.height - 40; anchors.verticalCenter: parent.verticalCenter; width: 1; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.2) }
            NotificationCenter { id: notificationCenter; anchors { fill: parent; topMargin: 16; leftMargin: 24; rightMargin: 24; bottomMargin: 10 } }
        }
        
        Item {
            id: frameContainer
            anchors.fill: outerContainer; z: 1000 
            
            Repeater {
                model: [{ a: "left", b: "top" }, { a: "right", b: "top" }, { a: "left", b: "bottom" }, { a: "right", b: "bottom" }]
                delegate: Item {
                    width: Theme.borderRadius; height: Theme.borderRadius
                    anchors.left: modelData.a === "left" ? parent.left : undefined; anchors.right: modelData.a === "right" ? parent.right : undefined
                    anchors.top: modelData.b === "top" ? parent.top : undefined; anchors.bottom: modelData.b === "bottom" ? parent.bottom : undefined
                    clip: true
                    Rectangle {
                        width: Theme.borderRadius * 2; height: Theme.borderRadius * 2
                        anchors.left: modelData.a === "left" ? parent.left : undefined; anchors.right: modelData.a === "right" ? parent.right : undefined
                        anchors.top: modelData.b === "top" ? parent.top : undefined; anchors.bottom: modelData.b === "bottom" ? parent.bottom : undefined
                        color: "transparent"; border.color: modelData.b === "top" ? Theme.accent : Theme.accent2; border.width: Theme.borderWidth; radius: Theme.borderRadius
                    }
                }
            }
            
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Theme.borderRadius; anchors.rightMargin: Theme.borderRadius; height: Theme.borderWidth; color: Theme.accent }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Theme.borderRadius; anchors.rightMargin: Theme.borderRadius; height: Theme.borderWidth; color: Theme.accent2 }
            
            Rectangle { 
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: Theme.borderRadius; anchors.bottomMargin: Theme.borderRadius; width: Theme.borderWidth
                gradient: Gradient { GradientStop { position: 0.0; color: Theme.accent } GradientStop { position: 1.0; color: Theme.accent2 } }
            }
            Rectangle { 
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: Theme.borderRadius; anchors.bottomMargin: Theme.borderRadius; width: Theme.borderWidth
                gradient: Gradient { GradientStop { position: 0.0; color: Theme.accent } GradientStop { position: 1.0; color: Theme.accent2 } }
            }
        }

        Item {
            id: notificationHandle
            height: 240; width: 180; anchors.left: outerContainer.right; anchors.leftMargin: -20; anchors.verticalCenter: outerContainer.verticalCenter; z: 1100
            property real proximity: 0
            property bool active: false
            
            Rectangle {
                width: 6; anchors.left: parent.left; anchors.leftMargin: 32; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: 60; anchors.bottomMargin: 60
                radius: 3; color: Theme.accent; opacity: Math.max(notificationHandle.active ? 1.0 : 0.0, notificationHandle.proximity) + (notificationHandle.proximity > 0.2 ? Theme.beatIntensity * 0.2 : 0)
                layer.enabled: true; layer.effect: MultiEffect { blurEnabled: notificationHandle.active; blur: 0.3; shadowEnabled: notificationHandle.active; shadowColor: Theme.accent; shadowBlur: 0.5 }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                
                Rectangle {
                    anchors.fill: parent; radius: 3; color: Theme.urgent; opacity: 0; visible: notificationCenter.hasCritical && !rootWindow.showNotifications
                    SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite; NumberAnimation { to: 0.9; duration: 800; easing.type: Easing.InOutSine } NumberAnimation { to: 0.15; duration: 800; easing.type: Easing.InOutSine } }
                }
            }
            
            MouseArea { 
                anchors.fill: parent; hoverEnabled: true; 
                onPositionChanged: (mouse) => {
                    let dx = mouse.x - 20; 
                    let dy = mouse.y - 120; 
                    let dist = Math.sqrt(dx*dx + dy*dy);
                    notificationHandle.proximity = Math.max(0, 1.0 - (dist / 140)) * 0.8;
                }
                onEntered: notificationHandle.active = true
                onExited: { notificationHandle.active = false; notificationHandle.proximity = 0 }
                onClicked: rootWindow.showNotifications = !rootWindow.showNotifications 
            }
        }

        Item {
            id: mixerHandle
            height: 240; width: 180; anchors.right: outerContainer.left; anchors.rightMargin: -20; anchors.verticalCenter: outerContainer.verticalCenter; z: 1100
            property real proximity: 0
            property bool active: false
            
            Rectangle {
                width: 6; anchors.right: parent.right; anchors.rightMargin: 32; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: 60; anchors.bottomMargin: 60
                radius: 3; color: Theme.accent; opacity: Math.max(mixerHandle.active ? 1.0 : 0.0, mixerHandle.proximity) + (mixerHandle.proximity > 0.2 ? Theme.beatIntensity * 0.2 : 0)
                layer.enabled: true; layer.effect: MultiEffect { blurEnabled: mixerHandle.active; blur: 0.3; shadowEnabled: mixerHandle.active; shadowColor: Theme.accent; shadowBlur: 0.5 }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            
            MouseArea { 
                anchors.fill: parent; hoverEnabled: true; 
                onPositionChanged: (mouse) => {
                    let dx = (parent.width - mouse.x) - 20; 
                    let dy = mouse.y - 120; 
                    let dist = Math.sqrt(dx*dx + dy*dy);
                    mixerHandle.proximity = Math.max(0, 1.0 - (dist / 140)) * 0.8;
                }
                onEntered: mixerHandle.active = true
                onExited: { mixerHandle.active = false; mixerHandle.proximity = 0 }
                onClicked: rootWindow.showMixer = !rootWindow.showMixer 
            }
        }
    }
}
