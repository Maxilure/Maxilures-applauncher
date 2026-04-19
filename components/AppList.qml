import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Effects


Item {
    id: root
    
    property string searchTerm: ""
    
    UsageTracker {
        id: usageTracker
        onLoaded: root.refreshList()
        onUsageMapChanged: root.refreshList()
    }
    
    function refreshList() {
        if (!appModel) return;
        appModel.values = computeValues();
    }
    
    function computeValues() {
        try {
            let term = root.searchTerm.toLowerCase();
            let rawApps = DesktopEntries.applications.values;
            if (!rawApps) return [];
            
            let items = Array.from(rawApps);
            
            // Sort primarily by usage, secondarily by name
            items.sort((a, b) => {
                let scoreA = usageTracker.getScore(a.id || a.name);
                let scoreB = usageTracker.getScore(b.id || b.name);
                if (scoreA !== scoreB) return scoreB - scoreA;
                return a.name.localeCompare(b.name);
            });
            
            if (!term) return items;
            
            let res = items.filter(app => {
                let nameMatch = app.name.toLowerCase().includes(term);
                let descMatch = app.description && app.description.toLowerCase().includes(term);
                return nameMatch || descMatch;
            });
            
            if (res.length === 0) {
                return [{ isCommand: true, command: root.searchTerm, name: "Run: " + root.searchTerm }];
            }
            return res;
        } catch (e) {
            console.log("AppList Error during refresh: " + e);
            return [];
        }
    }
    
    // Resolve the best icon source for an app item.
    // Uses iconPath(name, true) which returns "" if the icon is NOT in the system theme.
    // This is the only reliable way to avoid the magenta checkerboard, which occurs
    // when the image://icon/ provider is given an unknown name.
    function resolveIconSource(item) {
        if (!item) return "";
        
        // Terminal shortcuts
        if (item.isCommand) {
            let p = Quickshell.iconPath("utilities-terminal-symbolic", true) || 
                    Quickshell.iconPath("terminal", true);
            if (p) return p;
            return Quickshell.shellPath("assets/terminal_run-icon.svg");
        }

        let icon = String(item.icon || "");
        let id   = String(item.id   || "").toLowerCase();
        let cmd  = String(item.command || "").toLowerCase();
        let name = String(item.name  || "").toLowerCase();

        // 1. Absolute paths
        if (icon.startsWith("/")) return "file://" + icon;

        // 2. Primary icon with existence check
        if (icon) {
            let path = Quickshell.iconPath(icon, true);
            if (path) return path;
        }

        // 3. Contextual fallbacks (if theme matches are missing)
        
        // Handle Lutris
        if (id.includes("lutris") || cmd.includes("lutris")) {
            let p = Quickshell.iconPath("net.lutris.Lutris", true) || Quickshell.iconPath("lutris", true);
            if (p) return p;
            return "image://icon/lutris"; 
        }

        // Handle Wine/EXE
        if (cmd.includes("wine") || id.includes("wine") || name.includes("wine")) {
            let p = Quickshell.iconPath("wine", true) || Quickshell.iconPath("winetricks", true);
            if (p) return p;
            return Quickshell.shellPath("assets/exe_missing-icons.svg");
        }

        // 4. Final generic fallback
        return Quickshell.shellPath("assets/missing_app-icon.svg");
    }
    
    onSearchTermChanged: {
        root.refreshList();
        listView.currentIndex = 0;
        listView.positionViewAtBeginning();
    }
    
    function moveUp() {
        if (listView.currentIndex > 0) {
            listView.currentIndex--
            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
        }
    }
    
    function moveDown() {
        if (listView.currentIndex < listView.count - 1) {
            listView.currentIndex++
            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
        }
    }
    
    function resetSelection() {
        listView.currentIndex = 0
        listView.positionViewAtBeginning()
        root.refreshList()
    }
    
    function launchSelected() {
        if (listView.currentIndex < 0 || !listView.model) return;
        
        let item = listView.model.values[listView.currentIndex];
        if (item) {
            try {
                if (item.isCommand) {
                    Quickshell.execDetached(["fish", "-c", item.command]);
                } else if (item.execute) {
                    usageTracker.trackLaunch(item.id || item.name);
                    item.execute()
                }
            } catch (e) {
                // Silently fail or log critical errors briefly
            }
            root.launched()
        }
    }
    
    signal launched()
    
    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        focus: true
        currentIndex: 0
        snapMode: ListView.NoSnap
        highlightMoveDuration: 150
        highlight: null // Disable default highlight which can cause ghost lines
        
        model: ScriptModel {
            id: appModel
            values: root.computeValues()
        }
        
        delegate: Item {
            id: appDelegate
            width: listView.width
            height: 44
            
            property bool isSelected: listView.currentIndex === index || appArea.containsMouse
            
            // 1. BASE SELECTION BACKGROUND
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8 // Create the "floating" highlight look
                radius: Theme.borderRadius
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                opacity: appDelegate.isSelected ? 1.0 : 0.0
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                border.width: appDelegate.isSelected ? 1 : 0
                antialiasing: true // Ensure smooth corners
                
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            
            // 2. LEFT ACCENT INDICATOR (Moved in to match the new background margin)
            Rectangle {
                id: accentBar
                anchors.left: parent.left
                anchors.leftMargin: 10 // Pushed in to align with the 8px margin + 2px offset
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                radius: 1.5
                color: Theme.match
                
                // Animate height and opacity
                height: appDelegate.isSelected ? 20 : 0
                opacity: appDelegate.isSelected ? 1.0 : 0.0
                
                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            
            // 3. CONTENT ROW (With shifting animation)
            Row {
                id: contentRow
                anchors.fill: parent
                anchors.leftMargin: appDelegate.isSelected ? 24 : 18 // Indented to match the floating highlight
                anchors.rightMargin: 14
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 12
                
                Behavior on anchors.leftMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Item {
                    id: iconContainer
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    scale: appDelegate.isSelected ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    
                    property string iconSrc: root.resolveIconSource(modelData)
                    property bool isLocal: iconSrc.includes("assets/") || iconSrc.includes("/assets/")
                    
                    Image {
                        id: iconBase
                        anchors.fill: parent
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        source: parent.iconSrc
                        visible: !parent.isLocal
                        opacity: appDelegate.isSelected ? 1.0 : 0.8
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    
                    MultiEffect {
                        anchors.fill: iconBase
                        source: iconBase
                        visible: parent.isLocal
                        colorization: 1.0
                        colorizationColor: Theme.primaryText
                        opacity: appDelegate.isSelected ? 1.0 : 0.6
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
                
                Text {
                    text: modelData.name
                    color: Theme.primaryText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: appDelegate.isSelected ? Font.DemiBold : Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                    
                    scale: appDelegate.isSelected ? 1.02 : 1.0
                    transformOrigin: Item.Left
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
            
            MouseArea {
                id: appArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: listView.currentIndex = index
                onClicked: root.launchSelected()
            }
        }
    }
    

}
