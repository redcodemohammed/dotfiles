pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// One panel at a time (owner, 2026-10-17): every panel that opens calls claim() with itself;
// any other open one sees `current` change and closes (bar panels slide away through Reveal,
// the shortcuts overlay just closes). Covers every bar panel and the inbox (all on Reveal.qml)
// and the shortcuts overlay. The island is not a panel.
// `qs ipc call panel toggle <record|sound|bluetooth|network>` opens one on the focused screen (Bar.qml listens).
Singleton {
    id: root
    property var current: null
    function claim(panel) { current = panel }

    signal toggleRequested(string name, string screen)
    IpcHandler {
        target: "panel"
        function toggle(name: string): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                root.toggleRequested(name, monitor.name)
        }
    }
}
