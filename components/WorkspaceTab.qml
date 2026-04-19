import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    width: folderWrapper.width
    height: 48 // Extra height for internal spacing
    
    // Use HoverHandler for robust tab-wide hover detection
    property bool isHovered: hoverHandler.hovered
    
    // Tracks which workspaces have urgent windows
    property var urgentWorkspaces: ({})
    
    // Efficiently poll for urgency every 500ms
    // This is more robust than event parsing as it handles all potential edge cases
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            let newMap = {};
            let tls = Array.from(Hyprland.toplevels.values);
            tls.forEach(tl => {
                if (tl.urgent && tl.workspace) {
                    newMap[tl.workspace.id] = true;
                }
            });
            
            // Only update if something changed to avoid unnecessary re-renders
            if (JSON.stringify(newMap) !== JSON.stringify(root.urgentWorkspaces)) {
                root.urgentWorkspaces = newMap;
            }
        }
    }
    
    signal workspaceSelected(var workspace)
    
    HoverHandler {
        id: hoverHandler
    }
    
    // Clipping container to create a flat-bottomed tab
    Item {
        anchors.fill: parent
        clip: true
        
        Rectangle {
            id: folderWrapper
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -12 // Push the bottom border outside the clipped area
            anchors.horizontalCenter: parent.horizontalCenter
            
            color: Theme.background
            border.color: Theme.border
            border.width: Theme.borderWidth
            radius: 10
            
            // Tighter scaling for hovered, but beefy for unhovered
            width: rowContainer.width + 40 // 20px padding on each side
            height: root.isHovered ? 32 + 12 : 24 + 12 
            
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
            
            Row {
                id: rowContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.isHovered ? 12 : 17
                spacing: 10 
                z: 3 
                
                Repeater {
                    model: ScriptModel {
                        values: {
                            let ws = Array.from(Hyprland.workspaces.values)
                            return ws.filter(w => w.id > 0).sort((a,b) => a.id - b.id)
                        }
                    }
                    
                    delegate: Item {
                        id: dotItem
                        required property var modelData
                        property bool activeWs: Hyprland.focusedWorkspace === modelData
                        property bool dotHovered: dotMouseArea.containsMouse
                        property bool isUrgent: !!root.urgentWorkspaces[modelData.id]
                        
                        // Beefy unhovered (28x10), Tighter hovered (32x28)
                        width: root.isHovered ? 32 : 28
                        height: root.isHovered ? 28 : 10
                        clip: root.isHovered // Create that mini-tab look
                        
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

                        Rectangle {
                            id: dotRect
                            width: parent.width
                            // When whole tab is hovered, make dots mini-tabs (taller so bottom is clipped)
                            height: root.isHovered ? parent.height + 10 : parent.height
                            radius: root.isHovered ? 10 : 5
                            anchors.top: parent.top
                            
                            color: {
                                if (activeWs) return Theme.selection;
                                if (dotItem.dotHovered) return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.1);
                                if (root.isHovered) return "transparent";
                                return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25);
                            }
                            
                            border.color: activeWs ? Qt.rgba(Theme.match.r, Theme.match.g, Theme.match.b, 0.3) : "transparent"
                            border.width: activeWs ? 1 : 0
                            
                            Behavior on color { ColorAnimation { duration: 200 } }

                            // Urgent Pulse Overlay
                            Rectangle {
                                id: urgentPulse
                                anchors.fill: parent
                                radius: parent.radius
                                color: Theme.urgent
                                opacity: 0
                                visible: dotItem.isUrgent && !dotItem.activeWs
                                
                                SequentialAnimation on opacity {
                                    running: urgentPulse.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.7; duration: 800; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.1; duration: 800; easing.type: Easing.InOutSine }
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -4 // Lifted up more
                                text: modelData.id
                                color: dotItem.isUrgent ? "white" : (activeWs ? Theme.match : (dotItem.dotHovered ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.8)))
                                font.family: Theme.fontFamily
                                font.pixelSize: 13 // Slightly bigger
                                font.weight: (activeWs || dotItem.isUrgent) ? Font.Bold : Font.Normal
                                opacity: root.isHovered ? 1 : 0
                                
                                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                        
                        MouseArea {
                            id: dotMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // Signal first to ensure the launcher hides immediately
                                root.workspaceSelected(modelData);
                                
                                // Direct dispatch to Hyprland IPC (single string format)
                                Hyprland.dispatch("workspace " + modelData.id);
                                Hyprland.focusedWorkspace = modelData;
                            }
                        }
                    }
                }
            }
        }
    }
}
