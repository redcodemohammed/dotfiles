import QtQuick

// An on/off switch in the network panel (owner's design): a 40x24 pill with a 12px round knob
// (owner, 2026-10-20; square with a 2px border before). On: accent fill, dark knob on the right.
// Off: the control fill, dim knob on the left. The knob slides.
// `available: false` dims it to half and ignores clicks.
Rectangle {
    id: sw
    property bool on: false
    property bool available: true
    signal toggled()

    width: 40
    height: 24
    radius: height / 2
    color: on ? Theme.accent : Edge.controlHover
    Behavior on color { ColorAnimation { duration: 150 } }
    opacity: available ? 1 : 0.5

    Rectangle {
        x: sw.on ? 22 : 6
        y: 6
        width: 12
        height: 12
        radius: 6
        color: sw.on ? Theme.textOnAccent : Theme.fgMuted
        Behavior on x {
            enabled: Settings.look.animations
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: sw.available
        onClicked: sw.toggled()
    }
}
