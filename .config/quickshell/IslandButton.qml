import QtQuick

// A 40px island button (design: 2px border, square). `on`: lit like a selected toggle (light
// border on surface-selected); `danger`: red border (Stop and save, Start recording);
// `available: false` dims it and ignores clicks. Hover lightens it.
Rectangle {
    id: button
    property string label
    property bool on: false
    property bool danger: false
    property bool available: true
    signal pressed()

    height: 40
    color: on || area.containsMouse ? Theme.surfaceSelected : Theme.surface
    border.width: 2
    border.color: danger ? Theme.alert : on ? Theme.fg : Theme.border

    Text {
        anchors.centerIn: parent
        text: button.label
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: !button.available ? Theme.fgDim : button.on || button.danger ? Theme.fg : Theme.fgMuted
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.available
        onClicked: button.pressed()
    }
}
