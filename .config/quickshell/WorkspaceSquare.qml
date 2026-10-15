import QtQuick
import Quickshell.Hyprland

// One workspace square for Workspaces.qml: 24px, active amber fill and dark number, occupied gray
// number, empty dim. `clickable`: a click focuses it (visiting workspaces from a screen that is
// gone; Hyprland's own focus, which goes to wherever the workspace is).
Rectangle {
    id: square
    property var ws: null
    property int number
    property bool clickable: false
    readonly property bool active: ws !== null && ws.active
    readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0

    width: 24
    height: 24
    color: active ? Theme.accent : "transparent"

    Text {
        anchors.centerIn: parent
        text: square.number
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: square.active ? Theme.textOnAccent : square.occupied ? Theme.fgMuted : Theme.fgDim
    }

    MouseArea {
        anchors.fill: parent
        enabled: square.clickable && square.ws !== null
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + square.ws.id + " })")
    }
}
