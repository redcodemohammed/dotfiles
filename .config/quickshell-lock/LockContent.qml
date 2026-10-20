import QtQuick
import Quickshell
import Quickshell.Services.UPower

// One screen of the lock, in the desktop's frame (owner, 2026-10-20: "Boot, login and lock" design,
// idea B). The frame's colour all round (Edge.qml, linked from the shell, so it follows the
// wallpaper), the desktop hidden under a solid ground with the frame's 18px inner corners; the
// band holds a "Locked" chip where the bar's left end is. The clock as a poster in the bottom-left
// (light, 260px, the colon in the accent; the date above it in hue5), the password on a card in
// the bottom-right: no borders, fills only. The field: control fill idle, accent tint (lock icon
// filled) while typing, red tint and a short shake when wrong. Under it the layout and battery
// pills, Caps Lock as a hue1 pill (a warning, so not red), and "Enter to unlock" or "Wrong
// password". Frame sizes as the shell's defaults (Settings.look: 10 sides, 44 band, 18 radius).
Item {
    id: content
    required property var shell

    readonly property int side: 10
    readonly property int band: 44
    readonly property int radius: 18
    readonly property string font: "JetBrainsMono Nerd Font"

    function tint(c, a) {
        return Qt.tint(Edge.fill, Qt.rgba(c.r, c.g, c.b, a))
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle { // the frame
        anchors.fill: parent
        color: Edge.fill
    }

    Rectangle { // the desktop, hidden
        id: ground
        x: content.side
        y: content.band
        width: parent.width - 2 * content.side
        height: parent.height - content.band - content.side
        radius: content.radius
        color: Theme.bg

        Column { // the clock, bottom-left
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 64
            anchors.bottomMargin: 40
            Text {
                text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                font.family: content.font
                font.pixelSize: 20
                color: Theme.hue5
            }
            Text {
                x: -12 // the digits' side bearing, so they line up with the date
                text: Qt.formatDateTime(clock.date, "HH") + "<font color=\"" + Theme.accent + "\">:</font>"
                    + Qt.formatDateTime(clock.date, "mm")
                textFormat: Text.StyledText
                font.family: content.font
                font.weight: Font.Light
                font.pixelSize: Math.min(260, ground.height * 0.3)
                font.letterSpacing: -10
                lineHeight: 0.95
                color: Theme.fg
            }
        }

        Rectangle { // the password card, bottom-right
            id: card
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 64
            anchors.bottomMargin: 64
            width: 380
            height: cardColumn.height + 32
            radius: content.radius
            color: Edge.fill
            transform: Translate { id: shake }

            Column {
                id: cardColumn
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 12
                    color: content.shell.wrong ? Edge.alertTint
                        : content.shell.password !== "" || content.shell.checking ? Edge.accentTint
                        : Edge.control
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: lockIcon
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool on: content.shell.wrong || content.shell.password !== "" || content.shell.checking
                        text: Icons.lock
                        font.family: on ? Icons.fill : Icons.regular
                        font.pixelSize: 20
                        color: content.shell.wrong ? Theme.alert : on ? Theme.accent : Theme.fgMuted
                    }
                    Text { // the placeholder
                        visible: field.text === ""
                        anchors.left: lockIcon.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        font.family: content.font
                        font.pixelSize: 15
                        color: Theme.fgDim
                    }
                    TextInput {
                        id: field
                        anchors.left: lockIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        font.family: content.font
                        font.pixelSize: 15
                        font.letterSpacing: 3
                        color: Theme.fg
                        cursorVisible: false
                        focus: true
                        enabled: !content.shell.checking
                        clip: true

                        text: content.shell.password
                        onTextEdited: {
                            content.shell.password = text
                            content.shell.wrong = false
                        }
                        onAccepted: content.shell.submit()
                        Keys.onEscapePressed: content.shell.password = ""
                        Keys.onReleased: event => {
                            if (event.key === Qt.Key_CapsLock)
                                content.shell.readKeyboards()
                        }
                    }
                }

                Row { // pills, then the hint at the right end
                    width: parent.width
                    height: 26
                    spacing: 6

                    Pill {
                        visible: content.shell.layout !== ""
                        label: content.shell.layout
                        hue: Theme.hue4
                    }
                    Pill {
                        id: battery
                        readonly property var device: UPower.displayDevice
                        readonly property int level: Math.round(device.percentage * 100)
                        readonly property bool critical: UPower.onBattery && level <= 10
                        visible: device.ready && device.isLaptopBattery
                        icon: Icons.battery(level, UPower.onBattery, critical)
                        label: level + "%"
                        hue: critical ? Theme.alert : Theme.hue2
                    }
                    Pill {
                        visible: content.shell.capsLock
                        label: "Caps Lock on"
                        hue: Theme.hue1
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: content.shell.wrong ? "Wrong password" : content.shell.checking ? "Checking…" : "Enter to unlock"
                    font.family: content.font
                    font.pixelSize: 12
                    color: content.shell.wrong ? Theme.alert : Theme.fgMuted
                }
            }
        }

        Text { // test mode: gone once failsafeSeconds is 0
            visible: content.shell.failsafeSeconds > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            text: "Test mode: unlocks by itself in " + content.shell.failsafeLeft + " s"
            font.family: content.font
            font.pixelSize: 12
            color: Theme.fgMuted
        }
    }

    Rectangle { // the band's chip, where the bar's left end is
        x: content.side
        y: 6
        width: chipRow.width + 20
        height: 32
        radius: 8
        color: Edge.accentTint
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.lock
                font.family: Icons.fill
                font.pixelSize: 16
                color: Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Locked"
                font.family: content.font
                font.pixelSize: 13
                color: Theme.accent
            }
        }
    }

    // Wrong password: a short shake of the card.
    Connections {
        target: content.shell
        function onWrongChanged() {
            if (content.shell.wrong)
                shakeAnim.restart()
        }
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -10; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 10; duration: 80 }
        NumberAnimation { target: shake; property: "x"; to: -6; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
    }

    component Pill: Rectangle {
        property string label
        property string icon: ""
        property color hue
        height: 26
        width: pillRow.width + 20
        radius: 8
        color: content.tint(hue, 0.15)
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: parent.parent.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.icon
                font.family: Icons.regular
                font.pixelSize: 14
                color: parent.parent.hue
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.label
                font.family: content.font
                font.pixelSize: 12
                color: parent.parent.hue
            }
        }
    }
}
