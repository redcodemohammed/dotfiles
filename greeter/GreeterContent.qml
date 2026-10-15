import QtQuick
import Quickshell
import Quickshell.Services.UPower

// One screen of the login screen: the lock screen's layout (owner's choice). Clock, date, the user
// name, the 320x48 password field (muted idle, amber while typing, red when wrong), the layout or
// "Wrong password", a reserved Caps Lock line, then the session ("‹ Hyprland (uwsm-managed) ›":
// click either side, or Up/Down in the field). Battery at the bottom (laptops), Restart and
// Shut down in the bottom-right corner. Test mode says so at the bottom.
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
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: content.shell.user
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: Theme.fg
        }
        Item { width: 1; height: 8 }

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
                Keys.onUpPressed: content.shell.nextSession(-1)
                Keys.onDownPressed: content.shell.nextSession(1)
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_CapsLock)
                        content.shell.readKeyboards()
                }
            }
        }

        Item { width: 1; height: 8 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: content.shell.wrong ? "Wrong password" : content.shell.message || content.shell.layout
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: content.shell.wrong || content.shell.message !== "" ? Theme.alert : Theme.fgMuted
        }
        Item { width: 1; height: 4 }
        Text { // reserved line, so nothing moves
            anchors.horizontalCenter: parent.horizontalCenter
            height: 16
            text: content.shell.capsLock ? "Caps Lock on" : ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.alert
        }
        Item { width: 1; height: 16 }

        Row { // the session
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Repeater {
                model: [{ text: "‹", step: -1 }, { text: "", step: 0 }, { text: "›", step: 1 }]
                Text {
                    id: part
                    required property var modelData
                    text: modelData.step === 0 ? (content.shell.session ? content.shell.session.name : "") : modelData.text
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: modelData.step !== 0 && area.containsMouse ? Theme.accent : Theme.fgMuted
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        enabled: part.modelData.step !== 0 && content.shell.sessions.length > 1
                        onClicked: content.shell.nextSession(part.modelData.step)
                    }
                }
            }
        }
    }

    Row { // battery: laptops only, small and muted, red when critical
        readonly property var device: UPower.displayDevice
        readonly property int level: Math.round(device.percentage * 100)
        readonly property bool critical: UPower.onBattery && level <= 10
        visible: device.ready && device.isLaptopBattery
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        spacing: 4
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.battery(parent.level, UPower.onBattery, parent.critical)
            font.family: parent.critical ? Icons.fill : Icons.regular
            font.pixelSize: 14
            color: parent.critical ? Theme.alert : Theme.fgMuted
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.level
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: parent.critical ? Theme.alert : Theme.fgMuted
        }
    }

    Row { // power
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8
        Repeater {
            model: [{ label: "Restart", command: ["systemctl", "reboot"] },
                { label: "Shut down", command: ["systemctl", "poweroff"] }]
            Rectangle {
                id: power
                required property var modelData
                width: powerText.implicitWidth + 24
                height: 32
                color: powerArea.containsMouse ? Theme.surfaceSelected : Theme.surface
                border.width: 2
                border.color: Theme.border
                Text {
                    id: powerText
                    anchors.centerIn: parent
                    text: power.modelData.label
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(power.modelData.command)
                }
            }
        }
    }

    Text {
        visible: content.shell.test
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 24
        text: "Test mode: a correct password starts nothing"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
}
