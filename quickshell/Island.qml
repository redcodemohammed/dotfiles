import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The island: top 4px, centred, on the main screen only. Compact 24px tall inside
// the bar; expanded grows down from the same spot. Width and height animate 120ms
// linear; contents swap instantly. Floats over windows, never takes keyboard focus,
// hidden in true fullscreen. The window is click-through outside the pill.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    // Main screen: the first screen for now. The real machine pins this to the main external.
    readonly property bool isMain: modelData === Quickshell.screens[0]
    readonly property bool fullscreen: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.hasFullscreen : false

    visible: isMain && IslandState.kind !== "" && !fullscreen
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore // sits over the bar's reserved strip
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    implicitWidth: 440
    implicitHeight: 4 + 256
    mask: Region { item: pill }

    Rectangle {
        id: pill
        y: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: IslandState.size[0]
        // Notifications size to their content (body length, Earlier list, Arabic line height).
        height: IslandState.kind === "notify" ? notify.implicitHeight + 4 : IslandState.size[1]
        clip: true
        color: Theme.surface
        border.width: 2
        readonly property var info: IslandState.active ? IslandState.active.data : ({})
        border.color: IslandState.kind === "record"
            || (IslandState.kind === "build" && info.failed)
            || (IslandState.kind === "notify" && info.entry && info.entry.urgent)
            ? Theme.alert : Theme.border

        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.Linear } }
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.Linear } }

        // Compact: the whole pill expands it.
        MouseArea {
            anchors.fill: parent
            visible: !IslandState.open
            onClicked: IslandState.expand()
        }

        IslandVolume {
            anchors.fill: parent
            visible: IslandState.kind === "volume"
            open: IslandState.open
        }

        IslandNotify {
            id: notify
            anchors.fill: parent
            visible: IslandState.kind === "notify"
            entry: pill.info.entry ?? null
        }

        // Placeholder content for states not built yet (island steps 2, 5-8).
        Text {
            visible: IslandState.kind !== "volume" && IslandState.kind !== "notify"
            x: IslandState.open ? 12 : 8
            y: IslandState.open ? 12 : (parent.height - height) / 2
            text: IslandState.kind + (IslandState.open ? " · expanded" : "")
                + (IslandState.queued ? " · 1 queued" : "")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: IslandState.open ? 14 : 13
            color: Theme.fg
        }

        // Expanded: chevron top right collapses (dismisses a transient).
        // Notifications close with their own Dismiss button instead.
        Item {
            visible: IslandState.open && IslandState.kind !== "notify"
            width: 24
            height: 24
            x: parent.width - 12 - width
            y: 12

            Text {
                anchors.centerIn: parent
                text: Icons.caretUp
                font.family: Icons.regular
                font.pixelSize: 16
                color: Theme.fgMuted
            }

            MouseArea {
                anchors.fill: parent
                onClicked: IslandState.collapse()
            }
        }
    }
}
