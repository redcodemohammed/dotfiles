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
    readonly property string caretLeft: "\ue138"  // the bar tray, folded
    readonly property string caretRight: "\ue13a" // the bar tray, open
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
    readonly property string power: "\ue3da" // power panel: the bar block, Shut down
    readonly property string wrench: "\ue5d4" // tools panel: the bar block
    readonly property string signOut: "\ue42a" // power panel: Log out
    readonly property string moon: "\ue330" // power panel: Sleep
    readonly property string eyedropper: "\ue568" // tools panel: Pick colour
    readonly property string textT: "\ue48a" // tools panel: Text from screen
    readonly property string timer: "\ue492" // Pomodoro focus
    readonly property string coffee: "\ue1c2" // Pomodoro break
    readonly property string arrowCounterClockwise: "\ue038" // Pomodoro reset
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

    // Network panel
    readonly property string arrowClockwise: "\ue036" // rescan
    readonly property string magnifyingGlass: "\ue30c" // search
    readonly property string lock: "\ue2fa" // secured network
    readonly property string eye: "\ue220" // show password
    readonly property string eyeSlash: "\ue224" // hide password
    readonly property string warningCircle: "\ue4e2" // connection failed
    readonly property string plus: "\ue3d4" // join hidden network
    readonly property string qrCode: "\ue3e6" // share network
    readonly property string shield: "\ue40a" // VPN profile (Fill while on)

    // Bar: Bluetooth, and the capture indicator (Fill, red, while live)
    readonly property string bluetooth: "\ue0da"
    readonly property string bluetoothConnected: "\ue0dc"
    readonly property string bluetoothSlash: "\ue0de"
    readonly property string microphone: "\ue326"
    readonly property string microphoneSlash: "\ue328" // a muted app in the sound panel
    readonly property string webcam: "\ue9b2"

    // Workspaces visiting from a screen that is gone (lid shut): where they belong
    readonly property string laptop: "\ue586"
    readonly property string monitor: "\ue32e"

    // Phone panel actions
    readonly property string bellRinging: "\ue5e8"
    readonly property string clipboardText: "\ue198"
    readonly property string uploadSimple: "\ue4c0"
    readonly property string phoneIncoming: "\ue3be" // the phone's incoming-call card
    readonly property string folderOpen: "\ue256" // browse phone files

    // Wi-Fi signal level 1-4 from Quickshell's strength (0-1), for the bar block and the panel.
    function wifiLevel(strength) {
        return strength >= 0.75 ? 4 : strength >= 0.5 ? 3 : strength >= 0.3 ? 2 : 1
    }
}
