import QtQuick
import Quickshell.Bluetooth

// The bar's Bluetooth item (spec: "Connected?", icon only, in its chip's hue). Off or blocked: the slash glyph;
// on: the plain glyph; a device connected: the connected glyph. The state changes the glyph, not
// the colour. In the quick-settings chip, shown while Bluetooth is on (Bar.qml).
// Named BluetoothStatus so it doesn't shadow Quickshell.Bluetooth's Bluetooth singleton.
Text {
    property color hue: Theme.fgMuted
    readonly property color ink: hue
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.state === BluetoothAdapterState.Enabled
    readonly property bool connected: on && Bluetooth.devices.values.some(d => d.connected)

    text: !on ? Icons.bluetoothSlash : connected ? Icons.bluetoothConnected : Icons.bluetooth
    font.family: Icons.regular
    font.pixelSize: 16
    color: ink
}
