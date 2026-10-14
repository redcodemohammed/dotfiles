import QtQuick

// A device list for the volume island (owner, 2026-10-15): divider, caption, one row per device.
// The current one has the amber marker on its left edge (the launcher's selection style); hover
// lightens the row; clicking emits picked(node). Height: 22 + 28 per device (IslandState.volumeHeight).
Column {
    id: list
    property string title
    property var nodes: []
    property var current: null
    signal picked(var node)
    width: parent.width
    spacing: 4

    Rectangle {
        width: parent.width
        height: 2
        color: Theme.border
    }
    Text {
        height: 16
        text: list.title
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
    Repeater {
        model: list.nodes
        Rectangle {
            id: row
            required property var modelData
            readonly property bool isCurrent: modelData === list.current
            width: list.width
            height: 24
            color: area.containsMouse ? Theme.surfaceSelected : "transparent"
            Rectangle {
                width: 2
                height: parent.height
                visible: row.isCurrent
                color: Theme.accent
            }
            Text {
                x: 10
                width: parent.width - 10
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.nickname || row.modelData.description || row.modelData.name
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: row.isCurrent ? Theme.fg : Theme.fgMuted
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                onClicked: list.picked(row.modelData)
            }
        }
    }
}
