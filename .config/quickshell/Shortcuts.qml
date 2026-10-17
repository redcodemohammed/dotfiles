import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Shortcuts overlay (owner, 2026-10-17): SUPER + F1 (`qs ipc call shortcuts toggle`) shows every
// Hyprland bind in the middle of the focused screen; Escape, a click or SUPER + F1 closes it.
// The list is read live from `hyprctl binds -j` each time it opens, so it always matches the
// config: hyprland.lua's bind() puts "Group: what it does<TAB>keys" in each bind's description
// (keys too, since keycode binds come back with an empty key). Binds that share a description
// share a row; a bind without one is left out.
PanelWindow {
    id: root
    visible: false
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shortcuts"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    IpcHandler {
        target: "shortcuts"
        function toggle(): void {
            if (root.visible)
                root.visible = false
            else
                reader.running = true // shows itself once the binds are in
        }
    }

    // Which column each group goes in; a group not listed joins the last column.
    readonly property var columns: [["Windows", "Workspaces"], ["Apps", "Shell", "Session"], ["Capture", "Media"]]
    property var groups: ({}) // name -> [{ text, keys }]

    // Key names as the config writes them -> what is printed on the key.
    readonly property var names: ({
        left: "←", right: "→", up: "↑", down: "↓", Return: "Enter", Escape: "Esc", Print: "PrtSc",
        mouse_down: "Scroll down", mouse_up: "Scroll up", "mouse:272": "Left drag", "mouse:273": "Right drag",
        XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mute",
        XF86AudioMicMute: "Mic mute", XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright −",
        XF86AudioNext: "Next", XF86AudioPrev: "Prev", XF86AudioPlay: "Play", XF86AudioPause: "Pause",
        SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt",
    })
    // US keycodes (xkb, the codes `wev` shows) for the code:NN binds.
    function codeName(n) {
        const rows = [[10, "1234567890-="], [24, "QWERTYUIOP[]"], [38, "ASDFGHJKL;'"], [52, "ZXCVBNM,./"]]
        for (const [start, keys] of rows)
            if (n >= start && n < start + keys.length)
                return keys[n - start]
        if (n >= 67 && n <= 76)
            return "F" + (n - 66)
        return "code " + n
    }
    function keyName(k) {
        if (k.startsWith("code:"))
            return codeName(parseInt(k.slice(5)))
        return names[k] ?? k
    }

    function build(binds) {
        const rows = {}  // description -> { group, text, combos: mods -> [keys] }
        const order = []
        for (const b of binds) {
            const tab = b.description.indexOf("\t")
            if (tab < 0)
                continue
            const desc = b.description.slice(0, tab)
            const parts = b.description.slice(tab + 1).split(" + ")
            const mods = parts.slice(0, -1).map(keyName).join(" ")
            if (!rows[desc]) {
                const colon = desc.indexOf(": ")
                rows[desc] = { group: desc.slice(0, colon), text: desc.slice(colon + 2), combos: {} }
                order.push(desc)
            }
            const combos = rows[desc].combos
            const key = keyName(parts[parts.length - 1])
            if (!combos[mods])
                combos[mods] = []
            if (!combos[mods].includes(key))
                combos[mods].push(key)
        }
        const out = {}
        for (const desc of order) {
            const r = rows[desc]
            // Arrows first, in ← ↓ ↑ → order, then the rest as bound (H J K L after the arrows).
            const arrows = ["←", "↓", "↑", "→"]
            const rank = k => arrows.includes(k) ? arrows.indexOf(k) : arrows.length
            const keys = Object.keys(r.combos).map(m => (m ? m + " + " : "")
                // the original position breaks ties: Qt's sort doesn't keep equal items in order
                + r.combos[m].map((k, i) => [k, i]).sort((a, b) => rank(a[0]) - rank(b[0]) || a[1] - b[1])
                    .map(p => p[0]).join(" ")).join("  /  ")
            if (!out[r.group])
                out[r.group] = []
            out[r.group].push({ text: r.text, keys: keys })
        }
        groups = out
    }
    function groupsIn(column) {
        const listed = [].concat(...columns)
        const names = columns[column].filter(g => groups[g])
        if (column === columns.length - 1)
            for (const g of Object.keys(groups))
                if (!listed.includes(g))
                    names.push(g)
        return names
    }

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.build(JSON.parse(text))
                } catch (err) {
                    root.groups = {}
                }
                root.visible = true
            }
        }
    }

    MouseArea { // a click anywhere closes it
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: content.implicitWidth + 48
        height: content.implicitHeight + 48
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: root.visible
        Keys.onEscapePressed: root.visible = false

        Column {
            id: content
            x: 24
            y: 24
            spacing: 16

            Item {
                width: parent.width
                height: 20
                Text {
                    text: "Shortcuts"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.fg
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Esc closes"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgDim
                }
            }

            Row {
                spacing: 32
                Repeater {
                    model: root.columns.length
                    Column {
                        required property int index
                        width: 340
                        spacing: 16
                        Repeater {
                            model: root.groupsIn(parent.index)
                            Column {
                                required property string modelData
                                width: 340
                                spacing: 4
                                Text {
                                    bottomPadding: 2
                                    text: modelData
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: Theme.fgMuted
                                }
                                Repeater {
                                    model: root.groups[parent.modelData]
                                    Item {
                                        required property var modelData
                                        width: 340
                                        height: 20
                                        Text {
                                            width: parent.width - keysText.implicitWidth - 12
                                            elide: Text.ElideRight
                                            text: modelData.text
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: Theme.fg
                                        }
                                        Text {
                                            id: keysText
                                            anchors.right: parent.right
                                            text: modelData.keys
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: Theme.fgMuted
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
