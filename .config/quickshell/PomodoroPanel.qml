import QtQuick
import QtQuick.Shapes
import Quickshell

// Pomodoro panel (owner, 2026-10-17; the "Remaining panels" design since 2026-10-20): comes out of
// the frame under the bar's Pomodoro block, 340 wide, its right edge on the block's. Closes on an
// outside click or Escape; Space is the main button. The phase as a pill in the accent (less colour (owner, 2026-10-25): gray, the accent only for a state;
// a hue per phase before), the time left inside a ring that empties as the phase runs,
// this round's finished focus sessions as dots and today's count, then Start / Pause / Resume (or
// the waiting phase) tinted in the accent, Skip and Reset, then the three timings on a card
// with - and + (5 min steps, 5-120).
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

    readonly property string mainLabel: Pomodoro.waiting === "focus" ? "Start focus"
        : Pomodoro.waiting !== "" ? "Start break"
        : Pomodoro.phase === "idle" ? "Start"
        : Pomodoro.running ? "Pause" : "Resume"
    // The phase shown: the running one, else the one waiting to start, else focus.
    readonly property string shown: Pomodoro.phase !== "idle" ? Pomodoro.phase : Pomodoro.waiting !== "" ? Pomodoro.waiting : "focus"
    function hueOf(p) { return Theme.accent } // every phase the same since 2026-10-25
    function tint(c, a) { return Qt.tint(Edge.fill, Qt.rgba(c.r, c.g, c.b, a)) }
    readonly property color hue: hueOf(shown)
    // How much of the phase is left, 0-1 (full while idle).
    readonly property real fraction: Pomodoro.phase === "idle" ? 1
        : Math.max(0, Math.min(1, Pomodoro.left / (Pomodoro.minutes(Pomodoro.phase) * 60000)))

    component Button: Rectangle {
        id: button
        property string label
        property string glyph: ""
        property bool primary
        property bool enabled: true
        property bool lifted // on a card: a step lighter
        signal clicked
        height: 40
        radius: 8
        color: primary ? panel.tint(panel.hue, hover.containsMouse ? 0.22 : 0.15)
            : lifted ? panel.tint(Theme.fg, hover.containsMouse ? 0.18 : 0.12)
            : hover.containsMouse ? Edge.controlHover : Edge.control
        opacity: enabled ? 1 : 0.4
        Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: button.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: button.glyph
                font.family: button.primary ? Icons.fill : Icons.regular
                font.pixelSize: 16
                color: button.primary ? panel.hue : Theme.fgMuted
            }
            Text {
                visible: button.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: button.primary ? panel.hue : Theme.fg
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }

    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        bodyWidth: 340
        bodyHeight: column.implicitHeight + 24

        focus: true
        Keys.onEscapePressed: reveal.close()
        Keys.onSpacePressed: Pomodoro.toggle()

        Column {
            id: column
            x: 16
            y: 8
            width: parent.width - 32
            spacing: 14

            Item { // the title and the phase
                width: parent.width
                height: 32
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pomodoro"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.fg
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: phaseText.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: panel.tint(panel.hue, 0.15)
                    Text {
                        id: phaseText
                        anchors.centerIn: parent
                        text: Pomodoro.waiting === "focus" ? "Break over"
                            : Pomodoro.waiting !== "" ? "Focus done"
                            : Pomodoro.phase === "idle" ? "Ready"
                            : Pomodoro.phaseName + (Pomodoro.running ? "" : " · paused")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: panel.hue
                    }
                }
            }

            Item { // the ring: the time left
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                height: 180
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath { // the track
                        strokeColor: Edge.controlHover
                        strokeWidth: 8
                        fillColor: "transparent"
                        PathAngleArc { centerX: 90; centerY: 90; radiusX: 84; radiusY: 84; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath { // what is left, from the top, clockwise
                        strokeColor: Pomodoro.running || Pomodoro.phase === "idle" ? panel.hue : Theme.fgMuted
                        strokeWidth: 8
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc { centerX: 90; centerY: 90; radiusX: 84; radiusY: 84; startAngle: -90; sweepAngle: 360 * panel.fraction }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Pomodoro.phase === "idle"
                            ? String(Pomodoro.minutes(panel.shown)).padStart(2, "0") + ":00"
                            : Pomodoro.clock
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 36
                        font.weight: Font.Medium
                        color: Pomodoro.running || Pomodoro.phase === "idle" ? Theme.fg : Theme.fgMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "of " + Pomodoro.minutes(panel.shown) + " min"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
            }

            Row { // this round's focus sessions, today's count
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Round"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                Repeater {
                    model: Pomodoro.settings.every
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: index < Pomodoro.cycle ? Theme.accent : Edge.controlHover
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 4
                    text: "· today " + Pomodoro.today
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }

            Row {
                width: parent.width
                spacing: 6
                Button {
                    width: parent.width - 2 * (40 + 6)
                    primary: true
                    glyph: Pomodoro.running ? Icons.pause : Icons.play
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

            Rectangle { // the timings
                width: parent.width
                height: timings.implicitHeight + 8
                radius: 12
                color: Edge.control
                Column {
                    id: timings
                    x: 12
                    y: 4
                    width: parent.width - 24
                    Repeater {
                        model: [
                            { key: "focus", name: "Focus" },
                            { key: "short", name: "Short break" },
                            { key: "long", name: "Long break" },
                        ]
                        Item {
                            required property var modelData
                            width: timings.width
                            height: 40
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: panel.hueOf(modelData.key)
                            }
                            Text {
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.fg
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Button {
                                    width: 28
                                    height: 28
                                    lifted: true
                                    label: "−"
                                    onClicked: Pomodoro.setMinutes(modelData.key, Pomodoro.settings[modelData.key] - 5)
                                }
                                Text {
                                    width: 60
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
                                    lifted: true
                                    label: "+"
                                    onClicked: Pomodoro.setMinutes(modelData.key, Pomodoro.settings[modelData.key] + 5)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                leftPadding: 4
                text: "Long break after every " + Pomodoro.settings.every + " · SUPER + P"
                width: parent.width
                wrapMode: Text.Wrap
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }
        }
    }
}
