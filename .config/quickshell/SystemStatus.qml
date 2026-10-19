import QtQuick

// The bar's system block (owner, 2026-10-18): CPU, memory and root disk use, each a glyph and a
// number in percent, in its chip's hue. A click opens the system panel (SystemPanel.qml).
Row {
    id: root
    property color hue: Theme.fgMuted
    readonly property color ink: hue
    spacing: 8

    component Reading: Row {
        property string glyph
        property real value
        spacing: 4
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.glyph
            font.family: Icons.regular
            font.pixelSize: 16
            color: root.ink
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(parent.value)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: root.ink
        }
    }

    Reading { glyph: Icons.cpu; value: SystemStats.cpu }
    Reading { glyph: Icons.memory; value: SystemStats.mem }
    Reading { glyph: Icons.hardDrive; value: SystemStats.rootDisk }
}
