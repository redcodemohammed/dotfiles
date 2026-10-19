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
// Tabs (Tab key or a click): Desktop, and tmux (step 2): `tmux list-keys -N` for the root, prefix
// and copy-mode tables, keeping the notes written "Group: what it does" (tmux.conf's -N notes;
// tmux's own notes have no group and are left out). Needs a running tmux server.
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
            else {
                tmuxReader.running = true
                reader.running = true // shows itself once the binds are in
            }
        }
    }

    // Per tab: which column each group goes in (a group not listed joins the last column), and
    // the groups read in: name -> [{ text, keys }].
    property string tab: "desktop"
    readonly property var tabs: ["desktop", "tmux"]
    readonly property var layouts: ({
        desktop: [["Windows", "Workspaces"], ["Apps", "Shell", "Session"], ["Capture", "Media"]],
        tmux: [["Panes"], ["Windows"], ["Sessions", "Copy"]],
    })
    property var desktopGroups: ({})
    property var tmuxGroups: ({})
    readonly property var columns: layouts[tab]
    readonly property var groups: tab === "desktop" ? desktopGroups : tmuxGroups

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

    // Hyprland: "Group: text<TAB>SUPER + SHIFT + code:46" in each described bind.
    function desktopEntries(binds) {
        const entries = []
        for (const b of binds) {
            const tab = b.description.indexOf("\t")
            if (tab < 0)
                continue
            const parts = b.description.slice(tab + 1).split(" + ")
            entries.push({ desc: b.description.slice(0, tab), mods: parts.slice(0, -1).map(keyName).join(" "),
                key: keyName(parts[parts.length - 1]) })
        }
        return entries
    }
    // tmux: lines "<table> <key>   <note>"; C-, M-, S- become Ctrl, Alt, Shift.
    function tmuxEntries(text) {
        const tables = { root: "", prefix: "Prefix", "copy-mode": "Copy mode" }
        const mods = { C: "Ctrl", M: "Alt", S: "Shift" }
        const entries = []
        for (const line of text.split("\n")) {
            const m = line.match(/^(\S+)\s+(\S+)\s+([A-Z][A-Za-z ]*): (.+)$/)
            if (!m)
                continue
            let key = m[2]
            const words = tables[m[1]] ? [tables[m[1]]] : []
            while (/^[CMS]-./.test(key)) {
                words.push(mods[key[0]])
                key = key.slice(2)
            }
            entries.push({ desc: m[3] + ": " + m[4], mods: words.join(" "), key: names[key.toLowerCase()] ?? key })
        }
        return entries
    }

    function collect(entries) {
        const rows = {}  // description -> { group, text, combos: mods -> [keys] }
        const order = []
        for (const e of entries) {
            const desc = e.desc
            const mods = e.mods
            if (!rows[desc]) {
                const colon = desc.indexOf(": ")
                rows[desc] = { group: desc.slice(0, colon), text: desc.slice(colon + 2), combos: {} }
                order.push(desc)
            }
            const combos = rows[desc].combos
            const key = e.key
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
        return out
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
                    root.desktopGroups = root.collect(root.desktopEntries(JSON.parse(text)))
                } catch (err) {
                    root.desktopGroups = {}
                }
                root.visible = true
                Panels.claim(root) // one panel at a time: others close
            }
        }
    }

    Process {
        id: tmuxReader
        command: ["sh", "-c", "for t in root prefix copy-mode; do tmux list-keys -N -P '' -T $t 2>/dev/null | sed \"s/^/$t /\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.tmuxGroups = root.collect(root.tmuxEntries(text))
        }
    }

    Connections {
        target: Panels
        function onCurrentChanged() {
            if (Panels.current !== root && root.visible)
                root.visible = false
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
        radius: Settings.look.frameRadius // the frame's own curve, as big as the overlay (owner, 2026-10-20)
        color: Edge.fill

        focus: root.visible
        Keys.onEscapePressed: root.visible = false
        Keys.onTabPressed: root.tab = root.tabs[(root.tabs.indexOf(root.tab) + 1) % root.tabs.length]

        MouseArea { // clicks on the card itself don't close it
            anchors.fill: parent
        }

        Column {
            id: content
            x: 24
            y: 24
            spacing: 16

            Item {
                width: parent.width
                height: 28
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Shortcuts"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.fg
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    SettingsTab { width: 120; tab: root.tab; label: "Desktop"; section: "desktop"; onChosen: root.tab = section }
                    SettingsTab { width: 120; tab: root.tab; label: "tmux"; section: "tmux"; onChosen: root.tab = section }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tab === "tmux" ? (Object.keys(root.tmuxGroups).length ? "Prefix: Ctrl + Space · Tab · Esc" : "tmux isn't running · Tab · Esc")
                        : "Tab: tmux · Esc closes"
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
