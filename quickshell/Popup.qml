import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification card. 360px wide, 12px padding, solid surface, 2px border.
// Urgent: red border and no timeout. Otherwise hides after 5 s (stays in the inbox).
// Click hides it early.
Rectangle {
    id: root
    required property var modelData
    readonly property bool urgent: modelData.urgency === NotificationUrgency.Critical
    // Image hint, else the app icon if the theme has it, else a generic bell glyph.
    readonly property string icon: modelData.image !== "" ? modelData.image
        : modelData.appIcon !== "" ? Quickshell.iconPath(modelData.appIcon, true)
        : ""

    width: 360
    implicitHeight: content.implicitHeight + 24
    color: Theme.surface
    border.width: 2
    border.color: urgent ? Theme.alert : Theme.border

    Timer {
        interval: 5000
        running: !root.urgent
        onTriggered: Notifs.hidePopup(root.modelData)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifs.hidePopup(root.modelData)
    }

    Row {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 12

        Item {
            width: 24
            height: 24

            IconImage {
                visible: root.icon !== ""
                source: root.icon
                implicitSize: 24
            }

            Text {
                visible: root.icon === ""
                anchors.centerIn: parent
                text: Icons.bellSimple
                font.family: Icons.regular
                font.pixelSize: 24
                color: Theme.fgMuted
            }
        }

        Column {
            width: parent.width - 36
            spacing: 4

            Text {
                width: parent.width
                text: root.modelData.summary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fg
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.modelData.body
                textFormat: Text.PlainText
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fgMuted
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
