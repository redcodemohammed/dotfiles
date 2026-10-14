import QtQuick
import Quickshell

// One screen of the lock. Solid background, centred clock, date 8px under it,
// a 320x48 password field 24px below the date, layout label under the field.
// Field border: muted idle, amber while typing, red when wrong. No avatar, no wallpaper.
Item {
    id: content
    required property var shell

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 64
            color: Theme.fg
        }

        Item { width: 1; height: 8 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fgMuted
        }

        Item { width: 1; height: 24 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 48
            color: Theme.surface
            border.width: 2
            border.color: content.shell.wrong ? Theme.alert
                : content.shell.password !== "" || content.shell.checking ? Theme.accent
                : Theme.border

            TextInput {
                id: field
                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fg
                cursorVisible: false
                focus: true
                enabled: !content.shell.checking

                text: content.shell.password
                onTextEdited: {
                    content.shell.password = text
                    content.shell.wrong = false
                }
                onAccepted: content.shell.submit()
                Keys.onEscapePressed: content.shell.password = ""
            }
        }

        Item { width: 1; height: 8 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: content.shell.wrong ? "Wrong password" : content.shell.layout
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: content.shell.wrong ? Theme.alert : Theme.fgMuted
        }
    }

    // Test-mode notice. Gone once failsafeSeconds is 0.
    Text {
        visible: content.shell.failsafeSeconds > 0
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 12
        text: "Test mode: unlocks by itself in " + content.shell.failsafeLeft + " s"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
}
