import QtQuick
import QtQuick.Shapes

// The bar's phone glyph (owner's design "Phone bridge", 2026-10-15), drawn from the design's SVG
// paths: a square phone outline; a slash while the phone isn't connected; a square top right
// while it has unread notifications. In its chip's hue (BarChip.qml, owner 2026-10-20): full
// with unread, dimmed otherwise. The chip shows on the full bar while a phone is paired (Bar.qml).
Item {
    id: root
    property color hue: Theme.fgMuted
    readonly property bool lit: Phone.connected && Phone.unread > 0
    readonly property color ink: lit ? hue : Qt.rgba(hue.r, hue.g, hue.b, 0.6)
    implicitWidth: 16
    implicitHeight: 16

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.5
            strokeColor: root.ink
            fillColor: "transparent"
            PathSvg { path: "M4 1.5h8v13h-8zM7 12.5h2" }
        }
        ShapePath {
            strokeWidth: 1.5
            strokeColor: Phone.connected ? "transparent" : root.ink
            fillColor: "transparent"
            PathSvg { path: "M2.5 2.5l11 11" }
        }
    }
    Rectangle { // unread
        visible: root.lit
        x: 10.5
        y: 0
        width: 5.5
        height: 5.5
        color: root.ink
    }
}
