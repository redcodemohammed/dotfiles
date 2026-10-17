import QtQuick
import Quickshell

// Bar clock, far right: numeric date and time, always shown. 24 or 12 hour, with or without
// seconds: the settings panel (Bar & island).
Text {
    SystemClock {
        id: clock
        precision: Settings.bar.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "yyyy-MM-dd  "
        + (Settings.bar.clock24 ? "HH:mm" : "h:mm") + (Settings.bar.seconds ? ":ss" : "")
        + (Settings.bar.clock24 ? "" : " AP"))
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 13
    color: Theme.fg
}
