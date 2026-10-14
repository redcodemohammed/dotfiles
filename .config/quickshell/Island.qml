import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The island, drawn as a notch (owner, 2026-10-15): joined to the screen's top edge in the bar's
// colour, it reaches down over the 6px gap to the bar's bottom edge; compact content sits 4px into
// the bar, expanded grows down with rounded bottom corners. No border, except a red one for
// alert states (its top line sits just off-screen). It slides down from the edge
// when it appears and back up when it goes. Width, height and the slide animate 120ms linear;
// contents swap instantly. Centred, main screen only. Floats over windows, never takes keyboard
// focus, hidden in true fullscreen. The window is click-through outside the notch.
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

    readonly property int barTop: 6     // the bar floats this far down (Bar.qml margins)
    readonly property int barHeight: 32 // Bar.qml implicitHeight
    readonly property int edge: 2       // notch border; its top line sits off-screen
    readonly property int ear: 24       // the notch flares into the screen edge with concave corners

    // Shown, or still sliding out. What the notch shows is kept while it slides out, so it
    // leaves with its content and size instead of collapsing first.
    readonly property bool wanted: isMain && IslandState.kind !== "" && !fullscreen
    property bool leaving: false
    onWantedChanged: if (!wanted) leaving = true
    property string shownKind: ""
    property var shownSize: [0, 0]
    property bool shownOpen: false
    function keep() {
        if (IslandState.kind === "")
            return
        shownKind = IslandState.kind
        shownSize = IslandState.size
        shownOpen = IslandState.open
    }
    readonly property var live: [IslandState.kind, IslandState.size, IslandState.open]
    onLiveChanged: keep()
    Component.onCompleted: keep()

    visible: wanted || leaving
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore // starts at the screen edge, over the bar's reserved strip
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    implicitWidth: 640 + 2 * (ear + edge) // widest state (media) plus a shoulder on each side
    implicitHeight: barTop + 256
    mask: Region { item: pill }


    Rectangle {
        id: pill // the notch: joined to the screen's top edge (y = -edge hides the top border)
        anchors.horizontalCenter: parent.horizontalCenter
        // Shown: top border just off-screen. Hidden: fully above the screen, so it slides in from there.
        y: root.wanted ? -root.edge : -(height + root.edge)
        width: root.shownSize[0]
        // The state's own box. Notifications size to their content (body, Earlier list, Arabic).
        readonly property real contentHeight: root.shownKind === "notify"
            ? notify.implicitHeight + 4 : root.shownSize[1]
        // Compact reaches the bar's bottom edge; expanded is the gap plus the state's box.
        height: root.edge + (root.shownOpen ? root.barTop + contentHeight : root.barTop + root.barHeight)
        clip: true
        color: Theme.bg
        bottomLeftRadius: 12
        bottomRightRadius: 12
        readonly property var info: IslandState.active ? IslandState.active.data : ({})
        readonly property bool alert: root.shownKind === "record"
            || (root.shownKind === "build" && info.failed)
            || (root.shownKind === "notify" && info.entry && info.entry.urgent)
            || (root.shownKind === "battery" && IslandState.batteryCritical)
        border.width: alert ? root.edge : 0 // no border normally (owner: it looked bad), red for alerts
        border.color: Theme.alert

        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.Linear } }
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.Linear } }
        Behavior on y {
            NumberAnimation {
                duration: 120
                easing.type: Easing.Linear
                onRunningChanged: if (!running && !root.wanted) root.leaving = false
            }
        }

        // Compact: the whole notch expands it.
        MouseArea {
            anchors.fill: parent
            visible: !IslandState.open
            onClicked: IslandState.expand()
        }

        // The state's content, below the gap. Compact: centred in the bar (4px into it).
        Item {
            id: content
            y: root.edge + (root.shownOpen ? root.barTop : root.barTop + (root.barHeight - pill.contentHeight) / 2)
            width: parent.width
            height: pill.contentHeight

            IslandVolume {
                anchors.fill: parent
                visible: root.shownKind === "volume" || root.shownKind === "brightness"
                open: root.shownOpen
            }

            IslandNotify {
                id: notify
                anchors.fill: parent
                visible: root.shownKind === "notify"
                entry: pill.info.entry ?? null
            }

            IslandBattery {
                anchors.fill: parent
                visible: root.shownKind === "battery"
                open: root.shownOpen
            }

            IslandMedia {
                anchors.fill: parent
                visible: root.shownKind === "media"
                open: root.shownOpen
            }

            IslandBuild {
                anchors.fill: parent
                visible: root.shownKind === "build"
                open: root.shownOpen
                info: pill.info
            }

            // Placeholder content for states not built yet (recording).
            Text {
                visible: ["volume", "brightness", "battery", "media", "notify", "build"].indexOf(root.shownKind) < 0
                x: root.shownOpen ? 12 : 8
                y: root.shownOpen ? 12 : (parent.height - height) / 2
                text: root.shownKind + (root.shownOpen ? " · expanded" : "")
                    + (IslandState.queued ? " · 1 queued" : "")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: root.shownOpen ? 14 : 13
                color: Theme.fg
            }

            // Expanded: chevron top right collapses (dismisses a transient).
            // Notifications close with their own Dismiss button instead.
            Item {
                visible: root.shownOpen && root.shownKind !== "notify"
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

    // Shoulders: the notch flares into the screen's top edge (IslandEar.qml). Declared after the
    // notch so they paint over the top of its side border. They follow its
    // width and slide; their curve gets the red border only for alerts.
    IslandEar {
        x: pill.x - root.ear
        y: pill.y + root.edge
        radius: root.ear
        edge: root.edge
        border: pill.alert ? Theme.alert : "transparent"
    }
    IslandEar {
        x: pill.x + pill.width - root.edge
        y: pill.y + root.edge
        radius: root.ear
        edge: root.edge
        border: pill.alert ? Theme.alert : "transparent"
        mirrored: true
    }
}
