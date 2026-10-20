import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Notification inbox (owner, 2026-10-17; the "Remaining panels" design since 2026-10-20): a panel
// from the Arch chip, 380 wide (wider when a notification's actions need it for one line). It was
// its own layer surface with exclusive keyboard focus, which on Hyprland also swallows every click
// elsewhere; EdgePanel gives it the panels' focus grab and one-panel-at-a-time.
// The header: Notifications, a Do Not Disturb pill (Notifs.dnd, lit coral while on) and Clear
// all. Each notification a card: its app's icon in a rounded box (a bell without one), the app
// and how long ago, the summary, two lines of body, a dismiss button; the keyboard's one (J/K) a
// step lighter. Notifications with more than one action (screenshots, recordings) show them as
// buttons under the body (ActionRow); a click runs one and closes the inbox. None: "All caught
// up". Cards scroll when the list is long.
// SUPER + I or a left click on the chip toggles it (Notifs.inboxOpen; the focused screen's bar
// shows it); Escape, Clear all and dismissing the last one close it. Opening clears the unread
// count. J/K or arrows move, Enter runs the default action, X dismisses. Letters by keycode.
PopupWindow {
    id: root
    required property var bar
    required property var block
    // From the Arch chip at the bar's left end (owner, 2026-10-20; the bell before): its body's
    // left edge on the chip's, merged into the frame's left side.
    readonly property var monitor: Hyprland.monitorFor(bar.screen)

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: 0
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
    // 380 as designed; wider when a notification's actions (ActionRow) need it for one line:
    // 16 + 12 + 32 icon + 10 left, 12 + 16 right.
    implicitWidth: reveal.implicitWidth
    readonly property real bodyWidth: Math.min(Math.max(380, widestActions + 98), bar.screen.width - 12 - reveal.r)
    readonly property real widestActions: {
        let widest = 0
        for (const child of list.contentItem.children)
            if (child.actionsWidth !== undefined)
                widest = Math.max(widest, child.actionsWidth)
        return widest
    }
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }

    function tint(c, a) { return Qt.tint(Edge.fill, Qt.rgba(c.r, c.g, c.b, a)) }
    property double now: Date.now()
    Timer { // "how long ago" moves on while it is open
        running: root.visible
        interval: 30000
        repeat: true
        onTriggered: root.now = Date.now()
    }
    function ago(time) { // now, 4 min, 2 h, else the date and time
        const s = Math.max(0, (now - time.getTime()) / 1000)
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + " min" : s < 86400 ? Math.floor(s / 3600) + " h"
            : Qt.formatDateTime(time, "d MMM HH:mm")
    }

    component HeadButton: Rectangle {
        id: headButton
        property string label
        property string glyph: ""
        property bool on
        signal clicked
        width: headRow.implicitWidth + 20
        height: 28
        radius: glyph !== "" ? 14 : 8
        color: on ? root.tint(Theme.hue1, headHover.containsMouse ? 0.22 : 0.15)
            : headHover.containsMouse ? Edge.controlHover : Edge.control
        Row {
            id: headRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: headButton.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: headButton.glyph
                font.family: headButton.on ? Icons.fill : Icons.regular
                font.pixelSize: 14
                color: headButton.on ? Theme.hue1 : Theme.fgMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: headButton.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: headButton.on ? Theme.hue1 : headButton.glyph !== "" ? Theme.fgMuted : Theme.fg
            }
        }
        MouseArea {
            id: headHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: headButton.clicked()
        }
    }

    EdgePanel { // comes out of the frame under the Arch chip (owner, 2026-10-20)
        id: reveal
        window: root
        atLeft: true
        bodyWidth: root.bodyWidth
        // At most the screen under the band, less the frame's bottom side and the spring's room.
        bodyHeight: Math.min(header.y + header.height + 8 + (list.count === 0 ? empty.height : list.contentHeight)
            + (footer.visible ? 10 + footer.height : 0) + 12,
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

        Item { // Notifications, Do Not Disturb, Clear all
            id: header
            x: 16
            y: 8
            width: parent.width - 32
            height: 32
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.fg
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                HeadButton {
                    glyph: Notifs.dnd ? Icons.bellSlash : Icons.moon
                    label: "Do Not Disturb"
                    on: Notifs.dnd
                    onClicked: Notifs.dnd = !Notifs.dnd
                }
                HeadButton {
                    visible: Notifs.entries.length > 0
                    label: "Clear all"
                    onClicked: {
                        Notifs.clearAll()
                        Notifs.setInbox(false)
                    }
                }
            }
        }

        Column { // nothing here
            id: empty
            visible: list.count === 0
            y: header.y + header.height + 8
            width: parent.width
            height: implicitHeight + 40
            topPadding: 20
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 48
                height: 48
                radius: 12
                color: Edge.control
                Text {
                    anchors.centerIn: parent
                    text: Notifs.dnd ? Icons.bellSlash : Icons.bellSimple
                    font.family: Icons.regular
                    font.pixelSize: 22
                    color: Theme.hue1
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 64
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Notifs.dnd ? "Do Not Disturb is on: new ones wait here quietly." : "New notifications wait here."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }

        ListView {
            id: list
            x: 16
            y: header.y + header.height + 8
            width: parent.width - 32
            height: parent.height - y - 12 - (footer.visible ? 10 + footer.height : 0)
            clip: true
            spacing: 8
            model: Notifs.entries
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property string icon: modelData.image !== "" ? modelData.image
                    : modelData.appIcon !== "" ? Quickshell.iconPath(modelData.appIcon, true)
                    : ""
                readonly property bool current: ListView.isCurrentItem
                readonly property real actionsWidth: actionRow.visible ? actionRow.oneLineWidth : 0

                width: ListView.view.width
                height: rowContent.implicitHeight + 24
                radius: 12
                color: current || rowHover.containsMouse ? Edge.controlHover : Edge.control

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: list.currentIndex = row.index
                }

                Row {
                    id: rowContent
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 10

                    Rectangle { // the app's icon, or a bell
                        width: 32
                        height: 32
                        radius: 8
                        color: row.icon !== "" ? root.tint(Theme.fg, 0.08) : root.tint(Theme.hue1, 0.15)
                        IconImage {
                            visible: row.icon !== ""
                            anchors.centerIn: parent
                            source: row.icon
                            implicitSize: 20
                        }
                        Text {
                            visible: row.icon === ""
                            anchors.centerIn: parent
                            text: row.modelData.urgent ? Icons.warningCircle : Icons.bellSimple
                            font.family: Icons.regular
                            font.pixelSize: 16
                            color: row.modelData.urgent ? Theme.alert : Theme.hue1
                        }
                    }

                    Column {
                        width: parent.width - 42
                        spacing: 3

                        Item { // the app, how long ago, dismiss
                            width: parent.width
                            height: 18
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - when.implicitWidth - 40
                                elide: Text.ElideRight
                                text: row.modelData.appName || "Notification"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fgMuted
                            }
                            Text {
                                id: when
                                anchors.right: dismiss.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.ago(row.modelData.time)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fgMuted
                            }
                            Rectangle {
                                id: dismiss
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                radius: 6
                                color: dismissHover.containsMouse ? root.tint(Theme.fg, 0.12) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cross
                                    font.family: Icons.regular
                                    font.pixelSize: 13
                                    color: dismissHover.containsMouse ? Theme.fg : Theme.fgMuted
                                }
                                MouseArea {
                                    id: dismissHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Notifs.dismiss(row.modelData)
                                        if (Notifs.entries.length === 0)
                                            Notifs.setInbox(false)
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: row.modelData.summary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: Theme.fg
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.body
                            textFormat: Text.PlainText
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        ActionRow {
                            id: actionRow
                            visible: row.modelData.notification
                                && row.modelData.notification.actions.length > 1
                            topPadding: 6
                            width: parent.width
                            entry: row.modelData
                            buttonHeight: 28
                            fill: root.tint(Theme.fg, 0.12)
                            onInvoked: Notifs.setInbox(false)
                        }
                    }
                }
            }
        }

        Text { // the keys
            id: footer
            visible: list.count > 0
            x: 20
            y: parent.height - 12 - height
            height: 18
            text: "J K move · Enter opens · X dismisses"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgDim
        }
    }
}
