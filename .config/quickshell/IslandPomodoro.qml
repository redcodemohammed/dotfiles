import QtQuick

// Island card when a Pomodoro phase ends (owner, 2026-10-17; Pomodoro.qml). Opens expanded and
// stays until answered: after focus "Focus done" with Start break / Skip break; after a break
// "Break over" with Start focus / Later. Glyph: timer for focus, coffee for breaks, in the accent
// (amber means focus). Keeps its last content while the island slides out.
Item {
    id: root
    property var shown: null // { ended: "focus" | "short" | "long" }
    readonly property var live: IslandState.active && IslandState.active.kind === "pomodoro" ? IslandState.active.data : null
    onLiveChanged: if (live) shown = live
    readonly property bool afterFocus: shown !== null && shown.ended === "focus"

    component Button: Rectangle {
        id: button
        property string label
        property bool primary
        signal clicked
        height: 40
        color: primary ? Theme.surfaceSelected : Theme.surface
        border.width: 2
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: button.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: button.primary ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            anchors.fill: parent
            onClicked: button.clicked()
        }
    }

    Column {
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 12

        Row {
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.afterFocus ? Icons.coffee : Icons.timer
                font.family: Icons.fill
                font.pixelSize: 24
                color: Theme.accent
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: root.afterFocus ? "Focus done" : "Break over"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
                Text {
                    text: root.afterFocus
                        ? "Today: " + Pomodoro.today + " · next: " + Pomodoro.minutes(Pomodoro.waiting) + " min " + Pomodoro.label(Pomodoro.waiting)
                        : "Next: " + Pomodoro.settings.focus + " min focus"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }
        }

        Row {
            width: parent.width
            spacing: 4
            Button {
                width: (parent.width - 4) / 2
                primary: true
                label: root.afterFocus ? "Start break" : "Start focus"
                onClicked: Pomodoro.toggle()
            }
            Button {
                width: (parent.width - 4) / 2
                label: root.afterFocus ? "Skip break" : "Later"
                onClicked: Pomodoro.skip()
            }
        }
    }
}
