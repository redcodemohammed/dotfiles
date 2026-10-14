pragma Singleton
import QtQuick
import Quickshell

// Phosphor glyphs. Code points from phosphor-icons/web v2.1.2, src/regular/style.css
// (same code points in the Fill weight). Use with font.family regular or fill.
Singleton {
    readonly property string regular: "Phosphor"
    readonly property string fill: "Phosphor-Fill"

    readonly property string speakerHigh: ""
    readonly property string speakerLow: ""
    readonly property string speakerNone: ""
    readonly property string speakerSlash: ""

    readonly property string network: ""
    readonly property string networkSlash: ""
    readonly property string wifiHigh: ""
    readonly property string wifiSlash: ""
}
