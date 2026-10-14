import QtQuick
import QtQuick.Shapes

// A notch shoulder (owner, 2026-10-15): where the island meets the screen's top edge it flares out
// with a concave corner. Filled in the notch colour over the notch's own side border at the top;
// the border continues along the curve into that side border. Mirrored for the right side.
// Local x = radius is the notch's outer side.
Shape {
    id: ear
    property int radius: 10
    property int edge: 2
    property color fill: Theme.bg
    property color border: Theme.border
    property bool mirrored: false

    width: radius + edge
    height: radius
    preferredRendererType: Shape.CurveRenderer
    transform: Scale { xScale: ear.mirrored ? -1 : 1; origin.x: ear.width / 2 }

    ShapePath { // screen edge -> over the notch's side -> back along the curve
        strokeColor: "transparent"
        fillColor: ear.fill
        startX: 0
        startY: 0
        PathLine { x: ear.radius + ear.edge; y: 0 }
        PathLine { x: ear.radius + ear.edge; y: ear.radius }
        PathLine { x: ear.radius; y: ear.radius }
        PathArc { x: 0; y: 0; radiusX: ear.radius; radiusY: ear.radius; direction: PathArc.Counterclockwise }
    }
    ShapePath { // the border along the curve, ending in the middle of the notch's side border
        strokeColor: ear.border
        strokeWidth: ear.edge
        fillColor: "transparent"
        startX: 0
        startY: 0
        PathArc {
            x: ear.radius + ear.edge / 2
            y: ear.radius + ear.edge / 2
            radiusX: ear.radius + ear.edge / 2
            radiusY: ear.radius + ear.edge / 2
        }
    }
}
