import QtQuick
import QtQuick.Shapes
import Quickshell.Hyprland

// A bar panel that comes out of the frame (owner, 2026-10-20; Reveal.qml slid a bordered surface
// before): the panel's body hangs from the band's bottom edge under its chip, in the frame's
// colour (Edge.fill), its bottom corners rounded and its top joined to the band by an inward curve
// on either side, as the open island joins the corner. Open: it grows down out of the band on the
// window spring (only the height; the content is revealed from the top, clipped); close: it
// shrinks back into it, then the window hides. Off with Settings > Look > Animations.
// It does Reveal's other jobs too: an outside click closes it (HyprlandFocusGrab: the panel sets
// grabFocus: false), opening it closes any other panel (Panels.claim), and closing has to go
// through close(), not `visible = false`, so the shrink can play.
// Inside the panel: `EdgePanel { id: reveal; window: panel; bodyWidth: ..; bodyHeight: .. }` holding
// the content; the popup takes its size, `mask: Region { item: reveal.area }`, and is anchored so
// its top is the band's bottom edge (anchor.rect.y: block.height + 6, the chip 6px under the
// band's top) and the body lines up with the chip (the curves stick out `r` either side).
Item {
    id: edge
    required property var window // the PopupWindow
    default property alias content: body.data
    property real bodyWidth: 300
    property real bodyHeight: 200
    readonly property int r: Settings.look.frameRadius
    readonly property alias area: body // the panel's own box: the popup's input region
    readonly property bool closing: shrinking

    implicitWidth: bodyWidth + 2 * r
    implicitHeight: bodyHeight + 32 // room for the spring's overshoot

    property bool open: false
    property bool shrinking: false
    function close() {
        if (!window.visible || shrinking)
            return
        open = false
        if (Settings.look.animations)
            shrinking = true
        else
            window.visible = false
    }

    // The body's height; nothing while closed, so it grows out of the band. The spring overshoots,
    // so a shrink can pass below zero: the drawing clamps it.
    property real h: open ? bodyHeight : 0
    Behavior on h {
        enabled: Settings.look.animations && edge.window.visible
        NumberAnimation {
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: edge.open ? [0.34, 1.3, 0.64, 1, 1, 1] // hyprland.lua "spring"
                : [0.36, 0, 0.66, -0.3, 1, 1] // "spring" played backwards
            onRunningChanged: if (!running && edge.shrinking) {
                edge.shrinking = false
                edge.window.visible = false
            }
        }
    }

    Connections {
        target: Panels
        function onCurrentChanged() {
            if (Panels.current !== edge && edge.window.visible)
                edge.close()
        }
    }
    HyprlandFocusGrab {
        windows: [edge.window]
        active: edge.window.visible
        onCleared: edge.close()
    }
    Connections {
        target: edge.window
        function onVisibleChanged() {
            if (!edge.window.visible) { // hidden from outside: closed at once, ready to grow again
                edge.shrinking = false
                edge.open = false
                return
            }
            Panels.claim(edge) // any other open panel closes
            edge.open = true
        }
    }

    // The drawing: the body from x r to r + bodyWidth, its bottom corners rounded, and the inward
    // curves at the top into the band. One radius for all four, the frame's, smaller while the
    // body is too short for it.
    Shape {
        id: drawing
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real h: Math.max(0, edge.h)
        readonly property real rr: Math.min(edge.r, h / 2, edge.bodyWidth / 2)
        readonly property real bodyLeft: edge.r
        readonly property real bodyRight: edge.r + edge.bodyWidth
        ShapePath {
            fillColor: Edge.fill
            strokeColor: "transparent"
            strokeWidth: 0
            startX: drawing.bodyLeft - drawing.rr
            startY: 0
            PathLine { x: drawing.bodyRight + drawing.rr; y: 0 }
            PathArc { // inward, into the band
                x: drawing.bodyRight; y: drawing.rr
                radiusX: drawing.rr; radiusY: drawing.rr
                direction: PathArc.Counterclockwise
            }
            PathLine { x: drawing.bodyRight; y: drawing.h - drawing.rr }
            PathArc {
                x: drawing.bodyRight - drawing.rr; y: drawing.h
                radiusX: drawing.rr; radiusY: drawing.rr
                direction: PathArc.Clockwise
            }
            PathLine { x: drawing.bodyLeft + drawing.rr; y: drawing.h }
            PathArc {
                x: drawing.bodyLeft; y: drawing.h - drawing.rr
                radiusX: drawing.rr; radiusY: drawing.rr
                direction: PathArc.Clockwise
            }
            PathLine { x: drawing.bodyLeft; y: drawing.rr }
            PathArc { // inward, into the band
                x: drawing.bodyLeft - drawing.rr; y: 0
                radiusX: drawing.rr; radiusY: drawing.rr
                direction: PathArc.Counterclockwise
            }
        }
    }

    Item {
        id: body // the content at its full size, revealed from the top as the body grows
        x: edge.r
        width: edge.bodyWidth
        height: Math.max(0, edge.h)
        clip: true
    }
}
