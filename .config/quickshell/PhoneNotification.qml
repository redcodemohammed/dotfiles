import QtQuick
import Quickshell

// One phone notification in the phone panel's Inbox (owner's design "Phone bridge"; a card since the
// "Remaining panels" design, 2026-10-20, a step lighter while open): a dot in the accent while unread (2026-10-25: less colour), the app and time (muted), the title, and the text (two lines, all of it when open).
// A click opens it (and marks it read): Reply when the app accepts replies (Enter or Send), Copy
// code when the text carries a verification code, and Dismiss (on the phone too).
Rectangle {
    id: item
    required property var modelData
    property var owner // the panel
    readonly property var n: modelData
    readonly property bool expanded: owner !== undefined && owner.sel === n.id
    readonly property string code: Phone.codeIn(n.title + " " + n.text)

    height: col.implicitHeight + 4
    radius: 12
    color: expanded || cardHover.containsMouse ? Edge.controlHover : Edge.control
    HoverHandler { id: cardHover }

    Column {
        id: col
        x: 2
        y: 2
        width: parent.width - 4

        Item { // the notification itself
            width: parent.width
            height: head.implicitHeight + 16
            Column {
                id: head
                x: 8
                y: 8
                width: parent.width - 16
                spacing: 4
                Item {
                    width: parent.width
                    height: 16
                    Rectangle {
                        id: dot
                        visible: item.n.unread
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: height / 2 // a pill (owner, 2026-10-20: rounded)
                        color: Theme.accent
                    }
                    Text {
                        x: dot.visible ? 16 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: time.x - x - 8
                        text: item.n.app
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Text {
                        id: time
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.n.time
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
                Text {
                    width: parent.width
                    text: item.n.title
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
                Text {
                    width: parent.width
                    text: item.n.text
                    wrapMode: Text.Wrap
                    maximumLineCount: item.expanded ? 1000 : 2
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fgMuted
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    item.owner.sel = item.expanded ? "" : item.n.id
                    item.owner.replyText = ""
                    if (item.n.unread)
                        Phone.markRead(item.n.id)
                }
            }
        }

        Column { // opened
            visible: item.expanded
            x: 8
            width: parent.width - 16
            spacing: 8
            bottomPadding: 8

            PanelInput {
                id: replyField
                visible: item.n.replyId !== "" && Phone.settings.replyFromDesktop !== false
                width: parent.width
                placeholder: "Reply"
                action: "Send"
                onEdited: item.owner.replyText = text
                onAccepted: {
                    const t = text.trim()
                    if (t === "")
                        return
                    Phone.reply(item.n.replyId, t)
                    text = ""
                    item.owner.replyText = ""
                    item.owner.sel = ""
                    item.owner.say("Reply sent to " + item.n.title)
                }
            }

            Row {
                width: parent.width
                spacing: 4
                PanelButton {
                    visible: item.code !== ""
                    width: (parent.width - 4) / 2
                    primary: true
                    label: item.owner && item.owner.copied === item.n.id ? "Copied " + item.code : "Copy code " + item.code
                    onPressed: {
                        Quickshell.execDetached(["wl-copy", "--", item.code])
                        item.owner.copied = item.n.id
                        copiedReset.restart()
                    }
                }
                PanelButton {
                    width: item.code !== "" ? (parent.width - 4) / 2 : parent.width
                    label: "Dismiss"
                    onPressed: {
                        item.owner.sel = ""
                        Phone.dismiss(item.n.id)
                    }
                }
            }
        }
    }

    Timer {
        id: copiedReset
        interval: 1400
        onTriggered: if (item.owner) item.owner.copied = ""
    }
}
