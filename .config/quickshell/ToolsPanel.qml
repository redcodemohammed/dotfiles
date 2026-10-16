import QtQuick
import Quickshell

// Tools panel (owner, 2026-10-17): drops from the bar's power block at the far right, 360 wide,
// 4px under the bar, its right edge on the block's. Closes on an outside click or Escape;
// SUPER + X toggles it (Tools.qml). Power: Lock, Log out, Suspend, Reboot, Shut down, then
// UEFI setup and Windows (boot it once). Everything but Lock and Suspend asks for a second click
// within 3 s (the button turns primary and reads "Again?"). The actions are .local/bin/power-action.
// Tools (step 2): Pick colour (the panel closes, hyprpicker; recent colours below as swatches, a
// click copies one), Keep awake (on/off; pauses the idle chain), Text from screen (OCR).
// Next steps add the web dev tools and a Settings button.
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width - implicitWidth
    anchor.rect.y: block.height + 4
    implicitWidth: 360
    implicitHeight: body.implicitHeight
    color: "transparent"
    grabFocus: true
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            visible = false
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: {
        if (!visible) {
            closedAt = Date.now()
            armed = ""
            note = ""
        }
    }

    // A short line under the tools (e.g. "Copied #f5a524"), cleared after 2 s.
    property string note: ""
    onNoteChanged: if (note !== "") noteTimer.restart()
    Timer {
        id: noteTimer
        interval: 2000
        onTriggered: panel.note = ""
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
        visible = false
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

    // A tool button: glyph and label; `lit` (Keep awake) shows it lit, with the accent glyph.
    component ToolTile: Rectangle {
        id: tile
        property string glyph
        property string label
        property bool lit: false
        signal clicked
        height: 64
        color: lit || tileHover.containsMouse ? Theme.surfaceSelected : Theme.bg
        border.width: 2
        border.color: lit ? Theme.accent : Theme.border
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.glyph
                font.family: tile.lit ? Icons.fill : Icons.regular
                font.pixelSize: 20
                color: tile.lit ? Theme.accent : Theme.fg
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: tile.lit ? Theme.fg : Theme.fgMuted
            }
        }
        MouseArea {
            id: tileHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }

    Rectangle {
        id: body
        width: parent.width
        implicitHeight: column.implicitHeight + 24
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: panel.visible = false

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Text {
                text: "Power"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
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

            Text {
                topPadding: 4
                text: "Tools"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Row {
                width: parent.width
                spacing: 4
                readonly property real cell: (width - 2 * spacing) / 3
                ToolTile {
                    width: parent.cell
                    glyph: Icons.eyedropper
                    label: "Pick colour"
                    onClicked: {
                        panel.visible = false
                        Tools.pickColour()
                    }
                }
                ToolTile {
                    width: parent.cell
                    glyph: Icons.coffee
                    label: Tools.keepAwake ? "Awake: on" : "Keep awake"
                    lit: Tools.keepAwake
                    onClicked: Tools.setKeepAwake(!Tools.keepAwake)
                }
                ToolTile {
                    width: parent.cell
                    glyph: Icons.textT
                    label: "Text from screen"
                    onClicked: {
                        panel.visible = false
                        Tools.readText()
                    }
                }
            }

            Row { // recent colours: a click copies
                visible: Tools.colours.length > 0
                spacing: 4
                Repeater {
                    model: Tools.colours
                    Rectangle {
                        required property string modelData
                        width: 32
                        height: 32
                        color: modelData
                        border.width: 2
                        border.color: swatchHover.containsMouse ? Theme.fg : Theme.border
                        MouseArea {
                            id: swatchHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Tools.copy(parent.modelData)
                                panel.note = "Copied " + parent.modelData
                            }
                        }
                    }
                }
            }

            Text {
                visible: panel.note !== ""
                text: panel.note
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
    }
}
