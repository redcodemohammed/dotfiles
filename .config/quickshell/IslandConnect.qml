import QtQuick

// Island Wi-Fi and Bluetooth events (owner, 2026-10-15), compact only, 260x24 like the battery
// pill: the network or device name, then a muted word (Connected, Lost, Disconnected, or a
// device's battery) and the glyph. Wi-Fi lost is red only when nothing else is connected (network
// down, spec). A click opens the network panel or bluetui (IslandState.click). Keeps its last
// content while the island slides out.
Item {
    id: root
    property var shown: null // { what: "wifi" | "bt", on, name, device }
    readonly property var live: IslandState.active && IslandState.active.kind === "connect" ? IslandState.active.data : null
    onLiveChanged: if (live) shown = live

    readonly property bool wifi: shown !== null && shown.what === "wifi"
    readonly property bool on: shown !== null && shown.on
    readonly property bool down: wifi && !on && !NetState.linkUp
    readonly property var device: shown !== null && shown.what === "bt" ? shown.device : null
    readonly property string detail: {
        if (shown === null)
            return ""
        if (wifi)
            return on ? "Connected" : "Lost"
        if (on && device && device.batteryAvailable)
            return Math.round(device.battery * 100) + "%"
        return on ? "Connected" : "Disconnected"
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - right.width - 8
            text: root.shown ? root.shown.name : ""
            elide: Text.ElideRight
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        Row {
            id: right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.detail
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifi ? (root.on ? Icons.wifiHigh : Icons.wifiSlash)
                    : root.on ? Icons.bluetoothConnected : Icons.bluetooth
                font.family: root.down ? Icons.fill : Icons.regular
                font.pixelSize: 16
                color: root.down ? Theme.alert : Theme.fg
            }
        }
    }
}
