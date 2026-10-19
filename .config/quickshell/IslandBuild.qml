import QtQuick
import Quickshell

// Island build state (design: Desktop prototype, isBuild / isBuildOpen).
// Compact 320x24: check (muted) or cross (red), title, time or error count.
// Expanded 440x192: title, meta, last 4 output lines, Open terminal, Dismiss.
// Fed by bin/island-build over IPC (IslandState.build).
Item {
    id: root
    required property bool open
    required property var info // { failed, title, meta, lines, window }
    readonly property bool failed: info.failed ?? false

    component Button: Rectangle {
        property string label
        property bool primary
        signal clicked
        height: 40
        radius: 8
        color: primary ? Edge.accentTint : Edge.control
        Text {
            anchors.centerIn: parent
            text: parent.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: parent.primary ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    // Compact
    Item {
        visible: !root.open
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.failed ? Icons.cross : Icons.check
            font.family: Icons.regular
            font.pixelSize: 16
            color: root.failed ? Theme.alert : Theme.fgMuted
        }
        Text {
            anchors.left: glyph.right
            anchors.leftMargin: 8
            anchors.right: meta.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.info.title ?? ""
            elide: Text.ElideRight
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        Text {
            id: meta
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.info.meta ?? ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fgMuted
        }
    }

    // Expanded (the island draws the chevron in the header's right corner)
    Column {
        visible: root.open
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width
            height: 20
            Text {
                anchors.left: parent.left
                anchors.right: openMeta.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.info.title ?? ""
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fg
            }
            Text {
                id: openMeta
                anchors.right: parent.right
                anchors.rightMargin: 32 // chevron
                anchors.verticalCenter: parent.verticalCenter
                text: root.info.meta ?? ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
        }

        // Last output lines, on the bg color in a bordered box.
        Rectangle {
            width: parent.width
            height: output.implicitHeight + 20
            radius: 8
            color: Theme.bg // a well, darker than the island

            Column {
                id: output
                x: 10
                y: 10
                width: parent.width - 20
                Repeater {
                    model: root.info.lines ?? []
                    Text {
                        required property string modelData
                        width: output.width
                        text: modelData
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        lineHeight: 16
                        lineHeightMode: Text.FixedHeight
                        color: Theme.fgMuted
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 4
            Button {
                visible: (root.info.window ?? "") !== ""
                width: (parent.width - 4) / 2
                primary: true
                label: "Open terminal"
                onClicked: {
                    Quickshell.execDetached(["hyprctl", "dispatch",
                        'hl.dsp.focus({ window = "address:' + root.info.window + '" })'])
                    IslandState.next()
                }
            }
            Button {
                width: (root.info.window ?? "") !== "" ? (parent.width - 4) / 2 : parent.width
                label: "Dismiss"
                onClicked: IslandState.next()
            }
        }
    }
}
