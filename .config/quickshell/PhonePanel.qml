import QtQuick
import Quickshell
import Quickshell.Io

// Phone bridge panel (owner's design "Phone bridge", 2026-10-15): drops from the bar's phone
// block, 420 wide, 4px under the bar, its right edge on the block's. Grabs the keyboard, closes on
// an outside click or Escape. Header: the phone's name, "Connected · battery · network" (Low and a
// red battery at 15% or less), Reconnect while it is away (kcd has no disconnect: Unpair in
// Settings). Tabs: Inbox (unread count), Actions (ring, send clipboard, send file, transfers) and
// Settings (PhoneSettings.qml); a feature switched off there hides its action. Away: "Phone not
// connected". Inbox: the phone's notifications (Phone.qml), newest first; opening one marks it
// read and shows Reply (when the app allows it), Copy code (a verification code) and Dismiss (on
// the phone too). Clear all empties this list only. A line at the bottom confirms actions.
PopupWindow {
    id: panel
    required property var bar
    required property var block // the bar's phone block
    property real below: 0 // the incoming-call card's height and gap, while it shows (Bar.qml)

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width + reveal.overhang - implicitWidth // the body's right edge on the chip's
    anchor.rect.y: block.height + 6 + below
    implicitWidth: reveal.implicitWidth
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }
    color: "transparent"
    grabFocus: false // an outside click goes through EdgePanel's focus grab, so closing can slide
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: {
        if (!visible) {
            closedAt = Date.now()
            sel = ""
            replyText = ""
        }
    }

    property string tab: "inbox"
    property string sel: "" // the open notification
    property string replyText: ""
    property string copied: "" // notification whose code was just copied

    property string toast: ""
    Connections { // Browse phone files: close for the file manager when it opens, or say why not
        target: Phone
        function onMountingChanged() {
            if (!Phone.mounting && panel.visible && panel.toast === "")
                reveal.close()
        }
        function onMountFailed(message) {
            panel.say(message)
        }
    }
    function say(text) {
        toast = text
        toastTimer.restart()
    }
    Timer {
        id: toastTimer
        interval: 1600
        onTriggered: panel.toast = ""
    }

    readonly property string statusLine: {
        if (!Phone.connected)
            return "Not connected"
        const parts = ["Connected"]
        if (Phone.battery >= 0)
            parts.push(Phone.battery + "%" + (Phone.battery <= 15 ? " · Low" : ""))
        if (NetState.wifiNet)
            parts.push(NetState.wifiNet.name)
        return parts.join(" · ")
    }


    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        bodyWidth: 420
        bodyHeight: content.implicitHeight + 28
        focus: true
        Keys.onEscapePressed: reveal.close()

        Column {
            id: content
            // A child's own `panel` property would shadow the id in `panel: panel`.
            readonly property var owner: panel
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            Item { // the phone
                width: parent.width
                height: 40
                PhoneGlyph {
                    id: phoneGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    size: 24
                    stroke: 1.8 // the design's 1.2 at 16 units, scaled by 24/16
                }
                Column {
                    x: phoneGlyph.width + 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: headerRight.x - x - 8
                    spacing: 4
                    Text {
                        width: parent.width
                        text: Phone.name || "Phone"
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: Theme.fg
                    }
                    Text {
                        width: parent.width
                        text: panel.statusLine
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
                Row {
                    id: headerRight
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        visible: Phone.connected && Phone.battery >= 0 && Phone.battery <= 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.batteryWarning
                        font.family: Icons.fill
                        font.pixelSize: 16
                        color: Theme.alert
                    }
                    PanelButton {
                        visible: !Phone.connected
                        height: 32
                        label: "Reconnect"
                        onPressed: {
                            Phone.reconnect()
                            panel.say("Reconnecting")
                        }
                    }
                }
            }

            Row { // tabs
                width: parent.width
                spacing: 4
                Repeater {
                    model: [{ id: "inbox", label: Phone.unread > 0 ? "Inbox " + Phone.unread : "Inbox" },
                        { id: "actions", label: "Actions" }, { id: "settings", label: "Settings" }]
                    Rectangle {
                        id: tabButton
                        required property var modelData
                        readonly property bool on: panel.tab === modelData.id
                        width: (parent.width - 8) / 3
                        height: 32
                        color: on ? Theme.accent : Theme.bg
                        border.width: 2
                        border.color: on ? Theme.accent : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: tabButton.modelData.label
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: tabButton.on ? Theme.textOnAccent : Theme.fgMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panel.tab = tabButton.modelData.id
                        }
                    }
                }
            }

            Item { // away
                visible: !Phone.connected && panel.tab !== "settings"
                width: parent.width
                height: 120
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Phone not connected"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Same Wi-Fi needed"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
            }

            Column { // Inbox
                visible: Phone.connected && panel.tab === "inbox"
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 24
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Phone.unread > 0 ? Phone.unread + " unread" : "All read"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Rectangle {
                        anchors.right: parent.right
                        width: clearText.implicitWidth + 16
                        height: 24
                        color: clearArea.containsMouse ? Theme.surface : Theme.bg
                        border.width: 2
                        border.color: Theme.border
                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear all"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Phone.clearAll()
                                panel.sel = ""
                            }
                        }
                    }
                }

                Item {
                    visible: Phone.notifications.length === 0
                    width: parent.width
                    height: 80
                    Text {
                        anchors.centerIn: parent
                        text: Phone.settings.notification === false ? "Mirroring is off (Settings)" : "No notifications"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                }

                Flickable {
                    visible: Phone.notifications.length > 0
                    width: parent.width
                    height: Math.min(items.implicitHeight, 420)
                    contentHeight: items.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: items
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: Phone.notifications
                            PhoneNotification {
                                width: items.width
                                owner: items.panelRef
                            }
                        }
                        // The delegates' own `owner` property would shadow an id named alike.
                        readonly property var panelRef: panel
                    }
                }
            }

            Column { // Actions
                visible: Phone.connected && panel.tab === "actions"
                width: parent.width
                spacing: 4

                PanelButton {
                    width: parent.width
                    icon: Icons.bellRinging
                    label: "Ring phone"
                    onPressed: {
                        Phone.ring()
                        panel.say("Phone is ringing (touch it to stop)")
                    }
                }
                PanelButton {
                    visible: Phone.settings.clipboard !== false
                    width: parent.width
                    icon: Icons.clipboardText
                    label: "Send clipboard to phone"
                    onPressed: {
                        Phone.sendClipboard()
                        panel.say("Clipboard sent to phone")
                    }
                }
                PanelButton {
                    width: parent.width
                    icon: Icons.folderOpen
                    label: Phone.mounting ? "Opening phone files" : "Browse phone files"
                    available: !Phone.mounting
                    onPressed: Phone.browseFiles()
                }
                PanelButton {
                    visible: Phone.settings.share !== false
                    width: parent.width
                    icon: Icons.uploadSimple
                    label: "Send file"
                    onPressed: {
                        panel.visible = false // the file picker needs the keyboard
                        Phone.pickAndSend()
                    }
                }

                Column {
                    visible: Phone.transfers.length > 0
                    width: parent.width
                    spacing: 4
                    topPadding: 4
                    Text {
                        height: 16
                        text: "Transfers"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Repeater {
                        model: Phone.transfers
                        Rectangle {
                            id: transfer
                            required property var modelData
                            readonly property var t: modelData
                            readonly property int pct: t.total > 0 ? Math.round(t.current * 100 / t.total) : 0
                            width: parent.width
                            height: transferCol.implicitHeight + 20
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.border
                            Column {
                                id: transferCol
                                x: 10
                                y: 10
                                width: parent.width - 20
                                spacing: 4
                                Item {
                                    width: parent.width
                                    height: 16
                                    Text {
                                        width: sizeText.x - 8
                                        text: (transfer.t.up ? "↑ " : "↓ ") + transfer.t.name
                                        elide: Text.ElideMiddle
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: Theme.fg
                                    }
                                    Text {
                                        id: sizeText
                                        anchors.right: parent.right
                                        text: transfer.t.total > 0 ? NetState.amount(transfer.t.total).replace(/^0 MB$/, "< 1 MB") : ""
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: Theme.fgMuted
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    color: Theme.border
                                    Rectangle {
                                        height: 4
                                        width: transfer.t.state === "done" ? parent.width : parent.width * transfer.pct / 100
                                        color: transfer.t.state === "failed" ? Theme.alert : Theme.fg
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: transfer.t.state === "failed" ? "Failed" + (transfer.t.error ? ": " + transfer.t.error : "")
                                        : transfer.t.state === "done" ? (transfer.t.up ? "Sent" : "Saved to ~/Downloads/kcd")
                                        : (transfer.t.up ? "Sending" : "Receiving") + (transfer.t.total > 0 ? " " + transfer.pct + "%" : "")
                                    elide: Text.ElideRight
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: transfer.t.state === "failed" ? Theme.alert : Theme.fgMuted
                                }
                            }
                        }
                    }
                }
            }

            PhoneSettings {
                visible: panel.tab === "settings"
                width: parent.width
                panel: content.owner
            }

            Text { // confirmations
                width: parent.width
                height: 16
                text: panel.toast
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
    }
}
