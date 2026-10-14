import QtQuick
import Quickshell.Networking

// Online? Icon only. Gray when connected, red slash when down.
// The Networking module loads lazily from NetworkManager, so this starts
// as "down" for a moment and settles once the devices arrive.
Text {
    readonly property var devices: Networking.devices.values
    readonly property var active: devices.find(d => d.connected) ?? null
    readonly property bool hasWifi: devices.some(d => d.type === DeviceType.Wifi)
    readonly property bool online: active !== null
        && Networking.connectivity !== NetworkConnectivity.None

    text: online ? (active.type === DeviceType.Wifi ? Icons.wifiHigh : Icons.network)
        : hasWifi ? Icons.wifiSlash
        : Icons.networkSlash
    font.family: Icons.regular
    font.pixelSize: 16
    color: online ? Theme.fgMuted : Theme.alert
}
