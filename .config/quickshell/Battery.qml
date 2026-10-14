import QtQuick
import Quickshell.Services.UPower

// Laptop battery: icon plus number, both gray. On AC the glyph is the charging one.
// Critical (10% or less on battery): fill glyph and number in red. Hidden without a laptop battery.
Row {
    id: root
    readonly property var device: UPower.displayDevice // becomes ready a moment after start
    readonly property int level: Math.round(device.percentage * 100) // percentage is 0-1
    readonly property bool critical: UPower.onBattery && level <= 10

    visible: device.ready && device.isLaptopBattery
    spacing: 4

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.battery(root.level, UPower.onBattery, root.critical)
        font.family: root.critical ? Icons.fill : Icons.regular
        font.pixelSize: 16
        color: root.critical ? Theme.alert : Theme.fgMuted
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.level
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: root.critical ? Theme.alert : Theme.fgMuted
    }
}
