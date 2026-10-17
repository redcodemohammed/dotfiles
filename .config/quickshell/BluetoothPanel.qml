import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets

// Bluetooth panel (owner, 2026-10-17; in place of bluetui): drops from the bar's Bluetooth block,
// 340 wide. Bluetooth on/off, then the paired devices, connected first: each row has the device's
// icon, its name and the battery level when it reports one, and Connected / Connecting / Paired.
// A click opens the row: Connect or Disconnect, and Forget (a second click within 3 s, like
// Reboot). Scan (step 5b) lists nearby devices that aren't paired; a click pairs, trusts and
// connects one. Questions during pairing (does this code match, type this code) come from
// BtAgent.qml (.local/bin/bt-agent) and show at the top. Closing the panel stops the scan.
// All of it is Quickshell.Bluetooth (BlueZ over D-Bus).
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width - implicitWidth
    anchor.rect.y: block.height + 4
    implicitWidth: 340
    implicitHeight: body.implicitHeight
    color: "transparent"
    grabFocus: false // Reveal's focus grab
    visible: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var paired: on ? Bluetooth.devices.values.filter(d => d.paired)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name)) : []
    property string sel: ""    // the open row (address)
    property string armed: ""  // the row whose Forget waits for its second click
    readonly property var nearby: on && adapter.discovering ? Bluetooth.devices.values
        .filter(d => !d.paired && (d.name || d.deviceName)).sort((a, b) => a.name.localeCompare(b.name)) : []
    property string pairingWith: "" // address being paired: trusted and connected once paired
    property string pairError: ""

    function pair(dev) {
        pairError = ""
        pairingWith = dev.address
        dev.pair()
    }
    Timer { // follows the pairing: done, or given up after 60 s
        interval: 500
        repeat: true
        running: panel.pairingWith !== ""
        property int ticks: 0
        onRunningChanged: ticks = 0
        onTriggered: {
            const dev = Bluetooth.devices.values.find(d => d.address === panel.pairingWith)
            if (dev && dev.paired) {
                dev.trusted = true
                dev.connect()
                panel.pairingWith = ""
                BtAgent.shown = null
            } else if (!dev || (!dev.pairing && ++ticks > 4) || ticks > 120) {
                panel.pairError = "Couldn't pair " + (dev ? (dev.name || dev.address) : "the device")
                panel.pairingWith = ""
                BtAgent.shown = null
            }
        }
    }

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: {
        BtAgent.panelOpen = visible
        if (!visible) {
            closedAt = Date.now()
            sel = ""
            armed = ""
            pairError = ""
            if (adapter && adapter.discovering)
                adapter.discovering = false
            BtAgent.answer("no")
        }
    }
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: panel.armed = ""
    }

    Reveal { id: reveal; window: panel; target: body } // slides in and out like a window

    component Label: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fg
    }
    component Action: Rectangle {
        id: action
        property string label
        property bool primary: false
        signal clicked
        width: actionText.implicitWidth + 24
        height: 28
        color: primary ? Theme.accent : actionHover.containsMouse ? Theme.surfaceSelected : Theme.bg
        border.width: 2
        border.color: primary ? Theme.accent : Theme.border
        Label {
            id: actionText
            anchors.centerIn: parent
            text: action.label
            color: action.primary ? Theme.textOnAccent : Theme.fg
        }
        MouseArea {
            id: actionHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: action.clicked()
        }
    }

    Rectangle {
        id: body
        width: parent.width
        implicitHeight: column.implicitHeight + 24
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: reveal.close()

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 4

            Item {
                width: parent.width
                height: 28
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.adapter === null ? "No Bluetooth adapter" : "Bluetooth"
                }
                PanelSwitch {
                    visible: panel.adapter !== null
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: panel.on
                    onToggled: panel.adapter.enabled = !panel.on
                }
            }

            Rectangle { // the agent's question, or the code to type
                visible: BtAgent.request !== null || BtAgent.shown !== null
                width: parent.width
                height: visible ? promptColumn.implicitHeight + 24 : 0
                color: Theme.bg
                border.width: 2
                border.color: Theme.accent
                Column {
                    id: promptColumn
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 8
                    readonly property var req: BtAgent.request
                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: {
                            const q = promptColumn.req
                            if (q === null)
                                return BtAgent.shown ? "Type " + BtAgent.shown.code + " on "
                                    + BtAgent.nameOf(BtAgent.shown.address) + ", then Enter" : ""
                            const name = BtAgent.nameOf(q.address)
                            return q.kind === "confirm" ? "Does " + name + " show " + q.code + "?"
                                : q.kind === "authorize" ? "Pair with " + name + "?"
                                : q.kind === "passkey" ? "Type the code " + name + " shows"
                                : "PIN for " + name + " (often 0000)"
                        }
                    }
                    PanelInput {
                        id: codeField
                        visible: promptColumn.req !== null && (promptColumn.req.kind === "passkey" || promptColumn.req.kind === "pin")
                        width: parent.width
                        placeholder: "Code"
                        onAccepted: { BtAgent.answer(text); text = "" }
                        onVisibleChanged: if (visible) focusInput()
                    }
                    Row {
                        visible: promptColumn.req !== null
                        spacing: 4
                        Action {
                            label: promptColumn.req && promptColumn.req.kind === "confirm" ? "Yes, pair" : promptColumn.req && promptColumn.req.kind === "authorize" ? "Pair" : "OK"
                            primary: true
                            onClicked: {
                                const k = promptColumn.req.kind
                                BtAgent.answer(k === "passkey" || k === "pin" ? codeField.text : "yes")
                                codeField.text = ""
                            }
                        }
                        Action {
                            label: "Cancel"
                            onClicked: BtAgent.answer("no")
                        }
                    }
                }
            }

            Text {
                visible: panel.pairError !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: panel.pairError
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.alert
            }

            Text {
                visible: panel.on
                topPadding: 4
                text: panel.paired.length > 0 ? "Paired devices" : "No paired devices"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Repeater {
                model: panel.paired
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var dev: modelData
                    readonly property bool open: panel.sel === dev.address
                    readonly property bool busy: dev.state === BluetoothDeviceState.Connecting
                        || dev.state === BluetoothDeviceState.Disconnecting
                    width: column.width
                    height: rowBody.height + 4
                    color: open ? Theme.bg : rowHover.containsMouse ? Theme.surfaceSelected : "transparent"
                    border.width: 2
                    border.color: open ? Theme.border : "transparent"

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            panel.sel = row.open ? "" : row.dev.address
                            panel.armed = ""
                        }
                    }

                    Column {
                        id: rowBody
                        x: 2
                        y: 2
                        width: parent.width - 4

                        Item {
                            width: parent.width
                            height: 36
                            IconImage {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 20
                                source: Quickshell.iconPath(row.dev.icon || "bluetooth", "bluetooth")
                            }
                            Label {
                                x: 36
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 36 - tag.implicitWidth - 16
                                elide: Text.ElideRight
                                text: row.dev.name || row.dev.deviceName || row.dev.address
                                color: row.dev.connected ? Theme.fg : Theme.fgMuted
                            }
                            Label {
                                id: tag
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: (row.dev.batteryAvailable ? Math.round(row.dev.battery * 100) + "%  " : "")
                                    + (row.busy ? (row.dev.connected ? "Disconnecting" : "Connecting")
                                       : row.dev.connected ? "Connected" : "Paired")
                                color: row.dev.connected ? Theme.accent : Theme.fgDim
                            }
                        }

                        Row { // the open row's actions
                            visible: row.open
                            x: 8
                            height: visible ? 40 : 0
                            spacing: 4
                            Action {
                                label: row.dev.connected ? "Disconnect" : "Connect"
                                primary: !row.dev.connected
                                onClicked: row.dev.connected ? row.dev.disconnect() : row.dev.connect()
                            }
                            Action {
                                label: panel.armed === row.dev.address ? "Again?" : "Forget"
                                onClicked: {
                                    if (panel.armed !== row.dev.address) {
                                        panel.armed = row.dev.address
                                        armTimer.restart()
                                    } else {
                                        panel.armed = ""
                                        panel.sel = ""
                                        row.dev.forget()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { // Scan, then what it finds
                visible: panel.on
                width: parent.width
                height: 36
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: panel.adapter && panel.adapter.discovering ? "Nearby" : "Pair a new device"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                Action {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    label: panel.adapter && panel.adapter.discovering ? "Stop" : "Scan"
                    onClicked: panel.adapter.discovering = !panel.adapter.discovering
                }
            }

            Text {
                visible: panel.on && panel.adapter.discovering && panel.nearby.length === 0
                text: "Looking… put the device in pairing mode"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }

            Repeater {
                model: panel.nearby
                Rectangle {
                    id: near
                    required property var modelData
                    readonly property bool pairing: panel.pairingWith === modelData.address
                    width: column.width
                    height: 40
                    color: nearHover.containsMouse ? Theme.surfaceSelected : "transparent"
                    IconImage {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 20
                        source: Quickshell.iconPath(near.modelData.icon || "bluetooth", "bluetooth")
                    }
                    Label {
                        x: 38
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38 - nearTag.implicitWidth - 20
                        elide: Text.ElideRight
                        text: near.modelData.name || near.modelData.deviceName
                    }
                    Label {
                        id: nearTag
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: near.pairing ? "Pairing…" : "Pair"
                        color: near.pairing ? Theme.accent : Theme.fgDim
                    }
                    MouseArea {
                        id: nearHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: panel.pairingWith === ""
                        onClicked: panel.pair(near.modelData)
                    }
                }
            }
        }
    }
}
