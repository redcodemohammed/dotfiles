import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets

// Quick settings' Bluetooth view (owner, 2026-10-20; the Bluetooth panel before, in place of
// bluetui): opened by the Bluetooth tile's › or `qs ipc call panel toggle bluetooth`. On/off in the
// header; the connected devices (tinted, with Disconnect and the battery level when one is
// reported), then the paired ones (Connect). A row's › pushes the device page (Connect or
// Disconnect, Forget with a second click within 3 s). "Pair a new device" pushes the scan page:
// it scans while shown, lists nearby devices that aren't paired, a click pairs, trusts and
// connects one and goes back. Questions during pairing (does this code match, type this code)
// come from BtAgent.qml (.local/bin/bt-agent) and show as a card on the list and the scan page;
// the agent answers them only while this view is open (BtAgent.panelOpen). All of it is
// Quickshell.Bluetooth (BlueZ over D-Bus).
Item {
    id: view
    readonly property string viewName: "bluetooth"
    signal back
    signal push(var component, var properties)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var paired: on ? Bluetooth.devices.values.filter(d => d.paired)
        .sort((a, b) => a.name.localeCompare(b.name)) : []
    readonly property var connected: paired.filter(d => d.connected)
    readonly property var idle: paired.filter(d => !d.connected)
    property string pairingWith: "" // address being paired: trusted and connected once paired
    property string pairError: ""
    signal pairingDone

    Component.onCompleted: BtAgent.panelOpen = true
    Component.onDestruction: {
        BtAgent.panelOpen = false
        BtAgent.answer("no")
    }

    function pair(dev) {
        pairError = ""
        pairingWith = dev.address
        dev.pair()
    }
    Timer { // follows the pairing: done, or given up after 60 s
        interval: 500
        repeat: true
        running: view.pairingWith !== ""
        property int ticks: 0
        onRunningChanged: ticks = 0
        onTriggered: {
            const dev = Bluetooth.devices.values.find(d => d.address === view.pairingWith)
            if (dev && dev.paired) {
                dev.trusted = true
                dev.connect()
                view.pairingWith = ""
                BtAgent.shown = null
                view.pairingDone()
            } else if (!dev || (!dev.pairing && ++ticks > 4) || ticks > 120) {
                view.pairError = "Couldn't pair " + (dev ? (dev.name || dev.address) : "the device")
                view.pairingWith = ""
                BtAgent.shown = null
            }
        }
    }

    readonly property color hue: Theme.accent
    readonly property color lift: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)) // a button on a row
    readonly property color liftHover: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.18))

    component Label: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fg
    }
    component Caption: Text {
        leftPadding: 4
        topPadding: 4
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
    component Action: Rectangle {
        id: action
        property string label
        property bool primary: false
        property bool danger: false
        signal clicked
        width: actionText.implicitWidth + 20
        height: 28
        radius: 8
        color: primary ? view.hue : danger ? Edge.alertTint : actionHover.containsMouse ? view.liftHover : view.lift
        Text {
            id: actionText
            anchors.centerIn: parent
            text: action.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: action.primary ? Theme.bg : action.danger ? Theme.alert : Theme.fg
        }
        MouseArea {
            id: actionHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: action.clicked()
        }
    }

    // The agent's question, or the code to type on the device: a card in the accent.
    component Prompt: Rectangle {
        id: prompt
        readonly property var req: BtAgent.request
        visible: req !== null || BtAgent.shown !== null
        width: parent.width
        height: visible ? promptColumn.implicitHeight + 28 : 0
        radius: 12
        color: Qt.tint(Edge.fill, Qt.rgba(view.hue.r, view.hue.g, view.hue.b, 0.15))
        Column {
            id: promptColumn
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: {
                    const q = prompt.req
                    if (q === null)
                        return BtAgent.shown ? "Type this code on " + BtAgent.nameOf(BtAgent.shown.address) + ", then Enter" : ""
                    const name = BtAgent.nameOf(q.address)
                    return q.kind === "confirm" ? name + " wants to pair"
                        : q.kind === "authorize" ? "Pair with " + name + "?"
                        : q.kind === "passkey" ? "Type the code " + name + " shows"
                        : "PIN for " + name + " (often 0000)"
                }
            }
            Text {
                visible: prompt.req !== null && prompt.req.kind === "confirm"
                text: "Check this code matches the one on the device"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Text { // the code to check or to type
                readonly property string code: prompt.req !== null ? (prompt.req.kind === "confirm" ? prompt.req.code : "")
                    : BtAgent.shown ? BtAgent.shown.code : ""
                visible: code !== ""
                text: code.length === 6 ? code.slice(0, 3) + " " + code.slice(3) : code
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 26
                font.letterSpacing: 6
                color: view.hue
            }
            PanelInput {
                id: codeField
                visible: prompt.req !== null && (prompt.req.kind === "passkey" || prompt.req.kind === "pin")
                width: parent.width
                placeholder: "Code"
                onAccepted: { BtAgent.answer(text); text = "" }
                onVisibleChanged: if (visible) focusInput()
            }
            Row {
                visible: prompt.req !== null
                anchors.right: parent.right
                spacing: 6
                Action {
                    label: "Cancel"
                    onClicked: BtAgent.answer("no")
                }
                Action {
                    label: prompt.req && prompt.req.kind === "confirm" || prompt.req && prompt.req.kind === "authorize" ? "Pair" : "OK"
                    primary: true
                    onClicked: {
                        const k = prompt.req.kind
                        BtAgent.answer(k === "passkey" || k === "pin" ? codeField.text : "yes")
                        codeField.text = ""
                    }
                }
            }
        }
    }

    component Error: Text {
        visible: view.pairError !== ""
        width: parent.width
        leftPadding: 4
        wrapMode: Text.Wrap
        text: view.pairError
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.alert
    }

    // A paired device: its icon and name, the battery when reported, Connect or Disconnect, and
    // a › to its page. Connected: tinted with the accent.
    component Device: Rectangle {
        id: device
        required property var modelData
        readonly property var dev: modelData
        readonly property bool busy: dev.state === BluetoothDeviceState.Connecting
            || dev.state === BluetoothDeviceState.Disconnecting
        width: parent.width
        height: 44
        radius: 8
        color: dev.connected ? Qt.tint(Edge.fill, Qt.rgba(view.hue.r, view.hue.g, view.hue.b, 0.15)) : Edge.control
        IconImage {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 18
            source: Quickshell.iconPath(device.dev.icon || "bluetooth", "bluetooth")
        }
        Label {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: deviceEnd.x - x - 8
            elide: Text.ElideRight
            text: device.dev.name || device.dev.deviceName || device.dev.address
            color: device.dev.connected ? Theme.fg : Theme.fgMuted
        }
        Row {
            id: deviceEnd
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                visible: device.dev.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(device.dev.battery * 100) + "%"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Action {
                anchors.verticalCenter: parent.verticalCenter
                label: device.busy ? (device.dev.connected ? "Disconnecting" : "Connecting") : device.dev.connected ? "Disconnect" : "Connect"
                onClicked: if (!device.busy) device.dev.connected ? device.dev.disconnect() : device.dev.connect()
            }
            Rectangle { // the ›
                width: 28
                height: 36
                radius: 8
                color: moreHover.containsMouse ? view.lift : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: Icons.caretRight
                    font.family: Icons.regular
                    font.pixelSize: 14
                    color: Theme.fgMuted
                }
                MouseArea {
                    id: moreHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: view.push(devicePage, { dev: device.dev })
                }
            }
        }
    }

    ViewHeader {
        id: header
        title: "Bluetooth"
        onBack: view.back()
        PanelSwitch {
            on: view.on
            onToggled: view.adapter.enabled = !view.on
        }
    }

    Flickable {
        y: header.height + 8
        width: parent.width
        height: parent.height - y
        contentHeight: column.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            x: 16
            width: parent.width - 32
            spacing: 4

            Caption {
                visible: !view.on
                text: view.adapter === null ? "No Bluetooth adapter" : "Bluetooth is off"
            }
            Prompt {}
            Error {}

            Caption { visible: view.connected.length > 0; text: "Connected" }
            Repeater {
                model: view.connected
                Device {}
            }
            Caption { visible: view.idle.length > 0; text: "Paired" }
            Repeater {
                model: view.idle
                Device {}
            }

            Item { width: 1; height: 4 }
            Rectangle {
                visible: view.on
                width: parent.width
                height: 44
                radius: 8
                color: pairHover.containsMouse ? Edge.controlHover : Edge.control
                Row {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.plus
                        font.family: Icons.regular
                        font.pixelSize: 16
                        color: view.hue
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Pair a new device"
                    }
                }
                MouseArea {
                    id: pairHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: view.push(scanPage, {})
                }
            }
        }
    }

    // The scan page: discovering while it is shown.
    Component {
        id: scanPage
        Item {
            id: scan
            readonly property string viewName: "bluetooth"
            readonly property var nearby: view.on && view.adapter.discovering ? Bluetooth.devices.values
                .filter(d => !d.paired && (d.name || d.deviceName)).sort((a, b) => a.name.localeCompare(b.name)) : []
            Component.onCompleted: {
                view.pairError = ""
                if (view.on)
                    view.adapter.discovering = true
            }
            Component.onDestruction: if (view.adapter && view.adapter.discovering) view.adapter.discovering = false
            Connections {
                target: view
                function onPairingDone() { view.back() } // back to the list, where it shows as connected
            }

            ViewHeader {
                id: scanHeader
                title: "Pair a device"
                onBack: view.back()
            }
            Flickable {
                y: scanHeader.height + 8
                width: parent.width
                height: parent.height - y
                contentHeight: scanColumn.implicitHeight + 16
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: scanColumn
                    x: 16
                    width: parent.width - 32
                    spacing: 4
                    Prompt {}
                    Error {}
                    Caption {
                        text: scan.nearby.length === 0 ? "Looking… put the device in pairing mode" : "Nearby"
                    }
                    Repeater {
                        model: scan.nearby
                        Rectangle {
                            id: near
                            required property var modelData
                            readonly property bool pairing: view.pairingWith === modelData.address
                            width: scanColumn.width
                            height: 44
                            radius: 8
                            color: near.pairing ? Qt.tint(Edge.fill, Qt.rgba(view.hue.r, view.hue.g, view.hue.b, 0.15))
                                : nearHover.containsMouse ? Edge.controlHover : Edge.control
                            IconImage {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 18
                                source: Quickshell.iconPath(near.modelData.icon || "bluetooth", "bluetooth")
                            }
                            Label {
                                x: 40
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - nearTag.implicitWidth - 24
                                elide: Text.ElideRight
                                text: near.modelData.name || near.modelData.deviceName
                            }
                            Text {
                                id: nearTag
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: near.pairing ? "Pairing…" : "Pair"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: near.pairing ? view.hue : Theme.fgMuted
                            }
                            MouseArea {
                                id: nearHover
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: view.pairingWith === ""
                                onClicked: view.pair(near.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // A device's page: what it is, Connect or Disconnect, Forget.
    Component {
        id: devicePage
        Item {
            id: page
            required property var dev // null once forgotten, while the page slides out
            readonly property string viewName: "bluetooth"
            property bool armed: false
            Timer {
                id: armTimer
                interval: 3000
                onTriggered: page.armed = false
            }
            ViewHeader {
                id: pageHeader
                title: page.dev?.name || page.dev?.deviceName || page.dev?.address
                onBack: view.back()
            }
            Column {
                x: 16
                y: pageHeader.height + 8
                width: parent.width - 32
                spacing: 12
                Rectangle {
                    width: parent.width
                    height: 64
                    radius: 12
                    color: page.dev?.connected ? Qt.tint(Edge.fill, Qt.rgba(view.hue.r, view.hue.g, view.hue.b, 0.15)) : Edge.control
                    IconImage {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 28
                        source: Quickshell.iconPath(page.dev?.icon || "bluetooth", "bluetooth")
                    }
                    Column {
                        x: 56
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Label { text: page.dev?.connected ? "Connected" : "Paired, not connected" }
                        Text {
                            text: page.dev?.address + (page.dev?.batteryAvailable ? "  ·  " + Math.round(page.dev?.battery * 100) + "%" : "")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 6
                    Action {
                        label: page.armed ? "Again?" : "Forget"
                        danger: page.armed
                        onClicked: {
                            if (!page.armed) {
                                page.armed = true
                                armTimer.restart()
                            } else {
                                page.dev?.forget()
                                view.back()
                            }
                        }
                    }
                    Action {
                        label: page.dev?.connected ? "Disconnect" : "Connect"
                        primary: !page.dev?.connected
                        onClicked: page.dev?.connected ? page.dev?.disconnect() : page.dev?.connect()
                    }
                }
            }
        }
    }
}
