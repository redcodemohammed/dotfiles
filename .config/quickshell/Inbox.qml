import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Notification inbox. Same look as the island card: 360px wide, top-right, 4px below
// the bar, flush with the right edge. Rows scroll when the list is long.
// SUPER + I toggles, Escape closes. Opening clears the unread count.
// J/K or arrows move, Enter runs the default action, X dismisses. Letters by keycode.
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
        implicitHeight: Math.max(list.contentHeight, 44) + 4 + footer.height
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onPressed: event => {
            const code = event.nativeScanCode // XKB keycode: j = 44, k = 45, x = 53
            const current = Notifs.entries[list.currentIndex]
            if (event.key === Qt.Key_Escape) {
                Notifs.setInbox(false)
            } else if (event.key === Qt.Key_Down || code === 44) {
                list.incrementCurrentIndex()
            } else if (event.key === Qt.Key_Up || code === 45) {
                list.decrementCurrentIndex()
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && current) {
                if (Notifs.invoke(current))
                    Notifs.setInbox(false)
            } else if (code === 53 && current) {
                Notifs.dismiss(current)
            } else {
                return
            }
            event.accepted = true
        }

        Connections {
            target: Notifs
            function onInboxOpenChanged() {
                if (Notifs.inboxOpen)
                    list.currentIndex = 0
            }
        }

        ListView {
            id: list
            x: 2
            y: 2
            width: parent.width - 4
            height: parent.height - 4 - footer.height
            clip: true
            model: Notifs.entries
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property string icon: modelData.image !== "" ? modelData.image
                    : modelData.appIcon !== "" ? Quickshell.iconPath(modelData.appIcon, true)
                    : ""

                width: ListView.view.width
                height: rowContent.implicitHeight + 24

                // Selected: lighter surface plus a 2px amber marker on the left edge.
                Rectangle {
                    anchors.fill: parent
                    visible: row.ListView.isCurrentItem
                    color: Theme.surfaceSelected

                    Rectangle {
                        width: 2
                        height: parent.height
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: list.currentIndex = row.index
                }

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

        // Footer: 2px divider, then Clear all on the right.
        Item {
            id: footer
            visible: Notifs.entries.length > 0
            x: 2
            y: parent.height - 2 - height
            width: parent.width - 4
            height: visible ? 34 : 0

            Rectangle {
                width: parent.width
                height: 2
                color: Theme.border
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                text: "Clear all"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: clearArea.containsMouse ? Theme.fg : Theme.fgMuted

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: Notifs.clearAll()
                }
            }
        }
    }
}
