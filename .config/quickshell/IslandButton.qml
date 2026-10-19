import QtQuick

// A 40px island button, rounded 8 on a fill (owner, 2026-10-20; square with a 2px border before).
// `on`: lit like a selected toggle (an accent tint); `danger`: a red tint (Stop and save, Start recording);
// `available: false` dims it and ignores clicks. Hover lightens it.
Rectangle {
    id: button
    property string label
    property bool on: false
    property bool danger: false
    property bool available: true
    signal pressed()

    height: 40
    radius: 8
    color: danger ? Edge.alertTint : on ? Edge.accentTint : area.containsMouse ? Edge.controlHover : Edge.control

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
