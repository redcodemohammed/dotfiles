import QtQuick

// One tab in the settings panel's top row (SettingsPanel.qml): the open one (`tab` equals its
// `section`) has the accent underline and full-colour text; a click emits chosen().
Rectangle {
    id: cell
    property string label
    property string section
    property string tab
    readonly property bool current: tab === section
    signal chosen
    height: 28
    color: hover.containsMouse && !current ? Theme.surfaceSelected : "transparent"
    Text {
        anchors.centerIn: parent
        text: cell.label
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: cell.current ? Theme.fg : Theme.fgMuted
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: cell.current ? Theme.accent : Theme.border
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: cell.chosen()
    }
}
