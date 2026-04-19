import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick.Effects


Item {
    id: root
    height: 40
    
    property var targetWindow
    property alias text: entry.text
    property bool showTray: false
    
    signal activate()
    signal upPressed()
    signal downPressed()
    signal escapePressed()

    function focusSearch() {
        entry.forceActiveFocus()
    }
    
    property bool showSecretMenu: false
    
    Item {
        id: promptContainer
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width; height: parent.height
        
        Text {
            id: promptIcon
            text: "❯"
            color: promptMouse.containsMouse ? Theme.text : Theme.match
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
            rotation: root.showSecretMenu ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        }
        
        MouseArea {
            id: promptMouse
            anchors.fill: promptIcon; hoverEnabled: true
            onClicked: root.showSecretMenu = !root.showSecretMenu
        }
        
        Row {
            id: secretMenu
            anchors.left: promptIcon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            clip: true
            width: root.showSecretMenu ? childrenRect.width : 0
            visible: width > 0
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
            
            // Visualizer Mode Toggle
            Rectangle {
                width: 26; height: 26; radius: 7
                property color modeColor: Theme.vizMode === 0 ? Theme.match : (Theme.vizMode === 1 ? "#f1fa8c" : "#ff5555")
                color: Qt.rgba(modeColor.r, modeColor.g, modeColor.b, vizMouse.containsMouse ? 0.2 : 0.1)
                border.color: modeColor
                border.width: 1
                
                Image {
                    id: vizIcon
                    source: Quickshell.shellPath("assets/visualizer-icon.svg")
                    anchors.centerIn: parent; width: 14; height: 14
                    visible: false
                }
                MultiEffect {
                    anchors.fill: vizIcon; source: vizIcon
                    colorization: 1.0; colorizationColor: parent.modeColor
                }
                MouseArea {
                    id: vizMouse; anchors.fill: parent; hoverEnabled: true
                    onClicked: Theme.vizMode = (Theme.vizMode + 1) % 3
                }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            
            // Color Extraction Toggle
            Rectangle {
                width: 26; height: 26; radius: 7
                property color modeColor: Theme.colorExtraction ? Theme.match : "#ff5555"
                color: Qt.rgba(modeColor.r, modeColor.g, modeColor.b, colorMouse.containsMouse ? 0.2 : 0.1)
                border.color: modeColor
                border.width: 1
                
                Image {
                    id: colorIcon
                    source: Quickshell.shellPath("assets/color-icon.svg")
                    anchors.centerIn: parent; width: 14; height: 14
                    visible: false
                }
                MultiEffect {
                    anchors.fill: colorIcon; source: colorIcon
                    colorization: 1.0; colorizationColor: parent.modeColor
                }
                MouseArea {
                    id: colorMouse; anchors.fill: parent; hoverEnabled: true
                    onClicked: Theme.colorExtraction = !Theme.colorExtraction
                }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
    
    TextInput {
        id: entry
        anchors.left: promptContainer.right
        anchors.leftMargin: 10
        anchors.right: trayContainer.left
        anchors.rightMargin: 10
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Bold
        selectByMouse: true
        selectionColor: Theme.selection
        focus: true
        
        Text {
            id: promptText
            text: "Search Applications..."
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.5)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.text.length === 0 && !entry.activeFocus
        }
        
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.escapePressed()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                root.downPressed()
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root.upPressed()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate()
                event.accepted = true
            }
        }
    }
    
    Row {
        id: trayContainer
        anchors.right: parent.right
        anchors.rightMargin: 12 // Match the promptIcon's leftMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        
        Row {
            id: trayBox
            height: parent.height
            spacing: 6
            clip: true
            
            width: root.showTray ? childrenRect.width : 0
            visible: width > 0
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
            
            Repeater {
                model: SystemTray.items
                
                delegate: Rectangle {
                    required property var modelData
                    
                    width: props.width
                    height: props.height
                    color: trayMouse.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.1) : "transparent"
                    radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Item { id: props; width: 24; height: 24 }
                    
                    Image {
                        source: modelData.icon
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        sourceSize: Qt.size(16, 16)
                    }
                    
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                modelData.activate()
                            } else if (mouse.button === Qt.RightButton) {
                                let pos = trayMouse.mapToItem(null, mouse.x, mouse.y);
                                modelData.display(root.targetWindow, pos.x, pos.y);
                            }
                        }
                    }
                }
            }
        }
        
        Text {
            id: toggleBtn
            text: "⋮"
            color: toggleMouse.containsMouse ? Theme.text : Theme.match
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
            
            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.showTray = !root.showTray
            }
        }
    }
}
