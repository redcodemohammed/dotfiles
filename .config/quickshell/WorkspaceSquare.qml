import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// One workspace in Workspaces.qml (owner, 2026-10-17: see which app is where). Empty: its number
// in a 20px square (active: filled, dark number; else dim). With windows: a small number (11px),
// then one icon per window. Gray, the active one in the accent (owner, 2026-10-25: less colour;
// a hue per workspace from 2026-10-20 before): with windows a faint lift. Rounded 6.
// The icons are the apps' own coloured ones from the icon theme (owner, 2026-10-20, replacing the
// glyphs in the workspace hue): the window's app ID finds its .desktop file (heuristicLookup),
// whose Icon= is looked up in the theme; none found, the Nerd Font glyph (AppGlyphs.qml) in gray.
// So an occupied active one is not filled: a 2px bar in the accent just under it. A
// window that wants attention (urgent) has a red dot under its icon.
// A click goes there: `target` is the workspace ID (hyprsplit's range for this screen, so an empty
// slot works too). A right click toggles its save (open again at login): saves, updates it when
// the windows changed, forgets it when they are as saved or the pill is empty (owner, 2026-10-20); a saved one shows a bookmark in place of its number (owner, 2026-10-20:
// SavedWorkspaces.qml, .local/bin/workspace-session).
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
    readonly property color hue: Theme.accent // the active one's

    width: occupied ? glyphs.width + 16 : 20 // 8px either side of the glyphs
    height: 20 // 4px clear of the block's border all round (owner): 28 inside, padding 6
    radius: 6
    color: occupied ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, active ? 0.12 : 0.06) : active ? hue : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    function appId(t) {
        return (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject.class) || ""
    }

    Text {
        visible: !group.occupied
        anchors.centerIn: parent
        text: group.saved ? Icons.bookmarkSimple : group.number
        font.family: group.saved ? Icons.fill : "JetBrainsMono Nerd Font"
        font.pixelSize: group.saved ? 12 : 13
        color: group.active ? Theme.textOnAccent : group.saved ? Theme.fgMuted : Theme.fgDim
    }

    Row {
        id: glyphs
        visible: group.occupied
        anchors.centerIn: parent
        spacing: 8
        Text { // its number, small and dim, so SUPER + n still reads off the bar (owner); saved: a bookmark
            anchors.verticalCenter: parent.verticalCenter
            text: group.saved ? Icons.bookmarkSimple : group.number
            font.family: group.saved ? Icons.fill : "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: group.active ? group.hue : Theme.fgMuted
            opacity: group.saved || group.active ? 1 : 0.7
        }
        Repeater {
            model: group.windows
            Item {
                id: app
                required property var modelData
                readonly property string icon: {
                    const entry = DesktopEntries.heuristicLookup(group.appId(modelData))
                    return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
                }
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16

                IconImage {
                    visible: app.icon !== ""
                    anchors.fill: parent
                    source: app.icon
                }
                Text { // no icon in the theme: the glyph, as before
                    visible: app.icon === ""
                    anchors.centerIn: parent
                    text: AppGlyphs.forApp(group.appId(app.modelData))
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: Theme.fgMuted
                }
                Rectangle { // urgent: it wants attention, until it is focused
                    visible: app.modelData.urgent
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height // on the pill's bottom edge, above the active bar
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.alert
                }
            }
        }
    }

    Rectangle { // active with windows: the bar in the accent (filled would hide the icons' colours),
        // 2px under the pill in the chip's padding, clear of the icons (owner, 2026-10-20)
        visible: group.active && group.occupied
        anchors.top: parent.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 8
        height: 2
        radius: 1
        color: group.hue
    }

    MouseArea {
        anchors.fill: parent
        enabled: group.target > 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                SavedWorkspaces.toggle(group.target, group.number)
                return
            }
            if (!group.ws && group.monitorName !== "")
                Hyprland.dispatch("hl.dsp.focus({ monitor = \"" + group.monitorName + "\" })")
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + group.target + " })")
        }
    }
}
