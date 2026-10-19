import QtQuick
import Quickshell

// Power panel (owner, 2026-10-18; split from the tools panel): drops from the bar's power block
// at the far right, 360 wide, 4px under the bar, its right edge on the block's. Closes on an
// outside click or Escape. Lock, Log out, Suspend, Reboot, Shut down, then UEFI setup and
// Windows (boot it once). Everything but Lock and Suspend asks for a second click within 3 s
// (the button turns primary and reads "Again?"). The actions are .local/bin/power-action.
// Settings (top right) closes it and opens the settings panel (SettingsPanel.qml).
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
    signal settingsRequested

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: {
        if (!visible) {
            closedAt = Date.now()
            armed = ""
        }
    }

    // A small text button (Settings).
    component Chip: Rectangle {
        id: chip
        property string label
        signal clicked
        width: chipText.implicitWidth + 16
        height: 28
        color: chipHover.containsMouse ? Theme.surfaceSelected : Theme.bg
        border.width: 2
        border.color: Theme.border
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fg
        }
        MouseArea {
            id: chipHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    // The action waiting for its confirming click.
    property string armed: ""
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: panel.armed = ""
    }
    function run(action, confirm) {
        if (confirm && armed !== action) {
            armed = action
            armTimer.restart()
            return
        }
        armed = ""
        reveal.close()
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/power-action", action])
    }

    component Button: Rectangle {
        id: button
        property string glyph
        property string label
        property string action
        property bool confirm: false
        readonly property bool waiting: panel.armed === action
        height: 64
        color: waiting ? Theme.surfaceSelected : hover.containsMouse ? Theme.surfaceSelected : Theme.bg
        border.width: 2
        border.color: waiting ? Theme.accent : Theme.border
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                visible: button.glyph !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.glyph
                font.family: Icons.regular
                font.pixelSize: 20
                color: button.waiting ? Theme.accent : Theme.fg
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.waiting ? "Again?" : button.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: button.waiting ? Theme.fg : Theme.fgMuted
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: panel.run(button.action, button.confirm)
        }
    }


    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        atRight: true // at the bar's right end: merges into the frame's side
        bodyWidth: 360
        bodyHeight: column.implicitHeight + 24

        focus: true
        Keys.onEscapePressed: reveal.close()

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Item {
                width: parent.width
                height: 28
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Power"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                Chip {
                    anchors.right: parent.right
                    label: "Settings"
                    onClicked: {
                        reveal.close()
                        panel.settingsRequested()
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 4
                readonly property real cell: (width - 4 * spacing) / 5
                Button { width: parent.cell; glyph: Icons.lock; label: "Lock"; action: "lock" }
                Button { width: parent.cell; glyph: Icons.signOut; label: "Log out"; action: "logout"; confirm: true }
                Button { width: parent.cell; glyph: Icons.moon; label: "Sleep"; action: "suspend" }
                Button { width: parent.cell; glyph: Icons.arrowClockwise; label: "Reboot"; action: "reboot"; confirm: true }
                Button { width: parent.cell; glyph: Icons.power; label: "Off"; action: "poweroff"; confirm: true }
            }

            Row {
                width: parent.width
                spacing: 4
                Button {
                    width: (parent.width - 4) / 2
                    height: 40
                    glyph: ""
                    label: "UEFI setup"
                    action: "firmware"
                    confirm: true
                }
                Button {
                    width: (parent.width - 4) / 2
                    height: 40
                    glyph: ""
                    label: "Windows"
                    action: "windows"
                    confirm: true
                }
            }
        }
    }
}
