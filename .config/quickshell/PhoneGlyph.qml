import QtQuick
import QtQuick.Shapes

// The design's phone outline ("Phone bridge" board), square like the rest of the desktop, at any
// size: the bar block draws it at 16, the panel header at 24 (thinner stroke, as in the design).
Shape {
    id: glyph
    property real size: 16
    property color color: Theme.fg
    property real stroke: 1.5
    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: glyph.stroke
        strokeColor: glyph.color
        fillColor: "transparent"
        scale: Qt.size(glyph.size / 16, glyph.size / 16)
        PathSvg { path: "M4 1.5h8v13h-8zM7 12.5h2" }
    }
}
