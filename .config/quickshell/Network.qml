import QtQuick
import QtQuick.Shapes
import Quickshell.Networking

// The bar's network glyph, the spec's "Online?" item, drawn from the owner's "Network manager"
// design (2026-10-15) with its own SVG paths, in its chip's hue (owner, 2026-10-20). Wi-Fi
// connected: three arcs and a dot, lit by signal level, the rest faint. Wi-Fi on but nothing connected: unlit arcs and a
// red slash (network down). Wi-Fi off: a slash. A wired connection without Wi-Fi shows the
// network glyph instead; no Wi-Fi card and no wire: a red network slash. Connected but the
// internet fails: a "!" top right, red for no internet, light for a sign-in page (NetState).
// Anything red turns the whole chip red: `ink` is the alert colour then. A VPN
// on: a small light square bottom right. The
// block opens the network panel (Bar.qml). Networking loads lazily: down for a moment at start.
Item {
    id: root
    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wired: devices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool showWired: wired && wifiNet === null
    readonly property bool down: wifiNet === null && !wired && Networking.wifiEnabled
    readonly property int level: wifiNet ? Icons.wifiLevel(wifiNet.signalStrength) : 0
    property color hue: Theme.fgMuted
    readonly property bool failing: down || (wifi === null && !showWired) || NetState.internet === "none"
    readonly property color ink: failing ? Theme.alert : hue
    readonly property color lit: hue
    readonly property color unlit: Qt.rgba(hue.r, hue.g, hue.b, 0.3)

    implicitWidth: 16
    implicitHeight: 16

    Text {
        visible: root.showWired || root.wifi === null
        anchors.centerIn: parent
        text: root.showWired ? Icons.network : Icons.networkSlash
        font.family: Icons.regular
        font.pixelSize: 16
        color: root.ink
    }

    Shape {
        visible: !root.showWired && root.wifi !== null
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.5
            strokeColor: root.level >= 4 ? root.lit : root.unlit
            fillColor: "transparent"
            PathSvg { path: "M2 6.5a9 9 0 0112 0" }
        }
        ShapePath {
            strokeWidth: 1.5
            strokeColor: root.level >= 3 ? root.lit : root.unlit
            fillColor: "transparent"
            PathSvg { path: "M4 9a6 6 0 018 0" }
        }
        ShapePath {
            strokeWidth: 1.5
            strokeColor: root.level >= 2 ? root.lit : root.unlit
            fillColor: "transparent"
            PathSvg { path: "M6 11a3 3 0 014 0" }
        }
        ShapePath { // the slash: red when down, grey when Wi-Fi is off
            strokeWidth: 1.5
            strokeColor: root.down ? Theme.alert : !Networking.wifiEnabled ? root.lit : "transparent"
            fillColor: "transparent"
            PathSvg { path: "M2.5 2.5l11 11" }
        }
    }
    Shape { // "!" top right: no internet (red) or a sign-in page (light)
        visible: NetState.internet === "none" || NetState.internet === "portal"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.5
            strokeColor: NetState.internet === "none" ? Theme.alert : Theme.fg
            fillColor: "transparent"
            PathSvg { path: "M13 1.5v3.5M13 6.5v.6" }
        }
    }
    Rectangle { // the dot under the arcs
        visible: !root.showWired && root.wifi !== null
        x: 6.9
        y: 12.1
        width: 2.2
        height: 2.2
        radius: 1.1
        color: root.level >= 2 ? root.lit : root.unlit
    }
    Rectangle { // VPN on
        visible: NetState.vpnOn
        x: 10.5
        y: 10.5
        width: 5.5
        height: 5.5
        color: Theme.fg
    }
}
