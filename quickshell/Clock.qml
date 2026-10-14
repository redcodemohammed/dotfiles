import QtQuick
import Quickshell

// Bar centre clock, 24h. Hover swaps in the date: no date otherwise, by design.
Text {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, hover.containsMouse ? "ddd d MMM yyyy" : "HH:mm")
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 13
    color: Theme.fg

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
    }
}
