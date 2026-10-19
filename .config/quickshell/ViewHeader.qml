import QtQuick

// The head of a quick-settings view (owner, 2026-10-20): a back button (to the top level, as
// Escape) and the view's name; `content` holds the view's own controls (a switch) at the far end.
Item {
    id: header
    property string title
    default property alias content: rightSide.data
    signal back
    width: parent.width
    height: 44

    Rectangle {
        id: backButton
        x: 16
        y: 8
        width: 32
        height: 32
        radius: 8
        color: backHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            anchors.centerIn: parent
            text: Icons.caretLeft
            font.family: Icons.regular
            font.pixelSize: 16
            color: Theme.fg
        }
        MouseArea {
            id: backHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: header.back()
        }
    }
    Text {
        x: backButton.x + backButton.width + 10
        anchors.verticalCenter: backButton.verticalCenter
        text: header.title
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Theme.fg
    }
    Row {
        id: rightSide
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: backButton.verticalCenter
        spacing: 8
    }
}
