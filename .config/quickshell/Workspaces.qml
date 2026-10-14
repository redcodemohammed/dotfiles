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
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            readonly property bool active: ws !== null && ws.active && ws.monitor === root.monitor
            readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0

            width: 24
            height: 24
            color: active ? Theme.accent : "transparent"

            Text {
                anchors.centerIn: parent
                text: parent.wsId
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: parent.active ? Theme.textOnAccent
                     : parent.occupied ? Theme.fgMuted
                     : Theme.fgDim
            }
        }
    }
}
