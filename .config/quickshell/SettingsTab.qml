import QtQuick

// One tab in a panel's top row (SettingsPanel.qml, the sound panel): rounded 8; the open one
// (`tab` equals its `section`) on an accent tint in full-colour text (owner, 2026-10-20; an accent
// underline before); a click emits chosen().
Rectangle {
    id: cell
    property string label
    property string section
    property string tab
    readonly property bool current: tab === section
    signal chosen
    height: 28
    radius: 8
    color: current ? Edge.accentTint : hover.containsMouse ? Edge.control : "transparent"
    Text {
        anchors.centerIn: parent
        text: cell.label
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: cell.current ? Theme.fg : Theme.fgMuted
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: cell.chosen()
    }
}
