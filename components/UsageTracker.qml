import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    property var usageMap: ({})
    property bool isLoaded: false
    property string filePath: Quickshell.env("HOME") + "/.config/quickshell/app_usage.json"
    
    signal loaded()

    FileView {
        id: usageFile
        path: root.filePath
        
        onLoaded: {
            try {
                let content = (typeof usageFile.text === "function") ? usageFile.text() : usageFile.text;
                
                if (content && content.trim().length > 0) {
                    root.usageMap = JSON.parse(content);
                }
            } catch (e) {
                console.log("UsageTracker: Error parsing " + root.filePath + ": " + e);
            }
            root.isLoaded = true;
            root.loaded();
        }
    }
    
    function trackLaunch(id) {
        if (!id) return;
        id = id.toLowerCase().trim();
        
        try {
            // Create a copy of the map to trigger notify
            let newMap = {};
            let keys = Object.keys(root.usageMap);
            for (let i = 0; i < keys.length; i++) {
                newMap[keys[i]] = root.usageMap[keys[i]];
            }
            newMap[id] = Date.now();
            root.usageMap = newMap;
            
            usageFile.setText(JSON.stringify(newMap));
        } catch (e) {
            console.log("UsageTracker: Track launch error: " + e);
        }
    }
    
    function getScore(id) {
        if (!id) return 0;
        id = id.toLowerCase().trim();
        return root.usageMap[id] || 0;
    }
}
