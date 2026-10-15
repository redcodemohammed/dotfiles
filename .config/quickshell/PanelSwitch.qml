import QtQuick

// An on/off switch in the network panel (owner's design): 40x24, 2px border, a 12px square knob.
// On: light border and knob on the right. Off: border colour, dim knob on the left.
// `available: false` dims it to half and ignores clicks.
Rectangle {
    id: sw
    property bool on: false
    property bool available: true
    signal toggled()

    width: 40
    height: 24
    color: Theme.bg
    border.width: 2
    border.color: on ? Theme.fg : Theme.border
    opacity: available ? 1 : 0.5

    Rectangle {
        x: sw.on ? 22 : 6
        y: 6
        width: 12
        height: 12
        color: sw.on ? Theme.fg : Theme.fgDim
    }

    MouseArea {
        anchors.fill: parent
        enabled: sw.available
        onClicked: sw.toggled()
    }
}
