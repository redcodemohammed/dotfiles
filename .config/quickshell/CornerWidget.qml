import QtQuick
import QtQuick.Shapes
import Quickshell

// The corner widget (owner, 2026-10-20, from the mockup): CPU, memory and root disk use as three
// rings (SystemStats.qml, as the bar's system chip), out of the frame's bottom-right corner in the
// frame colour, joined to the bottom and right sides by inward curves: the island's shape turned
// round (a half turn keeps every arc's direction). Under windows like the frame (the bottom
// layer): an empty workspace shows it. Click-through. Grows out of the corner when it appears.
// One screen: Settings > Look > Corner widget picks it by model ("" the main screen, "off" none).
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    readonly property string mainModel: Quickshell.env("DESKTOP_MAIN_MODEL") ?? ""
    readonly property string chosen: Settings.look.cornerScreen !== "" ? Settings.look.cornerScreen
        : mainModel !== "" ? mainModel : (Quickshell.screens.length > 0 ? Quickshell.screens[0].model : "")
    readonly property bool wanted: chosen === modelData.model
    property bool leaving: false
    onWantedChanged: if (!wanted) leaving = Settings.look.animations
    visible: wanted || leaving

    anchors { bottom: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    mask: Region {}
    color: "transparent"

    readonly property int side: Settings.look.frame // the frame's right side
    // The frame's bottom side: the bar's band on a portrait screen, where the bar sits at the
    // bottom (Bar.qml's onlyWorkspaces, while that bar shows), else as wide as the others.
    readonly property bool bandBelow: modelData.height > modelData.width
        && (Settings.bar.otherScreens || Quickshell.screens.length === 1 || mainModel === "" || modelData.model === mainModel)
    readonly property int floorSide: bandBelow ? 44 : side
    readonly property int radius: Settings.look.frameRadius
    readonly property int boxWidth: rings.implicitWidth + 40
    readonly property int boxHeight: rings.implicitHeight + 40
    implicitWidth: side + boxWidth + radius + 32 // room for the spring's overshoot
    implicitHeight: floorSide + boxHeight + radius + 32

    // The box's size; nothing while away, so it grows out of the corner.
    property bool shown: false
    Component.onCompleted: shown = true
    property real w: shown && wanted ? boxWidth : 0
    property real h: shown && wanted ? boxHeight : 0
    Behavior on w {
        enabled: Settings.look.animations
        NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.3, 0.64, 1, 1, 1] } // hyprland.lua "spring"
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

    // The drawing, in window coordinates from the bottom-right corner: the box's top-left corner
    // rounded, an inward curve into the bottom side (left) and into the right side (top).
    Shape {
        id: drawing
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real w: Math.max(0, root.w)
        readonly property real h: Math.max(0, root.h)
        readonly property real r: Math.min(root.radius, w / 2, h / 2)
        readonly property real inner: root.width - root.side   // the right side's inner edge
        readonly property real floor: root.height - root.floorSide // the bottom side's inner edge
        readonly property real boxLeft: inner - w
        readonly property real boxTop: floor - h
        ShapePath {
            fillColor: Edge.fill
            strokeColor: "transparent"
            strokeWidth: 0
            startX: root.width
            startY: drawing.floor
            PathLine { x: drawing.boxLeft - drawing.r; y: drawing.floor }
            PathArc { // inward, into the bottom side
                x: drawing.boxLeft; y: drawing.floor - drawing.r
                radiusX: drawing.r; radiusY: drawing.r
                direction: PathArc.Counterclockwise
            }
            PathLine { x: drawing.boxLeft; y: drawing.boxTop + drawing.r }
            PathArc { // the box's own corner
                x: drawing.boxLeft + drawing.r; y: drawing.boxTop
                radiusX: drawing.r; radiusY: drawing.r
                direction: PathArc.Clockwise
            }
            PathLine { x: drawing.inner - drawing.r; y: drawing.boxTop }
            PathArc { // inward, into the right side
                x: drawing.inner; y: drawing.boxTop - drawing.r
                radiusX: drawing.r; radiusY: drawing.r
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width; y: drawing.boxTop - drawing.r }
            PathLine { x: root.width; y: drawing.floor }
        }
    }

    Item { // the box, revealed from the corner as it grows
        x: drawing.boxLeft
        y: drawing.boxTop
        width: drawing.w
        height: drawing.h
        clip: true
        Row {
            id: rings
            x: 20
            y: 20
            spacing: 20
            Ring { label: "CPU"; value: SystemStats.cpu; hue: Theme.fg }
            Ring { label: "RAM"; value: SystemStats.mem; hue: Theme.fg }
            Ring { label: "DISK"; value: SystemStats.rootDisk; hue: Theme.fg }
        }
    }

    // One reading: a 64px ring (a faint track, the used share in the hue, round ends from the top,
    // clockwise) with the percent inside and its name under it. The hue is gray for all three
    // (owner, 2026-10-25: less colour; three hues before).
    component Ring: Column {
        id: ring
        property string label
        property real value // percent
        property color hue
        spacing: 8
        Item {
            width: 64
            height: 64
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(ring.hue.r, ring.hue.g, ring.hue.b, 0.2)
                    strokeWidth: 6
                    fillColor: "transparent"
                    PathAngleArc { centerX: 32; centerY: 32; radiusX: 28; radiusY: 28; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: ring.hue
                    strokeWidth: 6
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 32; centerY: 32; radiusX: 28; radiusY: 28
                        startAngle: -90 // from the top
                        sweepAngle: 360 * Math.max(0, Math.min(ring.value, 100)) / 100
                        Behavior on sweepAngle {
                            enabled: Settings.look.animations
                            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: Math.round(ring.value)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: ring.hue
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: Theme.fgMuted
        }
    }
}
