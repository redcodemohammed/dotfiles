import QtQuick

// The bar's Pomodoro chip content (owner, 2026-10-17; Pomodoro.qml), in its chip's hue (owner,
// 2026-10-20). Idle: a dimmed timer glyph. Focus: the filled timer and the time left. Break: a
// coffee cup and the time left. Paused: all dimmed. A phase ended and waits: the filled glyph and
// "Break?" / "Focus?".
Row {
    id: root
    property color hue: Theme.accent
    readonly property color ink: Pomodoro.running || Pomodoro.waiting !== "" ? hue : Qt.rgba(hue.r, hue.g, hue.b, 0.6)
    spacing: 6
    readonly property bool breakNow: Pomodoro.phase === "short" || Pomodoro.phase === "long"
        || (Pomodoro.waiting !== "" && Pomodoro.waiting !== "focus")
    readonly property bool lit: (Pomodoro.phase === "focus" && Pomodoro.running) || Pomodoro.waiting !== ""

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: parent.breakNow ? Icons.coffee : Icons.timer
        font.family: parent.lit ? Icons.fill : Icons.regular
        font.pixelSize: 16
        color: root.ink
    }
    Text {
        visible: Pomodoro.active
        anchors.verticalCenter: parent.verticalCenter
        text: Pomodoro.waiting === "focus" ? "Focus?" : Pomodoro.waiting !== "" ? "Break?" : Pomodoro.clock
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: root.ink
    }
}
