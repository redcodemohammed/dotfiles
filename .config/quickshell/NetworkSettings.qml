import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// The network panel's Settings tab (owner's design "Network manager"; regrouped 2026-10-17 by what
// each setting affects). Connection: a card per active connection, Wi-Fi and Ethernet
// (NetworkConnCard.qml; an Ethernet card carries its profile's settings). A Wi-Fi network's own
// settings (Auto-connect, Metered, DNS, Share, Forget) are on its row in the Wi-Fi tab
// (NetworkRow.qml, NetworkProfile.qml); the hotspot has its tab (NetworkHotspot.qml). This device:
// Airplane mode (all radios, rfkill). The cards add Internet (NetState; "OK" with a ping to
// 1.1.1.1), and a click on a card row copies its value (wl-copy).
Column {
    id: root
    required property var panel
    readonly property var net: panel.wifi ? (panel.wifi.networks.values.find(n => n.connected) ?? null) : null
    readonly property string device: panel.wifi ? panel.wifi.name : ""
    readonly property var wired: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var scan: net ? (panel.info[net.name] ?? null) : null
    readonly property bool live: panel.visible && panel.tab === "settings"
    onLiveChanged: if (live && NetState.internet === "ok" && !pinger.running) pinger.running = true

    // Active connections, Wi-Fi first: { kind, device, title }
    readonly property var conns: (net ? [{ kind: "wifi", device: device, title: net.name }] : [])
        .concat(wired.filter(d => d.connected).map(d => ({ kind: "wired", device: d.name, title: "Ethernet · " + d.name })))

    property string latency: ""
    Process {
        id: pinger
        command: ["ping", "-c", "1", "-W", "2", "-n", "1.1.1.1"]
        stdout: StdioCollector {
            id: pingOut
            onStreamFinished: {
                const m = pingOut.text.match(/time=([0-9.]+)/)
                root.latency = m ? Math.round(Number(m[1])) + " ms" : ""
            }
        }
    }
    readonly property string internetText: NetState.internet === "ok" ? "OK" + (latency ? " · " + latency : "")
        : NetState.internet === "portal" ? "Sign-in required" : "No internet"

    // Click a card row to copy its value.
    property string copied: ""
    function copy(key, value) {
        copier.command = ["wl-copy", "--", value]
        copier.running = true
        copied = key
        copiedTimer.restart()
    }
    Process { id: copier }
    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copied = ""
    }

    spacing: 8

    PanelCaption { text: "Connection" }
    Text {
        visible: root.conns.length === 0
        text: "Not connected"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fg
    }
    Repeater {
        model: root.conns
        NetworkConnCard {
            required property var modelData
            conn: modelData
            settings: root
        }
    }

    PanelCaption { text: "This device" }
    PanelSwitchRow {
        label: "Airplane mode"
        on: root.panel.airplane
        onToggled: root.panel.setAirplane(!root.panel.airplane)
    }
}
