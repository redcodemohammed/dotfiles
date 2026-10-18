import QtQuick
import Quickshell

// System panel (owner, 2026-10-18): drops from the bar's system block, 360 wide, 4px under the
// bar, its right edge on the block's. CPU (use, temperature, the last minute as a graph), memory
// (used of total, graph), every disk (used of size, a bar) and the three busiest processes
// (sys-top, read only while the panel is open). Closes on an outside click or Escape. Values:
// SystemStats.qml.
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
    grabFocus: false // Reveal's focus grab
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: {
        SystemStats.watchingTop = visible
        if (!visible)
            closedAt = Date.now()
    }

    // A section's title row: glyph and name on the left, the figures on the right.
    component Heading: Item {
        property string glyph
        property string label
        property string value
        width: column.width
        height: 20
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.glyph
                font.family: Icons.regular
                font.pixelSize: 16
                color: Theme.fgMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fg
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
    }

    component Caption: Text {
        topPadding: 4
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }

    Reveal { id: reveal; window: panel; target: body } // slides in and out like a window

    Rectangle {
        id: body
        width: parent.width
        implicitHeight: column.implicitHeight + 24
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: reveal.close()

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Caption { topPadding: 0; text: "System" }

            Heading {
                glyph: Icons.cpu
                label: "CPU"
                value: Math.round(SystemStats.cpu) + "%"
                    + (SystemStats.temp >= 0 ? "  ·  " + Math.round(SystemStats.temp) + "°C" : "")
            }
            SparkGraph {
                width: column.width
                height: 40
                values: SystemStats.cpuHistory
                length: SystemStats.historyLength
            }

            Heading {
                glyph: Icons.memory
                label: "Memory"
                value: SystemStats.gigabytes(SystemStats.memUsed) + " / " + SystemStats.gigabytes(SystemStats.memTotal) + " GB"
            }
            SparkGraph {
                width: column.width
                height: 40
                values: SystemStats.memHistory
                length: SystemStats.historyLength
            }

            Caption { text: "Disks" }
            Repeater {
                model: SystemStats.disks
                Column {
                    required property var modelData
                    width: column.width
                    spacing: 4
                    Heading {
                        glyph: Icons.hardDrive
                        label: parent.modelData.target.replace(Quickshell.env("HOME"), "~")
                        value: SystemStats.gigabytes(parent.modelData.used) + " / " + SystemStats.gigabytes(parent.modelData.size) + " GB  ·  " + Math.round(parent.modelData.percent) + "%"
                    }
                    Rectangle { // used of size
                        width: column.width
                        height: 8
                        color: Theme.bg
                        Rectangle {
                            width: parent.width * Math.min(100, parent.parent.modelData.percent) / 100
                            height: parent.height
                            color: Theme.fgMuted
                        }
                    }
                }
            }

            Caption { text: "Top processes" }
            Text {
                visible: SystemStats.top.length === 0
                text: "Measuring..."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }
            Repeater {
                model: SystemStats.top
                Item {
                    required property var modelData
                    width: column.width
                    height: 20
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - figures.implicitWidth - 8
                        elide: Text.ElideRight
                        text: parent.modelData.name
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fg
                    }
                    Text {
                        id: figures
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.cpu.toFixed(1) + "%  ·  " + SystemStats.gigabytes(parent.modelData.mem) + " GB"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
            }
        }
    }
}
