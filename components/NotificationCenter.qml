import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick.Effects

Item {
    id: root
    
    NotificationServer {
        id: server
        // Ensure all incoming notifications are tracked so they appear in our model
        onNotification: (n) => {
            n.tracked = true;
        }
    }
    
    // Model from the server
    property var notifications: server.trackedNotifications
    
    // SIGNAL SYSTEM FOR STAGGERED CLEAR
    signal clearTriggered()
    
    // Expose whether any unread critical notification exists (for the drawer handle)
    property bool hasCritical: {
        let notifs = server.trackedNotifications;
        if (!notifs) return false;
        return Array.from(notifs.values).some(n => n.urgency >= 2);
    }

    // 1. Header (Matched to Mixer)
    Item {
        id: header
        width: parent.width
        height: 40
        anchors.top: parent.top
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.Bold
        }
    }
    
    Rectangle { 
        id: titleSep; anchors.top: header.bottom; width: parent.width; height: 1
        color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3) 
    }

    // 2. Footer (Matched to Mixer)
    Rectangle { 
        id: footerSep; anchors.bottom: footer.top; width: parent.width; height: 1
        color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3) 
    }

    Item {
        id: footer
        width: parent.width; height: 40
        anchors.bottom: parent.bottom
        
        // Relocated Clear All Button
        MouseArea {
            anchors.centerIn: parent
            width: 100; height: 28
            hoverEnabled: true
            visible: server.trackedNotifications.values.length > 0
            
            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                radius: 14 // Rounded like mixer tabs
                border.color: parent.containsMouse ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }
            
            Text {
                anchors.centerIn: parent
                text: "Clear All"
                color: Theme.match
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            
            onClicked: root.clearTriggered()
        }
    }
    
    // 3. Content Area
    Item {
        id: emptyState
        anchors.top: titleSep.bottom; anchors.bottom: footerSep.top; anchors.left: parent.left; anchors.right: parent.right
        visible: server.trackedNotifications.values.length === 0
        
        Column {
            anchors.centerIn: parent
            spacing: 8
            
            Item {
                width: 48; height: 48
                anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    id: emptyIconBase; anchors.fill: parent
                    source: "file://" + Quickshell.shellPath("assets/sparkles-icon.svg")
                    fillMode: Image.PreserveAspectFit; visible: false; sourceSize: Qt.size(128, 128)
                }
                MultiEffect {
                    anchors.fill: emptyIconBase; source: emptyIconBase
                    colorization: 1.0; colorizationColor: Theme.text; opacity: 0.4
                }
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up!"; color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
                font.family: Theme.fontFamily; font.pixelSize: 14
            }
        }
    }
    
    ListView {
        id: listView
        anchors.top: titleSep.bottom; anchors.bottom: footerSep.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 12; anchors.bottomMargin: 12
        model: server.trackedNotifications
        spacing: 8
        clip: true
        visible: server.trackedNotifications.values.length > 0
            
            delegate: Rectangle {
                id: notificationCard
                width: ListView.view.width
                
                // --- KINETIC EXIT SYSTEM ---
                property bool isExiting: false
                
                // Height shrinks to 0 on exit
                height: isExiting ? 0 : contentRow.height + 24
                opacity: isExiting ? 0 : 1
                visible: height > 0
                clip: true // Ensure content doesn't leak during collapse

                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: 250 } }
                
                // Reactive styling
                readonly property bool isCritical: modelData.urgency >= 2
                
                Rectangle {
                    anchors.fill: parent; radius: parent.radius; z: -1
                    color: notificationCard.isCritical ? Qt.rgba(0.2, 0.05, 0.05, 0.6) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.05)
                }
                
                color: "transparent"
                
                border.color: isCritical
                    ? Qt.rgba(1.0, 0.3, 0.3, pulse.val) // Pulsing red border
                    : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                
                border.width: isCritical ? 2 : 1
                radius: 10
                
                // Breathing animation for critical alerts
                QtObject {
                    id: pulse
                    property real val: 0.8
                    SequentialAnimation on val {
                        running: notificationCard.isCritical
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.3; to: 0.8; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.8; to: 0.3; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }
                
                Row {
                    id: contentRow
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    spacing: 12
                    opacity: notificationCard.isExiting ? 0 : 1
                    
                    // CONTENT VANISHES FIRST
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    
                    // Resolve the best icon source for a notification (Ironclad & Protocol-Aware)
                    function resolveIconSource(n) {
                        if (!n) return "";
                        
                        let result = "";
                        let appName = (n.appName || "").toLowerCase();
                        let summary = (n.summary || "").toLowerCase();
                        let appIconRaw = (n.appIcon || "").toLowerCase();

                        // 1. Check for attached image (Protocol-Aware)
                        // Blacklist the 'image://icon/' provider as it causes checkerboards in this environment
                        if (n.image && n.image !== "" && !n.image.startsWith("image://icon/")) {
                            if (n.image.startsWith("/") || n.image.includes("://")) {
                                result = n.image.startsWith("/") ? "file://" + n.image : n.image;
                            }
                        }

                        // 2. Smart Category Mapping (Keyword-based fallback for local assets)
                        // Expanded to catch common system-requested names like 'terminal'
                        if (result === "") {
                            let asset = "";

                            if (n.urgency >= 2 || summary.includes("critical") || summary.includes("alert")) asset = "animated/Alert Animation/alert-octagon.svg"
                            else if (appName.includes("spotify") || appName.includes("music") || summary.includes("track")) asset = "media-icon.svg"
                            else if (appName.includes("discord") || appName.includes("chat") || appName.includes("telegram")) asset = "chat-icon.svg"
                            else if (summary.includes("battery") || summary.includes("power")) asset = "battery-icon.svg"
                            else if (summary.includes("wifi") || summary.includes("network")) asset = "wifi-icon.svg"
                            else if (appIconRaw.includes("terminal") || appName.includes("terminal") || summary.includes("terminal")) asset = "terminal-icon.svg"
                            else if (appIconRaw.includes("info") || summary.includes("message") || summary.includes("status")) asset = "info-icon.svg"
                            else if (appName.includes("notify-send")) asset = "general.svg"

                            if (asset !== "") result = "file://" + Quickshell.shellPath("assets/" + asset);
                        }

                        // 3. Fallback to explicitly named system icon (Double-checking protocol)
                        if (result === "" && n.appIcon && n.appIcon !== "" && !n.appIcon.startsWith("image://icon/")) {
                            if (n.appIcon.startsWith("/")) {
                                result = "file://" + n.appIcon;
                            } else {
                                let path = Quickshell.iconPath(n.appIcon, true);
                                if (path) result = "file://" + path;
                            }
                        }
                        
                        // 4. Ultimate Fallback to themed missing icon
                        if (result === "" || result === "file://") {
                            result = "file://" + Quickshell.shellPath("assets/missing_notification-icon.svg");
                        }

                        // Use Qt.resolvedUrl to ensure the path is perfectly formatted
                        return Qt.resolvedUrl(result);
                    }

                    // Icon Container
                    Item {
                        id: iconContainer
                        width: 48; height: 48
                        anchors.verticalCenter: parent.verticalCenter
                        
                        readonly property string iconSrc: parent.resolveIconSource(modelData)
                        // Detect if we should apply theme tinting
                        readonly property bool isLocal: iconSrc.toString().includes("/assets/") || iconSrc.toString().includes("/quickshell/")
                        
                        // High-Resolution Critical Alert Symbol (SVG-based for perfect crispness)
                        Item {
                            id: lottieWrapper
                            anchors.fill: parent
                            opacity: 0
                            
                            Image {
                                id: alertIcon
                                anchors.centerIn: parent
                                width: 44; height: 44
                                source: "file://" + Quickshell.shellPath("assets/animated/Alert Animation/alert-octagon.svg")
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(128, 128)
                                
                                // Pulsing scale animation to simulate the "urgent" Lottie effect
                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: notificationCard.isCritical
                                    PropertyAnimation { to: 1.1; duration: 800; easing.type: Easing.InOutQuad }
                                    PropertyAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                        
                        // Normal Static Icon
                        Image {
                            id: iconBase
                            anchors.fill: parent
                            source: iconContainer.iconSrc
                            fillMode: Image.PreserveAspectFit
                            visible: false 
                            sourceSize: Qt.size(256, 256)
                            layer.enabled: true
                        }
                        
                        // Theme Tinting Engine (Handles both icons)
                        MultiEffect {
                            anchors.fill: parent
                            source: notificationCard.isCritical ? lottieWrapper : iconBase
                            colorization: iconContainer.isLocal ? 1.0 : 0.0
                            colorizationColor: notificationCard.isCritical ? Theme.urgent : Theme.primaryText
                            opacity: notificationCard.isCritical ? 1.0 : 0.7
                        }
                    }
                    
                    Column {
                        width: parent.width - 64 - 24 // Icon (48) + Spacing (12) + Margin + Close button
                        spacing: 2
                        
                        Text {
                            id: summaryText
                            width: parent.width
                            text: modelData.summary
                            color: notificationCard.isCritical 
                                ? Qt.rgba(1.0, 0.5, 0.5, pulse.val + 0.2) // Pulsing red text
                                : Theme.primaryText
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            id: bodyText
                            width: parent.width
                            text: modelData.body
                            color: notificationCard.isCritical
                                ? Qt.rgba(1.0, 0.7, 0.7, pulse.val)
                                : Theme.secondaryText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            text: modelData.appName
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.3)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }
                
                // Dismiss Button
                MouseArea {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 32; height: 32
                    hoverEnabled: true
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖" // close icon
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: parent.containsMouse ? "#ffffff" : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
                    }
                    
                    onClicked: {
                        notificationCard.isExiting = true;
                    }
                }

                // Final cleanup after animation
                Timer {
                    id: dismissTimer
                    interval: 350
                    running: false
                    onTriggered: modelData.dismiss()
                }

                // --- STAGGERED CLEAR LOGIC ---
                Connections {
                    target: root
                    function onClearTriggered() {
                        staggerTimer.start();
                    }
                }

                Timer {
                    id: staggerTimer
                    interval: index * 50 // Stagger by 50ms per item
                    repeat: false
                    onTriggered: {
                        notificationCard.isExiting = true;
                        dismissTimer.start();
                    }
                }
            }
        }
}
