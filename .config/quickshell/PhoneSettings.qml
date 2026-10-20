import QtQuick

// The phone panel's Settings tab (owner's design "Phone bridge", 2026-10-15). Sharing: Mirror
// notifications, Reply from desktop (the panel's own), Sync clipboard, File sharing (kcd's share
// plugin does both directions, so the design's "Receive files" covers sending too), Battery alerts,
// and Remote input (the phone as mouse and keyboard; added). Mirror notifications from: a switch per
// app that has sent one. Connection: how the phone is reached. Unpair this phone, pressed twice.
// Changes reach kcd through Phone.setSetting (kcd-settings, kcd restarts). Since the "Remaining
// panels" design (2026-10-20) a view of its own (the phone panel's gear), each group on a card.
Column {
    id: root
    required property var panel
    property bool confirmUnpair: false
    spacing: 6

    Text {
        height: 16
        leftPadding: 4
        text: "Sharing" + (Phone.applying ? " · applying" : "")
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
    Rectangle {
    width: root.width
    height: sharing.implicitHeight + 8
    radius: 12
    color: Edge.control
    Column {
    id: sharing
    x: 12
    y: 4
    width: parent.width - 24
    Repeater {
        model: [
            { key: "notification", label: "Mirror notifications" },
            { key: "replyFromDesktop", label: "Reply from desktop" },
            { key: "clipboard", label: "Sync clipboard" },
            { key: "share", label: "File sharing" },
            { key: "batteryAlerts", label: "Battery alerts" },
            { key: "mousepad", label: "Remote input (mouse, keyboard)" },
        ]
        Item {
            id: row
            required property var modelData
            width: sharing.width
            height: 40
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            PanelSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                on: Phone.settings[row.modelData.key] !== false
                onToggled: Phone.setSetting(row.modelData.key, !on)
            }
        }
    }
    }
    }

    Item { width: 1; height: 8 }
    Text {
        height: 16
        leftPadding: 4
        text: "Mirror notifications from"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
    Text {
        visible: Phone.settings.knownApps.length === 0
        width: parent.width
        leftPadding: 4
        text: "Apps show here after their first notification"
        wrapMode: Text.Wrap
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgDim
    }
    Rectangle {
    visible: Phone.settings.knownApps.length > 0
    width: root.width
    height: apps.implicitHeight + 8
    radius: 12
    color: Edge.control
    Column {
    id: apps
    x: 12
    y: 4
    width: parent.width - 24
    Repeater {
        model: Phone.settings.knownApps.slice().sort((a, b) => a.localeCompare(b))
        Item {
            id: app
            required property var modelData
            width: apps.width
            height: 40
            opacity: Phone.settings.notification !== false ? 1 : 0.5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48
                text: app.modelData
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            PanelSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                available: Phone.settings.notification !== false
                on: Phone.settings.mutedApps.indexOf(app.modelData) < 0
                onToggled: Phone.toggleApp(app.modelData)
            }
        }
    }
    }
    }

    Item { width: 1; height: 8 }
    Item {
        width: parent.width
        height: 24
        Text {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            text: "Connection"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: !Phone.connected ? "Not connected" : NetState.wifiNet ? "Wi-Fi · " + NetState.wifiNet.name : "Local network"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fg
        }
    }
    PanelButton {
        width: parent.width
        danger: true
        label: root.confirmUnpair ? "Press again to unpair" : "Unpair this phone"
        onPressed: {
            if (!root.confirmUnpair) {
                root.confirmUnpair = true
                unpairReset.restart()
                return
            }
            root.confirmUnpair = false
            Phone.unpair()
            root.panel.visible = false
        }
    }
    Timer {
        id: unpairReset
        interval: 3000
        onTriggered: root.confirmUnpair = false
    }
}
