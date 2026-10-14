import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

// Keyboard layout: EN or AR, gray in both (the text changes, not the color).
// Read once from the main keyboard, then follow Hyprland's activelayout events, like the lock.
Text {
    id: root
    property string keymap: "" // Hyprland's name, e.g. "English (US)" or "Arabic"

    visible: keymap !== ""
    text: keymap.startsWith("English") ? "EN"
        : keymap.startsWith("Arabic") ? "AR"
        : keymap.slice(0, 2).toUpperCase()
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 13
    color: Theme.fgMuted

    Process {
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            id: devices
            onStreamFinished: {
                try {
                    const main = JSON.parse(devices.text).keyboards.find(k => k.main)
                    if (main)
                        root.keymap = main.active_keymap
                } catch (err) {
                    // Until the first switch the label stays hidden.
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.keymap = event.data.split(",").slice(1).join(",")
        }
    }
}
