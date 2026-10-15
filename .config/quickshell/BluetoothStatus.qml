import QtQuick
import Quickshell.Bluetooth

// The bar's Bluetooth item (spec: "Connected?", icon only, grey). Off or blocked: the slash glyph;
// on: the plain glyph; a device connected: the connected glyph. The state changes the glyph, not
// the colour. Its block hides without an adapter and opens bluetui (Bar.qml, owner's choice).
// Named BluetoothStatus so it doesn't shadow Quickshell.Bluetooth's Bluetooth singleton.
Text {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.state === BluetoothAdapterState.Enabled
    readonly property bool connected: on && Bluetooth.devices.values.some(d => d.connected)

    text: !on ? Icons.bluetoothSlash : connected ? Icons.bluetoothConnected : Icons.bluetooth
    font.family: Icons.regular
    font.pixelSize: 16
    color: Theme.fgMuted
}
