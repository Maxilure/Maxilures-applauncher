//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import "components"

ShellRoot {
    // Top-level application shell object
    
    LauncherWindow {
        id: launcher
        visible: false // Start hidden
    }

    GlobalShortcut {
        name: "launcher"
        onPressed: {
            launcher.visible = !launcher.visible;
        }
    }
}
