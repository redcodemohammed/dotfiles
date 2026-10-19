import QtQuick
import QtQuick.Shapes
import Quickshell

// The frame round the desktop (owner, 2026-10-20): an edge on all four sides with rounded inner
// corners, that the bar, the island and the panels grow out of. One window per screen (Bar.qml
// makes it), under the windows and over the wallpaper, taking no input. It is one shape: the
// screen's rectangle with a rounded rectangle cut out of it (OddEvenFill: where the two overlap,
// nothing is filled). The top side is the bar's band (`top`), the others Settings.look.frame
// wide. Windows keep clear of it through Hyprland: the bar reserves the top, and hyprland.lua
// widens gaps_out on the other sides by the same width. A floating window can still cover it.
PanelWindow {
    id: frame
    property int top: Settings.look.frame // the bar's height, while the bar shows
    readonly property int side: Settings.look.frame
    readonly property int radius: Settings.look.frameRadius

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore // the whole screen, the bar's reserved strip too
    aboveWindows: false                 // the bottom layer: windows and the bar draw over it
    mask: Region {}                     // no input: clicks reach the desktop beneath
    color: "transparent"

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer // smooth curves without multisampling
        ShapePath {
            fillColor: Edge.fill // the accent-tinted bar colour, shared with the island
            strokeColor: "transparent"
            strokeWidth: 0
            fillRule: ShapePath.OddEvenFill
            PathRectangle {
                width: frame.width
                height: frame.height
            }
            PathRectangle {
                x: frame.side
                y: frame.top
                width: frame.width - 2 * frame.side
                height: frame.height - frame.top - frame.side
                radius: frame.radius
            }
        }
    }
}
