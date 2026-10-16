import QtQuick

// The bar's Pomodoro block content (owner, 2026-10-17; Pomodoro.qml). Idle: a muted timer glyph.
// Focus: timer in the accent (amber means focus) and the time left. Break: a coffee cup and the
// time left. Paused: all muted. A phase ended and waits: the accent glyph and "Break?" / "Focus?".
Row {
    spacing: 6
    readonly property bool breakNow: Pomodoro.phase === "short" || Pomodoro.phase === "long"
        || (Pomodoro.waiting !== "" && Pomodoro.waiting !== "focus")
    readonly property bool lit: (Pomodoro.phase === "focus" && Pomodoro.running) || Pomodoro.waiting !== ""

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: parent.breakNow ? Icons.coffee : Icons.timer
        font.family: parent.lit ? Icons.fill : Icons.regular
        font.pixelSize: 16
        color: parent.lit ? Theme.accent : Pomodoro.running ? Theme.fg : Theme.fgMuted
    }
    Text {
        visible: Pomodoro.active
        anchors.verticalCenter: parent.verticalCenter
        text: Pomodoro.waiting === "focus" ? "Focus?" : Pomodoro.waiting !== "" ? "Break?" : Pomodoro.clock
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Pomodoro.running ? Theme.fg : Theme.fgMuted
    }
}
