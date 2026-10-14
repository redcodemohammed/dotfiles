import QtQuick

// Anything unread? Gray bell at zero. Amber filled bell plus count when unread.
// Do Not Disturb swaps the glyph to a slashed bell; amber still means unread.
Row {
    readonly property int unread: Notifs.unread
    readonly property bool dnd: Notifs.dnd
    readonly property color tint: unread > 0 ? Theme.accent : Theme.fgMuted

    spacing: 4

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: parent.dnd ? Icons.bellSlash : Icons.bellSimple
        font.family: parent.unread > 0 && !parent.dnd ? Icons.fill : Icons.regular
        font.pixelSize: 16
        color: parent.tint
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.unread > 0
        text: parent.unread
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: parent.tint
    }
}
