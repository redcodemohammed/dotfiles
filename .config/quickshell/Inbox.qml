import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Notification inbox. Same look as the island card: 360px wide. A drop-down under the bar's bell
// like the other panels (owner, 2026-10-17; it was its own layer surface with exclusive keyboard
// focus, which on Hyprland also swallows every click elsewhere: the bell couldn't close it and
// nothing else opened). Reveal gives it the panels' slide, focus grab (keyboard, close on an
// outside click) and one-panel-at-a-time. Rows scroll when the list is long.
// SUPER + I or a left click on the bell toggles it (Notifs.inboxOpen; the focused screen's bar
// shows it); Escape, Clear all and dismissing the last one close it. Opening clears the unread
// count.
// J/K or arrows move, Enter runs the default action, X dismisses. Letters by keycode.
// Notifications with more than one action (screenshots, recordings) show them as buttons under
// the body (ActionRow); a click runs one and closes the inbox.
PopupWindow {
    id: root
    required property var bar
    required property var block
    property bool atRight: false // hung from the power chip at the bar's right end (a slim bar)
    readonly property var monitor: Hyprland.monitorFor(bar.screen)

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width + reveal.overhang - implicitWidth // the body's right edge on the chip's
    anchor.rect.y: block.height + 6 // the band's bottom edge
    grabFocus: false // EdgePanel's focus grab
    visible: false
    color: "transparent"

    // Notifs.inboxOpen drives it: the focused screen's inbox opens; closing by any other way
    // (outside click, another panel) sets it back.
    property double closedAt: 0
    Connections {
        target: Notifs
        function onInboxOpenChanged() {
            if (Notifs.inboxOpen && root.monitor && root.monitor.focused && !root.visible) {
                if (Date.now() - root.closedAt < 300) // the click that closed it, landing on the bell
                    Notifs.inboxOpen = false
                else
                    root.visible = true
            } else if (!Notifs.inboxOpen && root.visible) {
                reveal.close()
            }
        }
    }
    onVisibleChanged: {
        if (!visible) {
            closedAt = Date.now()
            if (Notifs.inboxOpen)
                Notifs.setInbox(false)
        }
    }
    // 360 as designed; wider when a notification's actions (ActionRow) need it for one line:
    // 12 + 24 icon + 12 left, 12 right, 2 + 2 frame.
    implicitWidth: reveal.implicitWidth
    readonly property real bodyWidth: Math.min(Math.max(360, widestActions + 64), bar.screen.width - 12 - 2 * reveal.r)
    readonly property real widestActions: {
        let widest = 0
        for (const child of list.contentItem.children)
            if (child.actionsWidth !== undefined)
                widest = Math.max(widest, child.actionsWidth)
        return widest
    }
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }

    EdgePanel { // comes out of the frame under the bell (owner, 2026-10-20)
        id: reveal
        window: root
        atRight: root.atRight
        bodyWidth: root.bodyWidth
        // At most the screen under the band, less the frame's bottom side and the spring's room.
        bodyHeight: Math.min(Math.max(list.contentHeight, 44) + 4 + footer.height,
            root.bar.screen.height - root.bar.height - Settings.look.frame - 32)

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
                if (Notifs.entries.length === 0)
                    Notifs.setInbox(false) // the last one: nothing left to show
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
                readonly property real actionsWidth: actionRow.visible ? actionRow.oneLineWidth : 0

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

                        ActionRow {
                            id: actionRow
                            visible: row.modelData.notification
                                && row.modelData.notification.actions.length > 1
                            width: parent.width
                            entry: row.modelData
                            buttonHeight: 32
                            onInvoked: Notifs.setInbox(false)
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
                    onClicked: {
                        Notifs.clearAll()
                        Notifs.setInbox(false)
                    }
                }
            }
        }
    }
}
