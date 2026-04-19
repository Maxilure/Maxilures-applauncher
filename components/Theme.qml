pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool launcherVisible: false
    
    // 0: ACTIVE, 1: IDLE (Static), 2: DISABLED (Hidden)
    property int vizMode: 0
    property bool colorExtraction: true
    
    // --- PERSISTENCE ENGINE ---
    property string _settingsPath: Quickshell.env("HOME") + "/.config/quickshell/launcher_settings.json"
    property bool _loading: false
    property bool _loadedOnce: false
    
    FileView {
        id: settingsFile
        path: root._settingsPath
        onLoaded: {
            try {
                let text = (typeof settingsFile.text === "function") ? settingsFile.text() : settingsFile.text;
                if (!text || text.trim() === "") {
                    root._loadedOnce = true;
                    return;
                }
                let data = JSON.parse(text);
                root._loading = true;
                if (data.vizMode !== undefined) root.vizMode = data.vizMode;
                if (data.colorExtraction !== undefined) root.colorExtraction = data.colorExtraction;
                root._loading = false;
                root._loadedOnce = true;
                
                // Force a sync if extraction is saved as OFF
                if (!root.colorExtraction) {
                    root.accent = "#24708b";
                    root.accent2 = "#3a9fb6";
                    root.accent3 = "#1a4f5f";
                }
                
                console.log("Theme: Settings loaded successfully (" + text + ")");
            } catch(e) { 
                console.log("Theme: Error loading settings: " + e); 
                root._loadedOnce = true;
            }
        }
    }
    
    function saveSettings() {
        if (_loading || !_loadedOnce) return;
        let data = { vizMode: vizMode, colorExtraction: colorExtraction };
        settingsFile.setText(JSON.stringify(data));
        console.log("Theme: Settings saved (" + JSON.stringify(data) + ")");
    }
    
    // --- DYNAMIC ACCENT ENGINE (Chameleon Mode) ---
    property color accent: "#24708b"
    property color accent2: "#3a9fb6"
    property color accent3: "#1a4f5f" // Atmosphere layer
    Behavior on accent { ColorAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on accent2 { ColorAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on accent3 { ColorAnimation { duration: 800; easing.type: Easing.OutCubic } }
    
    // --- REAL-TIME AUDIO STATE ---
    property real beatIntensity: 0.0
    property var spectrum: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    
    Behavior on beatIntensity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    
    // --- SIGNAL HANDLERS (Consolidated) ---
    onColorExtractionChanged: {
        saveSettings();
        if (!colorExtraction) {
            accent = "#24708b";
            accent2 = "#3a9fb6";
            accent3 = "#1a4f5f";
        }
    }
    
    onVizModeChanged: {
        saveSettings();
        if (vizMode !== 0) {
            spectrum = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
            beatIntensity = 0;
        }
    }

    // --- INTELLIGENT CONTRAST ENGINE ---
    function generateAdaptive(base, lightFactor, darkFactor) {
        let source = colorExtraction ? base : Qt.color("#24708b");
        let lum = (0.299 * source.r + 0.587 * source.g + 0.114 * source.b);
        if (lum < 0.35) return Qt.lighter(source, 4.5); 
        if (lum > 0.85) return Qt.darker(source, 2.5);  
        return Qt.lighter(source, lightFactor);
    }

    // --- DESIGN TOKENS ---
    readonly property color background: Qt.rgba(5/255, 20/255, 30/255, 0.75)
    readonly property color dimmer: Qt.rgba(0, 0, 0, 0.45)
    
    property color primaryText: generateAdaptive(accent, 2.8, 1.5)
    property color secondaryText: Qt.rgba(primaryText.r, primaryText.g, primaryText.b, 0.85)
    
    Behavior on primaryText { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
    Behavior on secondaryText { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
    
    readonly property color text: primaryText
    readonly property color match: accent
    readonly property color selection: Qt.rgba(accent.r, accent.g, accent.b, 0.25)
    readonly property color border: Qt.rgba(accent.r, accent.g, accent.b, 0.9)
    readonly property color urgent: "#e64553"
    
    readonly property string fontFamily: "Cascadia Code"
    readonly property int fontSize: 14
    readonly property int borderRadius: 10
    readonly property int borderWidth: 1
}
