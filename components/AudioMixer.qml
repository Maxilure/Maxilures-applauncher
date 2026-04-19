import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick.Effects
import Quickshell.Io

Item {
    id: mixerRoot
    property int currentTab: 0 // 0: Apps, 1: Output, 2: Input

    // Global tracker to ensure all background nodes stay bound to their QML objects
    PwObjectTracker {
        id: globalTracker
        objects: Pipewire.nodes.values
    }


    Item {
        id: header; width: parent.width; height: 40; anchors.top: parent.top
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: "Audio Mixer"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.Bold
        }
    }

    Rectangle { id: titleSep; anchors.top: header.bottom; width: parent.width; height: 1; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3) }

    ListView {
        id: listView; anchors.top: titleSep.bottom; anchors.bottom: footerSep.top
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 12; anchors.rightMargin: 12 // Align items with footer visual start
        anchors.topMargin: 16; anchors.bottomMargin: 16; clip: true; spacing: 0; model: Pipewire.nodes; interactive: true; boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: delegateRoot; width: listView.width
            property var node: modelData
            property bool isValid: node && node.name && !["Dummy-Driver", "Freewheel-Driver", "Midi-Bridge", "cava"].includes(node.name)
            property string mediaClass: (node && node.properties) ? (node.properties["media.class"] || "") : ""
            property bool isApp: mediaClass.includes("Stream/")
            property bool isSink: mediaClass === "Audio/Sink"
            property bool isSource: mediaClass === "Audio/Source"
            property bool matchTab: {
                if (!isValid) return false;
                if (mixerRoot.currentTab === 0) return isApp;
                if (mixerRoot.currentTab === 1) return isSink;
                if (mixerRoot.currentTab === 2) return isSource;
                return false;
            }
            height: matchTab ? 72 : 0; visible: matchTab

            // Volume and Mute data
            property real vol: 0.0
            property bool isMuted: false

            // Correct explicit bindings for maximum reactivity
            Binding { target: delegateRoot; property: "vol"; value: (node && node.audio) ? node.audio.volume : 0.0; when: delegateRoot.matchTab }
            Binding { target: delegateRoot; property: "isMuted"; value: (node && node.audio) ? node.audio.mute : false; when: delegateRoot.matchTab }

            Item {
                anchors.fill: parent; anchors.topMargin: 16; visible: delegateRoot.matchTab

                // 1. Icon & Mute Button
                Rectangle {
                    id: iconBox; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 10; border.width: 1
                    color: delegateRoot.isMuted ? Qt.rgba(0.8, 0.2, 0.2, 0.2) : (delegateRoot.isSink ? Qt.rgba(Theme.match.r, Theme.match.g, Theme.match.b, 0.15) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06))
                    border.color: delegateRoot.isMuted ? Qt.rgba(0.9, 0.3, 0.3, 0.6) : (delegateRoot.isSink ? Theme.match : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.2))
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    property string iconPath: {
                        if (!delegateRoot.isValid) return "";
                        let props = node.properties || {};
                        let bin = (props["application.process.binary"] || "").toLowerCase().replace(/\.exe$/i, "");
                        let name = (props["application.name"] || "").toLowerCase().replace(/\s+/g, "-").replace(/\.exe$/i, "");
                        let path = delegateRoot.isApp ? Quickshell.iconPath(props["application.icon-name"] || bin || name, true) : Quickshell.iconPath(delegateRoot.isSink ? "audio-speakers" : "audio-input-microphone", true);
                        if (!path) return "";
                        return (path.startsWith("/") ? "file://" + path : path);
                    }

                    Image {
                        anchors.centerIn: parent; width: 30; height: 30; fillMode: Image.PreserveAspectFit
                        source: iconBox.iconPath; opacity: delegateRoot.isMuted ? 0.4 : 1.0; visible: iconBox.iconPath !== ""
                    }
                    Text {
                        anchors.centerIn: parent; font.pixelSize: 18; visible: iconBox.iconPath === ""
                        text: delegateRoot.isMuted ? "󰖁" : (delegateRoot.isApp ? "󰖟" : (delegateRoot.isSink ? "󰓃" : "󰍬"))
                        color: delegateRoot.isMuted ? "#e64553" : (delegateRoot.isSink ? Theme.match : Theme.text)
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            delegateRoot.isMuted = !delegateRoot.isMuted;
                            let cmd = delegateRoot.isApp ? "set-sink-input-mute" : (delegateRoot.isSink ? "set-sink-mute" : "set-source-mute");
                            let target = delegateRoot.isApp ? (node.properties["object.serial"] || node.properties["object.id"]) : node.name;
                            Quickshell.execDetached({ command: ["pactl", cmd, String(target), (delegateRoot.isMuted ? "1" : "0")] });
                        }
                    }
                }

                // --- CONTENT AREA (ABSOLUTE ANCHORS TO AVOID LAYOUT CRASHES) ---
                Item {
                    id: entryContent
                    anchors.left: iconBox.right; anchors.leftMargin: 12; anchors.right: parent.right
                    anchors.top: iconBox.top; anchors.bottom: iconBox.bottom


                    // Percentage Text (Premium styling)
                    Text {
                        id: percentageLabel; anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.baseline: nameLabel.baseline
                        text: Math.floor((isNaN(delegateRoot.vol) ? 0.0 : delegateRoot.vol) * 100) + "%"
                        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; opacity: 0.4
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    // Name Label
                    Text {
                        id: nameLabel; anchors.left: parent.left; anchors.right: percentageLabel.left; anchors.rightMargin: 12
                        anchors.top: parent.top; anchors.topMargin: -2; elide: Text.ElideRight
                        text: (delegateRoot.isApp ? (node.properties["application.name"] || node.name) : (node.properties["node.description"] || node.name)) || "Unknown"
                        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                    }

                    // --- SLIDER SECTION ---
                    Rectangle {
                        id: track; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                        height: 4; radius: 2; color: Theme.selection

                        Rectangle {
                            id: fill; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; z: 5
                            width: parent.width * (isNaN(delegateRoot.vol) ? 0.0 : Math.max(0, Math.min(1.0, delegateRoot.vol)))
                            color: Theme.accent; radius: 2; opacity: 1.0
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                        }

                        MouseArea {
                            anchors.fill: parent; anchors.margins: -10
                            onPressed: (mouse) => { if (node && node.audio) node.audio.volume = Math.max(0, Math.min(1.0, mouse.x / track.width)) }
                            onPositionChanged: (mouse) => { if (pressed && node && node.audio) node.audio.volume = Math.max(0, Math.min(1.0, mouse.x / track.width)) }
                        }
                    }
                }
            }
        }
    }

    Rectangle { id: footerSep; anchors.bottom: footerContainer.top; width: parent.width; height: 1; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3) }

    Item {
        id: footerContainer; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width; height: 40
        Rectangle { 
            anchors.fill: parent; color: Qt.rgba(0,0,0,0.3); radius: 16; anchors.margins: 4 
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.4 }
        }
        Row {
            id: footer; anchors.centerIn: parent
            spacing: 8
            
            Repeater {
                model: ["Apps", "Output", "Input"]
                Rectangle {
                    width: 80; height: 28; radius: 14; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    
                    color: mixerRoot.currentTab === index ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                    border.color: mixerRoot.currentTab === index ? Theme.accent : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.2)
                    
                    Text { 
                        anchors.centerIn: parent
                        text: modelData
                        color: mixerRoot.currentTab === index ? Theme.match : Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: 12 
                    }
                    
                    MouseArea { anchors.fill: parent; onClicked: mixerRoot.currentTab = index }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent; visible: listView.count === 0 || !Pipewire.ready
        text: !Pipewire.ready ? "Connecting to Pipewire..." : "No items in this tab"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.3); font.pixelSize: 12
    }
}
