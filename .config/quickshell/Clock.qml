import QtQuick
import Quickshell

// Bar clock, far right: numeric date and 24h time, always shown.
Text {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "yyyy-MM-dd  HH:mm")
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 13
    color: Theme.fg
}
