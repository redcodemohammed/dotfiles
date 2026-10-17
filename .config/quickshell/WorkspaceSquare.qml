import QtQuick
import Quickshell
import Quickshell.Hyprland

// One workspace in Workspaces.qml (owner, 2026-10-17: see which app is where). Empty: its number
// in a 20px square (active: accent fill, dark number; else dim). With windows: a small dim
// number (11px), then one Nerd Font glyph per window (AppGlyphs.qml) on its own background, like the owner's sample:
// surface_selected with gray glyphs, the active one accent with dark glyphs (as the active number
// square). Square, radius 0. A click goes there: `target` is the workspace ID (hyprsplit's range
// for this screen, so an empty slot works too).
Rectangle {
    id: group
    property var ws: null
    property int number
    property int target: ws ? ws.id : 0
    property string monitorName: "" // an empty slot: focus its screen first, so it opens there
    readonly property bool active: ws !== null && ws.active
    readonly property var windows: ws ? ws.toplevels.values : []
    readonly property bool occupied: windows.length > 0

    width: occupied ? glyphs.width + 16 : 20 // 8px either side of the glyphs
    height: 20 // 4px clear of the block's border all round (owner): 28 inside, padding 6
    color: active ? Theme.accent : occupied ? Theme.surfaceSelected : "transparent"

    function appId(t) {
        return (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject.class) || ""
    }

    Text {
        visible: !group.occupied
        anchors.centerIn: parent
        text: group.number
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: group.active ? Theme.textOnAccent : Theme.fgDim
    }

    Row {
        id: glyphs
        visible: group.occupied
        anchors.centerIn: parent
        spacing: 8
        Text { // its number, small and dim, so SUPER + n still reads off the bar (owner)
            anchors.verticalCenter: parent.verticalCenter
            text: group.number
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: group.active ? Theme.textOnAccent : Theme.fgDim
            opacity: group.active ? 0.7 : 1
        }
        Repeater {
            model: group.windows
            Text {
                required property var modelData
                text: AppGlyphs.forApp(group.appId(modelData))
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: group.active ? Theme.textOnAccent : Theme.fgMuted
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: group.target > 0
        onClicked: {
            if (!group.ws && group.monitorName !== "")
                Hyprland.dispatch("hl.dsp.focus({ monitor = \"" + group.monitorName + "\" })")
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + group.target + " })")
        }
    }
}
