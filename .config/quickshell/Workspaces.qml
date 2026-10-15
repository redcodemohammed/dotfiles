import QtQuick
import Quickshell.Hyprland

// Workspaces 1 to 5 as 24px squares. Active: amber fill, dark number. Occupied: gray number.
// Empty: dim number. Display only.
// hyprsplit gives each monitor its own ID range by its priority (hyprland.lua:
// hs.monitor_priority; G5 1-5, laptop 6-10, LF24 11-15), so a monitor shows the workspaces of its
// range in slots 1 to 5. A screen that goes away (lid shut) leaves its workspaces on a survivor:
// they show after the five, behind the glyph of the screen they belong to (laptop or monitor),
// numbered as on that screen; a click goes there (owner, 2026-10-15). When the screen comes back,
// hyprsplit moves them home.
Row {
    id: root
    required property var screen
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var priority: ["HDMI-A-1", "eDP-1", "DP-2"] // as hs.monitor_priority
    readonly property bool known: monitor !== null && priority.indexOf(monitor.name) >= 0
    readonly property int base: known ? priority.indexOf(monitor.name) * 5 : 0
    function own(ws) {
        return !known || (ws.id > base && ws.id <= base + 5)
    }
    // Visiting workspaces, grouped by the screen they belong to: [{ home, list }]
    readonly property var visitors: {
        if (!known)
            return []
        const groups = []
        const here = Hyprland.workspaces.values.filter(w => w.monitor === root.monitor && w.id > 0 && !root.own(w))
            .sort((a, b) => a.id - b.id)
        for (const w of here) {
            const home = priority[Math.floor((w.id - 1) / 5)] ?? ""
            let g = groups.find(g => g.home === home)
            if (!g) {
                g = { home: home, list: [] }
                groups.push(g)
            }
            g.list.push(w)
        }
        return groups
    }
    spacing: 4

    Repeater {
        model: 5

        WorkspaceSquare {
            required property int index
            ws: Hyprland.workspaces.values.find(w => w.monitor === root.monitor && w.id > 0 && root.own(w)
                && ((w.id - 1) % 5) + 1 === index + 1) ?? null
            number: index + 1
        }
    }

    Repeater {
        model: root.visitors

        Row {
            id: group
            required property var modelData
            spacing: 4
            leftPadding: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: group.modelData.home.startsWith("eDP") ? Icons.laptop : Icons.monitor
                font.family: Icons.regular
                font.pixelSize: 16
                color: Theme.fgMuted
            }
            Repeater {
                model: group.modelData.list
                WorkspaceSquare {
                    required property var modelData
                    ws: modelData
                    number: ((modelData.id - 1) % 5) + 1
                    clickable: true
                }
            }
        }
    }
}
