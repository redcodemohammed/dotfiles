import QtQuick
import Quickshell

// Pomodoro panel (owner, 2026-10-17): drops from the bar's Pomodoro block, 300 wide, 4px under
// the bar, its right edge on the block's. Closes on an outside click or Escape; Space is the main
// button. Phase and today's finished focus sessions, the time left, then Start / Pause / Resume
// (or the waiting phase), Skip and Reset, then the three timings with - and + (5 min steps, 5-120).
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width + reveal.overhang - implicitWidth // the body's right edge on the chip's
    anchor.rect.y: block.height + 6
    implicitWidth: reveal.implicitWidth
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }
    color: "transparent"
    grabFocus: false // an outside click goes through EdgePanel's focus grab, so closing can slide
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: if (!visible) closedAt = Date.now()

    readonly property string mainLabel: Pomodoro.waiting === "focus" ? "Start focus"
        : Pomodoro.waiting !== "" ? "Start break"
        : Pomodoro.phase === "idle" ? "Start"
        : Pomodoro.running ? "Pause" : "Resume"

    component Button: Rectangle {
        id: button
        property string label
        property string glyph: ""
        property bool primary
        property bool enabled: true
        signal clicked
        height: 36
        color: primary ? Theme.surfaceSelected : Theme.surface
        border.width: 2
        border.color: Theme.border
        opacity: enabled ? 1 : 0.4
        Text {
            anchors.centerIn: parent
            text: button.glyph !== "" ? button.glyph : button.label
            font.family: button.glyph !== "" ? Icons.regular : "JetBrainsMono Nerd Font"
            font.pixelSize: button.glyph !== "" ? 16 : 13
            color: button.primary ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            anchors.fill: parent
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }


    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        bodyWidth: 300
        bodyHeight: column.implicitHeight + 24

        focus: true
        Keys.onEscapePressed: reveal.close()
        Keys.onSpacePressed: Pomodoro.toggle()

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 12

            Item {
                width: parent.width
                height: 20
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Pomodoro.waiting === "focus" ? "Break over"
                        : Pomodoro.waiting !== "" ? "Focus done"
                        : Pomodoro.phaseName + (Pomodoro.phase !== "idle" && !Pomodoro.running ? " · paused" : "")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Today " + Pomodoro.today
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Pomodoro.phase === "idle"
                    ? String(Pomodoro.minutes(Pomodoro.waiting !== "" ? Pomodoro.waiting : "focus")).padStart(2, "0") + ":00"
                    : Pomodoro.clock
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 40
                color: Pomodoro.running ? (Pomodoro.phase === "focus" ? Theme.accent : Theme.fg) : Theme.fgMuted
            }

            Row {
                width: parent.width
                spacing: 4
                Button {
                    width: parent.width - 2 * (40 + 4)
                    primary: true
                    label: panel.mainLabel
                    onClicked: Pomodoro.toggle()
                }
                Button {
                    width: 40
                    glyph: Icons.skipForward
                    enabled: Pomodoro.active
                    onClicked: Pomodoro.skip()
                }
                Button {
                    width: 40
                    glyph: Icons.arrowCounterClockwise
                    enabled: Pomodoro.active || Pomodoro.cycle > 0
                    onClicked: Pomodoro.reset()
                }
            }

            Rectangle {
                width: parent.width
                height: 2
                color: Theme.border
            }

            Repeater {
                model: [
                    { key: "focus", name: "Focus" },
                    { key: "short", name: "Short break" },
                    { key: "long", name: "Long break" },
                ]
                Item {
                    required property var modelData
                    width: column.width
                    height: 28
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Button {
                            width: 28
                            height: 28
                            label: "-"
                            onClicked: Pomodoro.setMinutes(modelData.key, Pomodoro.settings[modelData.key] - 5)
                        }
                        Text {
                            width: 64
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: Pomodoro.settings[modelData.key] + " min"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: Theme.fg
                        }
                        Button {
                            width: 28
                            height: 28
                            label: "+"
                            onClicked: Pomodoro.setMinutes(modelData.key, Pomodoro.settings[modelData.key] + 5)
                        }
                    }
                }
            }

            Text {
                text: "Long break after every " + Pomodoro.settings.every + " · SUPER + P"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }
        }
    }
}
