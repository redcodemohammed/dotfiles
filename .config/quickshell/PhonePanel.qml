import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Phone bridge panel (owner's design "Phone bridge", 2026-10-15; the "Remaining panels" design
// since 2026-10-20): comes out of the frame under the bar's phone block, 380 wide, its right edge
// on the block's. Closes on an outside click or Escape. One page, no tabs:
// The header: the phone in a lilac box, its name, "Connected · battery · network" (Low and a red
// battery at 15% or less), Reconnect while it is away (kcd has no disconnect: Unpair in its
// settings), and a gear that pushes the settings view (PhoneSettings.qml) on a StackView, as quick
// settings' views (back or Escape pops it, closing returns to the top level).
// The actions as tiles, each in its hue: Ring, Clipboard (send it), Send file, Files (browse the
// phone's); a feature switched off in the settings hides its tile. Transfers under them while any
// run. Then the inbox: the phone's notifications (Phone.qml) as cards, newest first; opening one
// marks it read and shows Reply (when the app allows it), Copy code (a verification code) and
// Dismiss (on the phone too). Clear all empties this list only. Away: "Phone not connected".
// A green line at the bottom confirms actions.
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
            sel = ""
            replyText = ""
            stack.pop(null, StackView.Immediate)
        }
    }

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


    function tint(c, a) { return Qt.tint(Edge.fill, Qt.rgba(c.r, c.g, c.b, a)) }
    // The action tiles shown: a feature switched off in the settings hides its tile.
    readonly property var tiles: [
        { id: "ring", label: "Ring", glyph: Icons.bellRinging, hue: Theme.hue1, shown: true },
        { id: "clipboard", label: "Clipboard", glyph: Icons.clipboardText, hue: Theme.hue4, shown: Phone.settings.clipboard !== false },
        { id: "send", label: "Send file", glyph: Icons.uploadSimple, hue: Theme.hue2, shown: Phone.settings.share !== false },
        { id: "files", label: Phone.mounting ? "Opening" : "Files", glyph: Icons.folderOpen, hue: Theme.hue3, shown: true },
    ].filter(t => t.shown)
    function act(id) {
        if (id === "ring") {
            Phone.ring()
            say("Phone is ringing (touch it to stop)")
        } else if (id === "clipboard") {
            Phone.sendClipboard()
            say("Clipboard sent to phone")
        } else if (id === "send") {
            visible = false // the file picker needs the keyboard
            Phone.pickAndSend()
        } else if (id === "files" && !Phone.mounting) {
            Phone.browseFiles()
        }
    }

    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        bodyWidth: 380
        bodyHeight: stack.currentItem ? stack.currentItem.implicitHeight : topLevel.implicitHeight
        focus: true
        Keys.onEscapePressed: stack.depth > 1 ? stack.pop() : reveal.close()

        // The settings view slides in from the right over the top level, and back out.
        StackView {
            id: stack
            width: parent.width
            height: reveal.bodyHeight
            clip: true
            initialItem: topLevel
            readonly property int pace: Settings.look.animations ? 250 : 0
            pushEnter: Transition { XAnimator { from: stack.width; to: 0; duration: stack.pace; easing.type: Easing.OutCubic } }
            pushExit: Transition { XAnimator { from: 0; to: -stack.width / 3; duration: stack.pace; easing.type: Easing.OutCubic } }
            popEnter: Transition { XAnimator { from: -stack.width / 3; to: 0; duration: stack.pace; easing.type: Easing.OutCubic } }
            popExit: Transition { XAnimator { from: 0; to: stack.width; duration: stack.pace; easing.type: Easing.OutCubic } }
        }

        Item { // the top level
            id: topLevel
            implicitHeight: content.implicitHeight + 24
        Column {
            id: content
            x: 16
            y: 8
            width: stack.width - 32
            spacing: 14

            Item { // the phone
                width: parent.width
                height: 40
                Rectangle {
                    id: phoneBox
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 8
                    color: panel.tint(Theme.hue5, 0.15)
                    PhoneGlyph {
                        anchors.centerIn: parent
                        size: 18
                        stroke: 1.4
                        color: Theme.hue5
                    }
                }
                Column {
                    x: phoneBox.width + 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: headerRight.x - x - 8
                    spacing: 2
                    Text {
                        width: parent.width
                        text: Phone.name || "Phone"
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
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
                    Rectangle { // the settings view
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 8
                        color: gearHover.containsMouse ? Edge.controlHover : Edge.control
                        Text {
                            anchors.centerIn: parent
                            text: Icons.gear
                            font.family: Icons.regular
                            font.pixelSize: 15
                            color: gearHover.containsMouse ? Theme.fg : Theme.fgMuted
                        }
                        MouseArea {
                            id: gearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: stack.push(settingsView)
                        }
                    }
                }
            }

            Column { // away
                visible: !Phone.connected
                width: parent.width
                topPadding: 16
                bottomPadding: 16
                spacing: 10
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    radius: 12
                    color: Edge.control
                    PhoneGlyph {
                        anchors.centerIn: parent
                        size: 22
                        stroke: 1.6
                        color: Theme.fgMuted
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Phone not connected"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fg
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "It needs to be on the same Wi-Fi."
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }

            Row { // the actions
                visible: Phone.connected
                width: parent.width
                spacing: 6
                Repeater {
                    model: panel.tiles
                    Rectangle {
                        id: tile
                        required property var modelData
                        width: (content.width - 6 * (panel.tiles.length - 1)) / panel.tiles.length
                        height: 64
                        radius: 12
                        color: tileHover.containsMouse ? Edge.controlHover : Edge.control
                        opacity: modelData.id === "files" && Phone.mounting ? 0.5 : 1
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.glyph
                                font.family: Icons.regular
                                font.pixelSize: 18
                                color: tile.modelData.hue
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fg
                            }
                        }
                        MouseArea {
                            id: tileHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: panel.act(tile.modelData.id)
                        }
                    }
                }
            }

            Column { // transfers
                visible: Phone.connected && Phone.transfers.length > 0
                width: parent.width
                spacing: 6
                Repeater {
                    model: Phone.transfers
                    Rectangle {
                        id: transfer
                        required property var modelData
                        readonly property var t: modelData
                        readonly property int pct: t.total > 0 ? Math.round(t.current * 100 / t.total) : 0
                        readonly property color hue: t.state === "failed" ? Theme.alert : Theme.hue2
                        width: parent.width
                        height: transferCol.implicitHeight + 20
                        radius: 12
                        color: Edge.control
                        Column {
                            id: transferCol
                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 8
                            Item {
                                width: parent.width
                                height: 16
                                Text {
                                    width: stateText.x - 8
                                    text: (transfer.t.up ? "Sending " : "Receiving ") + transfer.t.name
                                    elide: Text.ElideMiddle
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: Theme.fg
                                }
                                Text {
                                    id: stateText
                                    anchors.right: parent.right
                                    text: transfer.t.state === "failed" ? "Failed"
                                        : transfer.t.state === "done" ? (transfer.t.up ? "Sent" : "Saved")
                                        : transfer.t.total > 0 ? transfer.pct + "%" : ""
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: transfer.hue
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 4
                                radius: 2
                                color: panel.tint(Theme.fg, 0.12)
                                Rectangle {
                                    height: 4
                                    radius: 2
                                    width: transfer.t.state === "done" ? parent.width : parent.width * transfer.pct / 100
                                    color: transfer.hue
                                }
                            }
                            Text {
                                visible: text !== ""
                                width: parent.width
                                text: transfer.t.state === "failed" ? (transfer.t.error || "")
                                    : transfer.t.state === "done" && !transfer.t.up ? "In ~/Downloads/kcd"
                                    : transfer.t.total > 0 ? NetState.amount(transfer.t.total).replace(/^0 MB$/, "< 1 MB") : ""
                                elide: Text.ElideRight
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fgMuted
                            }
                        }
                    }
                }
            }

            Column { // the inbox
                visible: Phone.connected
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 24
                    Text {
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: Phone.unread > 0 ? "Inbox · " + Phone.unread + " unread" : "Inbox"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Rectangle {
                        visible: Phone.notifications.length > 0
                        anchors.right: parent.right
                        width: clearText.implicitWidth + 16
                        height: 24
                        radius: 6
                        color: clearArea.containsMouse ? Edge.controlHover : "transparent"
                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear all"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: clearArea.containsMouse ? Theme.fg : Theme.fgMuted
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

                Rectangle {
                    visible: Phone.notifications.length === 0
                    width: parent.width
                    height: 56
                    radius: 12
                    color: Edge.control
                    Text {
                        anchors.centerIn: parent
                        text: Phone.settings.notification === false ? "Mirroring is off (settings)" : "No notifications"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }

                Flickable {
                    visible: Phone.notifications.length > 0
                    width: parent.width
                    height: Math.min(items.implicitHeight, 400)
                    contentHeight: items.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: items
                        width: parent.width
                        spacing: 6
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

            Rectangle { // confirmations
                visible: panel.toast !== ""
                width: parent.width
                height: 32
                radius: 8
                color: panel.tint(Theme.hue2, 0.15)
                Text {
                    x: 12
                    width: parent.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: panel.toast
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fg
                }
            }
        }
        }

        Component {
            id: settingsView
            Item {
                id: settingsItem
                readonly property string viewName: "settings"
                implicitHeight: Math.min(viewHeader.height + 8 + phoneSettings.implicitHeight + 16,
                    panel.bar.screen.height - panel.bar.height - Settings.look.frame - 32)
                ViewHeader {
                    id: viewHeader
                    title: "Phone settings"
                    onBack: stack.pop()
                }
                Flickable {
                    y: viewHeader.height + 8
                    width: parent.width
                    height: parent.height - y
                    contentHeight: phoneSettings.implicitHeight + 16
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    PhoneSettings {
                        id: phoneSettings
                        x: 16
                        width: parent.width - 32
                        panel: settingsItem.settingsPanelRef
                    }
                }
                // PhoneSettings' own `panel` property would shadow the id in `panel: panel`.
                readonly property var settingsPanelRef: panel
            }
        }
    }
}
