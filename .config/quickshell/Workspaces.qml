import QtQuick
import Quickshell.Hyprland

// Workspaces 1 to 5 as 24px squares. Active: amber fill, dark number.
// Occupied: gray number. Empty: dim number. Display only for now.
Row {
    id: root
    required property var screen
    readonly property var monitor: Hyprland.monitorFor(screen)
    spacing: 4

    Repeater {
        model: 5

        Rectangle {
            required property int index
            readonly property int slot: index + 1
            // hyprsplit gives each monitor its own ID range (1-5, 6-10, 11-15):
            // show this monitor's workspaces in slots 1 to 5.
            readonly property var ws: Hyprland.workspaces.values.find(w => w.monitor === root.monitor
                && w.id > 0 && ((w.id - 1) % 5) + 1 === slot) ?? null
            readonly property bool active: ws !== null && ws.active
            readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0

            width: 24
            height: 24
            color: active ? Theme.accent : "transparent"

            Text {
                anchors.centerIn: parent
                text: parent.slot
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: parent.active ? Theme.textOnAccent
                     : parent.occupied ? Theme.fgMuted
                     : Theme.fgDim
            }
        }
    }
}
