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

    readonly property string bellSimple: ""
    readonly property string bellSlash: ""

    readonly property string caretUp: "\ue13c" // island collapse chevron
    readonly property string check: "\ue182" // build ok
    readonly property string cross: "\ue4f6" // build failed

    readonly property string batteryFull: "\ue0c0"
    readonly property string batteryHigh: "\ue0c2"
    readonly property string batteryMedium: "\ue0c6"
    readonly property string batteryLow: "\ue0c4"
    readonly property string batteryCharging: "\ue0ba" // on AC
    readonly property string batteryWarning: "\ue0c8" // critical, 10% or less on battery

    readonly property string sun: "\ue472" // island brightness
}
