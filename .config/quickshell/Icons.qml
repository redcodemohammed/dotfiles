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

    // Island media
    readonly property string equalizer: "" // compact pill ("bars")
    readonly property string musicNote: "" // no cover art
    readonly property string play: ""
    readonly property string pause: ""
    readonly property string skipBack: ""
    readonly property string skipForward: ""
    readonly property string shuffle: ""
    readonly property string repeat: ""
    readonly property string repeatOnce: ""
    readonly property string microphoneStage: "" // lyrics

    // Recording
    readonly property string record: ""
    readonly property string stop: ""

    // Power profiles (island battery pill)
    readonly property string leaf: "" // Saver
    readonly property string scales: "" // Balanced
    readonly property string lightning: "" // Performance

    // Battery glyph for a level 0-100, shared by the bar and the island.
    function battery(level, onBattery, critical) {
        return !onBattery ? batteryCharging
            : critical ? batteryWarning
            : level > 90 ? batteryFull
            : level > 60 ? batteryHigh
            : level > 30 ? batteryMedium
            : batteryLow
    }

    readonly property string sun: "\ue472" // island brightness
}
