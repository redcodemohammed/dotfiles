import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The island: 4px into the bar (bar 6px from the top: 10px), centred, on the main screen only. Compact 24px tall inside
// the bar; expanded grows down from the same spot. Width and height animate 120ms
// linear; contents swap instantly. Floats over windows, never takes keyboard focus,
// hidden in true fullscreen. The window is click-through outside the pill.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    // Main screen: the Odyssey G5 when connected, else the laptop panel, else the first screen.
    // Matched by model, like the Hyprland monitor rule: Qt's screen order is not stable.
    readonly property var mainScreen: {
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].model === "Odyssey G5") return screens[i]
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === "eDP-1") return screens[i]
        return screens[0]
    }
    readonly property bool isMain: modelData === mainScreen
    readonly property bool fullscreen: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.hasFullscreen : false

    visible: isMain && IslandState.kind !== "" && !fullscreen
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore // sits over the bar's reserved strip
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    implicitWidth: 440
    implicitHeight: 10 + 256
    mask: Region { item: pill }

    Rectangle {
        id: pill
        y: 10 // the bar floats 6px down; the pill sits 4px into it
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
            || (IslandState.kind === "battery" && IslandState.batteryCritical)
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
            visible: IslandState.kind === "volume" || IslandState.kind === "brightness"
            open: IslandState.open
        }

        IslandNotify {
            id: notify
            anchors.fill: parent
            visible: IslandState.kind === "notify"
            entry: pill.info.entry ?? null
        }

        IslandBattery {
            anchors.fill: parent
            visible: IslandState.kind === "battery"
            open: IslandState.open
        }

        IslandBuild {
            anchors.fill: parent
            visible: IslandState.kind === "build"
            open: IslandState.open
            info: pill.info
        }

        // Placeholder content for states not built yet (media, recording).
        Text {
            visible: ["volume", "brightness", "battery", "notify", "build"].indexOf(IslandState.kind) < 0
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
