pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The tools panel's shared side (owner, 2026-10-17): SUPER + X opens it on the focused screen
// (`qs ipc call tools toggle`); each bar's ToolsPanel listens for its own screen's name.
Singleton {
    id: root
    signal panelRequested(string screen)

    IpcHandler {
        target: "tools"
        function toggle(): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                root.panelRequested(monitor.name)
        }
    }
}
