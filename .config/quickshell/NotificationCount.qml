import QtQuick

// Anything unread? A dimmed bell at zero; the filled bell plus count in full colour when unread
// (its chip's hue, owner 2026-10-20). Do Not Disturb swaps the glyph to a slashed bell.
// Left click opens (or closes) the inbox; right click toggles Do Not Disturb: no island cards,
// the inbox still collects (owner, 2026-10-16).
Item {
    id: root
    readonly property int unread: Notifs.unread
    readonly property bool dnd: Notifs.dnd
    property color hue: Theme.accent
    readonly property color ink: unread > 0 ? hue : Qt.rgba(hue.r, hue.g, hue.b, 0.6)

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
            color: root.ink
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.unread > 0
            text: root.unread
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: root.ink
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
