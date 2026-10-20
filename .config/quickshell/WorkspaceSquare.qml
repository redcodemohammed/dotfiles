import QtQuick
import Quickshell
import Quickshell.Hyprland

// One workspace in Workspaces.qml (owner, 2026-10-17: see which app is where). Empty: its number
// in a 20px square (active: filled, dark number; else dim). With windows: a small number (11px),
// then one Nerd Font glyph per window (AppGlyphs.qml) on its own background, like the owner's
// sample. Each workspace has its own hue (owner, 2026-10-20: hue1-hue6 in turn by its number):
// with windows a faint tint of it and the glyphs in it; active filled with it, dark glyphs
// (Theme.textOnAccent: the hues are lit like the accent). Rounded 6. A click goes there: `target` is the workspace ID (hyprsplit's range
// for this screen, so an empty slot works too). A right click saves its windows to open again at
// login, or forgets that save when it is empty; a saved one has a dot in its top-right corner
// (owner, 2026-10-20: SavedWorkspaces.qml, .local/bin/workspace-session).
Rectangle {
    id: group
    property var ws: null
    property int number
    property int target: ws ? ws.id : 0
    property string monitorName: "" // an empty slot: focus its screen first, so it opens there
    readonly property bool active: ws !== null && ws.active
    readonly property var windows: ws ? ws.toplevels.values : []
    readonly property bool occupied: windows.length > 0
    readonly property bool saved: target > 0 && SavedWorkspaces.has(target)
    readonly property color hue: [Theme.hue1, Theme.hue2, Theme.hue3, Theme.hue4, Theme.hue5, Theme.hue6][(number - 1) % 6]

    width: occupied ? glyphs.width + 16 : 20 // 8px either side of the glyphs
    height: 20 // 4px clear of the block's border all round (owner): 28 inside, padding 6
    radius: 6
    color: active ? hue : occupied ? Qt.rgba(hue.r, hue.g, hue.b, 0.18) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

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
            color: group.active ? Theme.textOnAccent : group.hue
            opacity: 0.7
        }
        Repeater {
            model: group.windows
            Text {
                required property var modelData
                text: AppGlyphs.forApp(group.appId(modelData))
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: group.active ? Theme.textOnAccent : group.hue
            }
        }
    }

    Rectangle { // saved: opens again at login
        visible: group.saved
        x: parent.width - width - 3 // inside the corner's curve, in the padding
        y: 3
        width: 4
        height: 4
        radius: 2
        color: group.active ? Theme.textOnAccent : group.hue
    }

    MouseArea {
        anchors.fill: parent
        enabled: group.target > 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (group.occupied)
                    SavedWorkspaces.save(group.target, group.number)
                else
                    SavedWorkspaces.forget(group.target, group.number)
                return
            }
            if (!group.ws && group.monitorName !== "")
                Hyprland.dispatch("hl.dsp.focus({ monitor = \"" + group.monitorName + "\" })")
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + group.target + " })")
        }
    }
}
