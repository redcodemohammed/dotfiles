import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// One screen of the login screen (owner, 2026-10-20: "Boot, login and lock" design, idea D): the
// desktop's frame, and the login as the quick-settings panel, open from the band's right end under
// an active "Log in" chip and joined to the band by inward curves. In the panel: the user (the
// initial on an accent tint, the host under the name), the password field (control fill idle,
// accent tint while typing, red tint when wrong), the sessions as rows (the chosen one in hue3,
// a click or Up/Down in the field picks one), then Restart and Shut down (shell.power(): skipped in
// test mode). The clock as a poster
// bottom-left, as on the lock. The band: the Arch logo on the left; the layout, battery (laptops)
// and Caps Lock chips before the Log in chip. Test mode says so at the bottom. Frame sizes as the
// shell's defaults (Settings.look: 10 sides, 44 band, 18 radius); colours from Edge.qml.
Item {
    id: content
    required property var shell

    readonly property int side: 10
    readonly property int band: 44
    readonly property int radius: 18
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property bool typing: shell.password !== "" || shell.checking

    function tint(c, a) {
        return Qt.tint(Edge.fill, Qt.rgba(c.r, c.g, c.b, a))
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    FileView {
        id: hostFile
        path: "/etc/hostname"
        printErrors: false
    }

    Rectangle { // the frame
        anchors.fill: parent
        color: Edge.fill
    }

    Rectangle { // the desktop, not started yet
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
            anchors.bottomMargin: 48
            spacing: 8
            Text {
                text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                font.family: content.font
                font.pixelSize: 18
                color: Theme.fgMuted
            }
            Text {
                x: -8 // the digits' side bearing, so they line up with the date
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: content.font
                font.weight: Font.Medium
                font.pixelSize: Math.min(160, ground.height * 0.2)
                font.letterSpacing: -6
                color: Theme.fg
            }
        }

        Text {
            visible: content.shell.test
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            text: "Test mode: a correct password starts nothing"
            font.family: content.font
            font.pixelSize: 12
            color: Theme.hue1
        }
    }

    // The panel, out of the band's right end
    Rectangle {
        id: panel
        anchors.right: parent.right
        anchors.rightMargin: content.side
        y: content.band
        width: 380
        height: panelColumn.height + 8 + 16
        color: Edge.fill
        bottomLeftRadius: content.radius

        Column {
            id: panelColumn
            x: 16
            y: 8
            width: parent.width - 32
            spacing: 14

            Rectangle { // the user
                width: parent.width
                height: 64
                radius: 12
                color: Edge.control
                Rectangle {
                    id: avatar
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: Edge.accentTint
                    Text {
                        anchors.centerIn: parent
                        text: content.shell.user.charAt(0).toUpperCase()
                        font.family: content.font
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Theme.accent
                    }
                }
                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: content.shell.user
                        font.family: content.font
                        font.pixelSize: 13
                        color: Theme.fg
                    }
                    Text {
                        visible: text !== ""
                        text: hostFile.text().trim() !== "" ? "on " + hostFile.text().trim() : ""
                        font.family: content.font
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
            }

            Rectangle { // the password
                width: parent.width
                height: 52
                radius: 12
                color: content.shell.wrong ? Edge.alertTint : content.typing ? Edge.accentTint : Edge.control
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: lockIcon
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool on: content.shell.wrong || content.typing
                    text: Icons.lock
                    font.family: on ? Icons.fill : Icons.regular
                    font.pixelSize: 20
                    color: content.shell.wrong ? Theme.alert : on ? Theme.accent : Theme.fgMuted
                }
                Text {
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
                    Keys.onUpPressed: content.shell.nextSession(-1)
                    Keys.onDownPressed: content.shell.nextSession(1)
                    Keys.onReleased: event => {
                        if (event.key === Qt.Key_CapsLock)
                            content.shell.readKeyboards()
                    }
                }
            }

            Text { // wrong, or what greetd or PAM said; else nothing
                visible: text !== ""
                width: parent.width
                leftPadding: 4
                wrapMode: Text.Wrap
                text: content.shell.wrong ? "Wrong password" : content.shell.message
                font.family: content.font
                font.pixelSize: 12
                color: Theme.alert
            }

            Column { // the sessions
                width: parent.width
                spacing: 4
                Text {
                    leftPadding: 4
                    text: "Session"
                    font.family: content.font
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                Repeater {
                    model: content.shell.sessions
                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === content.shell.sessionIndex
                        width: parent.width
                        height: 40
                        radius: 8
                        color: chosen ? content.tint(Theme.hue3, 0.15) : rowArea.containsMouse ? Edge.controlHover : Edge.control
                        Text {
                            id: dot
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "" // circle
                            font.family: row.chosen ? Icons.fill : Icons.regular
                            font.pixelSize: 14
                            color: row.chosen ? Theme.hue3 : Theme.fgMuted
                        }
                        Text {
                            anchors.left: dot.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.modelData.name
                            font.family: content.font
                            font.pixelSize: 13
                            color: row.chosen ? Theme.fg : Theme.fgMuted
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                content.shell.sessionIndex = row.index
                                field.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Row { // power
                width: parent.width
                spacing: 4
                Repeater {
                    model: [{ label: "Restart", icon: Icons.arrowClockwise, action: "reboot" },
                        { label: "Shut down", icon: Icons.power, action: "poweroff" }]
                    Rectangle {
                        id: power
                        required property var modelData
                        required property int index
                        width: (parent.width - 4) / 2
                        height: 48
                        radius: 8
                        color: powerArea.containsMouse ? Edge.controlHover : Edge.control
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: power.modelData.icon
                                font.family: Icons.regular
                                font.pixelSize: 18
                                color: power.index === 1 ? Theme.accent : Theme.fg
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: power.modelData.label
                                font.family: content.font
                                font.pixelSize: 13
                                color: Theme.fg
                            }
                        }
                        MouseArea {
                            id: powerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: content.shell.power(power.modelData.action) // the shell refuses in test mode
                        }
                    }
                }
            }
        }
    }
    InCurve { // into the band, left of the panel
        x: panel.x - width
        y: content.band
    }
    InCurve { // into the right side, under the panel
        x: panel.x + panel.width - width
        y: panel.y + panel.height
    }

    // The band
    Rectangle { // the Arch logo, where the bar's left end is
        x: content.side
        y: 6
        width: 32
        height: 32
        radius: 8
        color: Edge.accentTint
        Text {
            anchors.centerIn: parent
            text: "" // linux-archlinux
            font.family: content.font
            font.pixelSize: 16
            color: Theme.accent
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: content.side
        y: 6
        spacing: 10
        Chip {
            visible: content.shell.capsLock
            label: "Caps Lock on"
            hue: Theme.hue1
        }
        Chip {
            visible: content.shell.layout !== ""
            label: content.shell.layout
            hue: Theme.hue4
        }
        Chip {
            readonly property var device: UPower.displayDevice
            readonly property int level: Math.round(device.percentage * 100)
            readonly property bool critical: UPower.onBattery && level <= 10
            visible: device.ready && device.isLaptopBattery
            icon: Icons.battery(level, UPower.onBattery, critical)
            label: level
            hue: critical ? Theme.alert : Theme.hue2
        }
        Chip { // the open panel's chip: hover fill, like quick settings while open
            label: "Log in"
            hue: Theme.accent
            fill: Edge.controlHover
        }
    }

    component Chip: Rectangle {
        property string label
        property string icon: ""
        property color hue
        property color fill: content.tint(hue, 0.15)
        height: 32
        width: chipRow.width + 20
        radius: 8
        color: fill
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: parent.parent.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.icon
                font.family: Icons.regular
                font.pixelSize: 16
                color: parent.parent.hue
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.label
                font.family: content.font
                font.pixelSize: 13
                color: parent.parent.hue
            }
        }
    }

    // An inward corner: the frame's colour with a quarter circle of the ground cut from its
    // bottom-left, so the panel's edge curves into the band or the side.
    component InCurve: Item {
        width: content.radius
        height: content.radius
        clip: true
        Rectangle {
            anchors.fill: parent
            color: Edge.fill
        }
        Rectangle {
            x: -content.radius
            y: 0
            width: 2 * content.radius
            height: 2 * content.radius
            radius: content.radius
            color: Theme.bg
        }
    }
}
