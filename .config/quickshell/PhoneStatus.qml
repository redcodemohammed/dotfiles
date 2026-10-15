import QtQuick
import QtQuick.Shapes

// The bar's phone glyph (owner's design "Phone bridge", 2026-10-15), drawn from the design's SVG
// paths: a square phone outline in grey; a grey slash while the phone isn't connected; an accent
// square top right while it has unread notifications (amber = unread). The block shows on the
// full bar while a phone is paired (Bar.qml).
Item {
    implicitWidth: 16
    implicitHeight: 16

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.5
            strokeColor: Theme.fgMuted
            fillColor: "transparent"
            PathSvg { path: "M4 1.5h8v13h-8zM7 12.5h2" }
        }
        ShapePath {
            strokeWidth: 1.5
            strokeColor: Phone.connected ? "transparent" : Theme.fgMuted
            fillColor: "transparent"
            PathSvg { path: "M2.5 2.5l11 11" }
        }
    }
    Rectangle { // unread
        visible: Phone.connected && Phone.unread > 0
        x: 10.5
        y: 0
        width: 5.5
        height: 5.5
        color: Theme.accent
    }
}
