import QtQuick

// Anything unread? Gray bell at zero. Amber filled bell plus count when unread.
// Do Not Disturb swaps the glyph to a slashed bell; amber still means unread.
// Left click opens (or closes) the inbox; right click toggles Do Not Disturb: no island cards,
// the inbox still collects (owner, 2026-10-16).
Item {
    id: root
    readonly property int unread: Notifs.unread
    readonly property bool dnd: Notifs.dnd
    readonly property color tint: unread > 0 ? Theme.accent : Theme.fgMuted

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dnd ? Icons.bellSlash : Icons.bellSimple
            font.family: root.unread > 0 && !root.dnd ? Icons.fill : Icons.regular
            font.pixelSize: 16
            color: root.tint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.unread > 0
            text: root.unread
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: root.tint
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8 // easier to hit
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Notifs.dnd = !Notifs.dnd
            else
                Notifs.toggleInbox()
        }
    }
}
