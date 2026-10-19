import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The island's open form, part of the frame (owner, 2026-10-20; a notch at the top centre
// before): it grows out of the screen's top-left corner, under the bar's band, in the frame's
// colour (Edge.fill), joined to the band and the left side by inward curves. Compact lives in
// the band, on a block after the launcher (Bar.qml), so it never covers a window. The open form
// grows from nothing out of the corner and shrinks back into it, on the window spring.
// An alert (recording, a failed build, an urgent notification, a critical battery) turns the
// fill red (Edge.alertFill). On the focused screen. Floats over windows, never takes keyboard
// focus, hidden in true fullscreen. The window is click-through outside the island.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    // Shown on the focused screen (owner, 2026-10-15; it used to be pinned to the G5): moving
    // focus shrinks it on one screen and grows it on the other.
    readonly property bool focusedScreen: monitor !== null && monitor.focused
    readonly property bool fullscreen: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.hasFullscreen : false

    readonly property int band: 44      // the bar's height (Bar.qml): the island starts under it
    readonly property int side: Settings.look.frame // the frame's side: the island starts inside it
    readonly property int maxWidth: 640 // widest state (media)

    // Shown, or still shrinking away. What the island shows is kept while it goes, so it
    // leaves with its content instead of collapsing first.
    readonly property bool wanted: focusedScreen && IslandState.kind !== "" && IslandState.open && !fullscreen
    property bool leaving: false
    onWantedChanged: if (!wanted) leaving = Settings.look.animations
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
    anchors.left: true
    exclusionMode: ExclusionMode.Ignore // starts at the screen edge, over the bar's reserved strip
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    implicitWidth: side + maxWidth + 32 // room for the inward curve on the right (frame corners max 32)
    implicitHeight: band + Math.max(324, IslandState.volumeHeight) + 32 // tallest: recording setup or volume
    mask: Region { item: body }

    // The state's own box. Notifications size to their content (body, Earlier list, Arabic) and
    // are wider with a row of actions (IslandNotify.wantedWidth), up to maxWidth.
    readonly property real boxWidth: shownKind === "notify" && shownOpen
        ? Math.min(maxWidth, notify.wantedWidth) : shownSize[0]
    readonly property real boxHeight: shownKind === "notify" ? notify.implicitHeight + 4 : shownSize[1]
    readonly property var info: IslandState.active ? IslandState.active.data : ({})
    readonly property bool alert: shownKind === "record"
        || (shownKind === "build" && info.failed)
        || (shownKind === "notify" && info.entry && info.entry.urgent)
        || (shownKind === "battery" && IslandState.batteryCritical)

    // The island's size; nothing while it is away, so it grows out of the corner. The spring
    // overshoots, so a shrink can pass below zero: the drawing clamps it.
    property real w: wanted ? boxWidth : 0
    property real h: wanted ? boxHeight : 0
    // Size changes on the same small spring as Hyprland's windows: hyprland.lua's "spring" bezier.
    // Off with Settings > Look > Animations.
    Behavior on w {
        enabled: Settings.look.animations
        NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.3, 0.64, 1, 1, 1] }
    }
    Behavior on h {
        enabled: Settings.look.animations
        NumberAnimation {
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.3, 0.64, 1, 1, 1]
            onRunningChanged: if (!running && !root.wanted) root.leaving = false
        }
    }

    // The drawing: the island's box from the left screen edge (over the frame's side, the same
    // colour) with a rounded bottom-right corner, plus the two inward curves where it meets the
    // band (top right) and the frame's side (bottom left). Its radius is the frame's, smaller
    // while the island is too small for it.
    Shape {
        id: drawing
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real w: Math.max(0, root.w)
        readonly property real h: Math.max(0, root.h)
        readonly property real r: Math.min(Settings.look.frameRadius, w / 2, h / 2)
        readonly property real boxRight: root.side + w
        readonly property real boxBottom: root.band + h
        ShapePath {
            fillColor: root.alert ? Edge.alertFill : Edge.fill
            Behavior on fillColor { ColorAnimation { duration: 150 } }
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.band
            PathLine { x: drawing.boxRight + drawing.r; y: root.band }
            PathArc { // inward, into the band
                x: drawing.boxRight; y: root.band + drawing.r
                radiusX: drawing.r; radiusY: drawing.r
                direction: PathArc.Counterclockwise
            }
            PathLine { x: drawing.boxRight; y: drawing.boxBottom - drawing.r }
            PathArc { // the island's own corner
                x: drawing.boxRight - drawing.r; y: drawing.boxBottom
                radiusX: drawing.r; radiusY: drawing.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.side + drawing.r; y: drawing.boxBottom }
            PathArc { // inward, into the frame's side
                x: root.side; y: drawing.boxBottom + drawing.r
                radiusX: drawing.r; radiusY: drawing.r
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: drawing.boxBottom + drawing.r }
            PathLine { x: 0; y: root.band }
        }
    }

    Item {
        id: body // the island's box: takes the clicks (the mask) and clips the content as it grows
        x: root.side
        y: root.band
        width: Math.max(0, root.w)
        height: Math.max(0, root.h)
        clip: true

        // The state's content at its full size, revealed from the corner.
        Item {
            id: content
            width: root.boxWidth
            height: root.boxHeight

            IslandVolume {
                anchors.fill: parent
                visible: root.shownKind === "volume" || root.shownKind === "brightness"
                open: root.shownOpen
            }

            IslandNotify {
                id: notify
                anchors.fill: parent
                visible: root.shownKind === "notify"
                entry: root.info.entry ?? null
            }

            IslandBattery {
                anchors.fill: parent
                visible: root.shownKind === "battery"
                open: root.shownOpen
            }

            IslandConnect {
                anchors.fill: parent
                visible: root.shownKind === "connect"
            }

            IslandPomodoro {
                anchors.fill: parent
                visible: root.shownKind === "pomodoro"
            }

            IslandTimer {
                anchors.fill: parent
                visible: root.shownKind === "timer"
                open: root.shownOpen
            }

            IslandRecord {
                anchors.fill: parent
                visible: root.shownKind === "record" || root.shownKind === "recsetup"
                open: root.shownOpen
                setup: root.shownKind === "recsetup"
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
                info: root.info
            }

            // Placeholder content for states not built yet (recording).
            Text {
                visible: ["volume", "brightness", "battery", "connect", "media", "record", "recsetup", "notify", "build", "pomodoro", "timer"].indexOf(root.shownKind) < 0
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
}
