import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Notification inbox. Same look as popups: 360px wide, top-right, 4px below
// the bar, flush with the right edge. Rows scroll when the list is long.
// SUPER + I toggles, Escape closes. Opening clears the unread count.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    visible: Notifs.inboxOpen && monitor && monitor.focused
    anchors {
        top: true
        right: true
    }
    margins.top: 4
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 360
    implicitHeight: Math.min(frame.implicitHeight, modelData.height - 32 - 8)
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        id: frame
        anchors.fill: parent
        implicitHeight: Math.max(list.contentHeight, 44) + 4
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: Notifs.setInbox(false)

        ListView {
            id: list
            x: 2
            y: 2
            width: parent.width - 4
            height: parent.height - 4
            clip: true
            model: Notifs.entries
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property string icon: modelData.image !== "" ? modelData.image
                    : modelData.appIcon !== "" ? Quickshell.iconPath(modelData.appIcon, true)
                    : ""

                width: ListView.view.width
                height: rowContent.implicitHeight + 24

                Rectangle {
                    visible: row.index > 0
                    width: parent.width
                    height: 2
                    color: Theme.border
                }

                Row {
                    id: rowContent
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 12

                    Item {
                        width: 24
                        height: 24

                        IconImage {
                            visible: row.icon !== ""
                            source: row.icon
                            implicitSize: 24
                        }

                        Text {
                            visible: row.icon === ""
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

                        Item {
                            width: parent.width
                            height: title.implicitHeight

                            Text {
                                id: title
                                width: parent.width - time.implicitWidth - 8
                                text: row.modelData.summary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: Theme.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                id: time
                                anchors.right: parent.right
                                text: Qt.formatDateTime(row.modelData.time, "HH:mm")
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fgMuted
                            }
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.body
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

            Text {
                visible: list.count === 0
                x: 12
                y: 12
                text: "No notifications"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fgMuted
            }
        }
    }
}
