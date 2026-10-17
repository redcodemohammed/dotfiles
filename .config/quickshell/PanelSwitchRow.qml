import QtQuick

// A label and an on/off switch, 40 tall, full width (the network panel's Settings tab).
// `available: false` dims the switch and ignores clicks; a click emits toggled().
Item {
    id: row
    property string label
    property bool on
    property bool available: true
    signal toggled
    width: parent.width
    height: 40
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fg
    }
    PanelSwitch {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        available: row.available
        on: row.on
        onToggled: row.toggled()
    }
}
