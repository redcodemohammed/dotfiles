import QtQuick
import Quickshell
import Quickshell.Widgets

// Island notification (design: Notify / NotifyAr artboards and the Desktop prototype).
// Opens expanded, 360 wide: icon, title, time, amber unread count, 2-line body,
// Reply (runs the default action; labelled with the action's own text when the app gives one,
// e.g. "Apply now") and Dismiss, then "Earlier" x2.
// Arabic text: right-to-left, Vazirmatn 14/22, no Earlier list.
// Height follows the content; the island reads implicitHeight.
Item {
    id: root
    required property var entry
    readonly property bool rtl: /[؀-ۿ]/.test((entry ? entry.summary + entry.body : ""))
    readonly property string family: rtl ? "Vazirmatn" : "JetBrainsMono Nerd Font"
    readonly property int lineHeight: rtl ? 22 : 20
    readonly property var defaultAction: entry && entry.notification
        ? (entry.notification.actions.find(a => a.identifier === "default") ?? null) : null
    readonly property bool canReply: defaultAction !== null
    readonly property string replyLabel: {
        const t = defaultAction ? defaultAction.text.trim() : ""
        return t !== "" && t.toLowerCase() !== "default" ? t : rtl ? "رد" : "Reply"
    }
    readonly property var earlier: rtl || !entry ? [] : Notifs.entries.filter(e => e !== entry).slice(0, 2)
    readonly property string icon: !entry ? ""
        : entry.image !== "" ? entry.image
        : entry.appIcon !== "" ? Quickshell.iconPath(entry.appIcon, true)
        : ""

    implicitHeight: column.implicitHeight + 24

    LayoutMirroring.enabled: rtl
    LayoutMirroring.childrenInherit: true

    function when(time) {
        if (Date.now() - time.getTime() < 60000)
            return root.rtl ? "الآن" : "now"
        return Qt.formatDateTime(time, "HH:mm")
    }

    component Button: Rectangle {
        property string label
        property bool primary
        signal clicked
        height: 40
        color: primary ? Theme.surfaceSelected : Theme.surface
        border.width: 2
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: parent.label
            font.family: root.family
            font.pixelSize: 13
            color: parent.primary ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    Column {
        id: column
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        // Header: icon, title, time, unread count.
        Item {
            width: parent.width
            height: 24

            Item {
                id: iconBox
                anchors.left: parent.left // anchored, so right-to-left mirroring moves it
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

            Text {
                anchors.left: iconBox.right
                anchors.leftMargin: 12
                anchors.right: time.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.entry ? root.entry.summary : ""
                elide: Text.ElideRight
                font.family: root.family
                font.pixelSize: 14
                color: Theme.fg
            }

            Text {
                id: time
                anchors.right: badge.visible ? badge.left : parent.right
                anchors.rightMargin: badge.visible ? 12 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.entry ? root.when(root.entry.time) : ""
                font.family: root.family
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Rectangle {
                id: badge
                visible: Notifs.unread > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(24, count.implicitWidth + 8)
                height: 24
                color: Theme.accent
                Text {
                    id: count
                    anchors.centerIn: parent
                    text: Notifs.unread
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.textOnAccent
                }
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.entry ? root.entry.body : ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: root.lineHeight
            lineHeightMode: Text.FixedHeight
            horizontalAlignment: root.rtl ? Text.AlignRight : Text.AlignLeft
            font.family: root.family
            font.pixelSize: 14
            color: Theme.fgMuted
        }

        Row {
            width: parent.width
            spacing: 4
            Button {
                visible: root.canReply
                width: (parent.width - 4) / 2
                primary: true
                label: root.replyLabel
                onClicked: {
                    Notifs.invoke(root.entry)
                    IslandState.next()
                }
            }
            Button {
                width: root.canReply ? (parent.width - 4) / 2 : parent.width
                label: root.rtl ? "تجاهل" : "Dismiss"
                onClicked: IslandState.next() // the inbox keeps it
            }
        }

        // Earlier: the two notifications before this one.
        Rectangle {
            visible: root.earlier.length > 0
            width: parent.width
            height: 2
            color: Theme.border
        }

        Column {
            visible: root.earlier.length > 0
            width: parent.width
            spacing: 4

            Text {
                text: "Earlier"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Repeater {
                model: root.earlier
                Item {
                    required property var modelData
                    width: parent.width
                    height: 24
                    Text {
                        id: app
                        width: 56
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.appName
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                    Text {
                        anchors.left: app.right
                        anchors.leftMargin: 8
                        anchors.right: at.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.summary
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fg
                    }
                    Text {
                        id: at
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(modelData.time, "HH:mm")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                }
            }
        }
    }
}
