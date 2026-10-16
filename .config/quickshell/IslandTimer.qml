import QtQuick

// The island while a Pomodoro phase runs or is paused (owner, 2026-10-17; Pomodoro.qml), between
// recording and media. Compact 160x24: glyph (timer in the accent while focusing, coffee in a
// break, muted when paused) and the time left. Expanded 340x148 (a click): phase and today's
// count, the time left large, Pause / Resume, Skip and Reset. The settings stay in the bar's panel.
Item {
    id: root
    property bool open: false
    readonly property bool focusing: Pomodoro.phase === "focus"
    readonly property color glyphColor: !Pomodoro.running ? Theme.fgMuted : focusing ? Theme.accent : Theme.fg

    component Button: Rectangle {
        id: button
        property string label
        property string glyph: ""
        property bool primary
        signal clicked
        height: 40
        color: primary ? Theme.surfaceSelected : Theme.surface
        border.width: 2
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: button.glyph !== "" ? button.glyph : button.label
            font.family: button.glyph !== "" ? Icons.regular : "JetBrainsMono Nerd Font"
            font.pixelSize: button.glyph !== "" ? 16 : 13
            color: button.primary ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            anchors.fill: parent
            onClicked: button.clicked()
        }
    }

    // Compact: centred in the bar.
    Row {
        visible: !root.open
        anchors.centerIn: parent
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.focusing ? Icons.timer : Icons.coffee
            font.family: Pomodoro.running ? Icons.fill : Icons.regular
            font.pixelSize: 16
            color: root.glyphColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Pomodoro.clock
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Pomodoro.running ? Theme.fg : Theme.fgMuted
        }
    }

    Column {
        visible: root.open
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width
            height: 20
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.focusing ? Icons.timer : Icons.coffee
                    font.family: Pomodoro.running ? Icons.fill : Icons.regular
                    font.pixelSize: 16
                    color: root.glyphColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Pomodoro.phaseName + (Pomodoro.running ? "" : " · paused")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 32 // the island's collapse chevron sits in the corner
                anchors.verticalCenter: parent.verticalCenter
                text: "Today " + Pomodoro.today
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 48
            verticalAlignment: Text.AlignVCenter
            text: Pomodoro.clock
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 40
            color: Pomodoro.running ? (root.focusing ? Theme.accent : Theme.fg) : Theme.fgMuted
        }

        Row {
            width: parent.width
            spacing: 4
            Button {
                width: parent.width - 2 * (40 + 4)
                primary: true
                label: Pomodoro.running ? "Pause" : "Resume"
                onClicked: Pomodoro.toggle()
            }
            Button {
                width: 40
                glyph: Icons.skipForward
                onClicked: Pomodoro.skip()
            }
            Button {
                width: 40
                glyph: Icons.arrowCounterClockwise
                onClicked: Pomodoro.reset()
            }
        }
    }
}
