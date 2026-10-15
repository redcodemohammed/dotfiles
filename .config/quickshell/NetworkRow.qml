import QtQuick
import Quickshell.Networking

// One Wi-Fi network in the network panel (owner's design "Network manager"). Collapsed, 40 tall:
// signal bars, name, a lock when secured, and a tag (Connected, Saved, else the band). Clicked, it
// opens on the surface colour with a border: security, band, signal and bit rate; a password field
// for a new secured network (Enter connects); "Wrong password" (red) or "Connecting"; then Connect
// (accent), Disconnect and Forget. The password lives in the panel, so a re-sort keeps it.
Rectangle {
    id: row
    required property var modelData
    required property var panel
    readonly property var net: modelData
    readonly property bool expanded: panel.sel === net.name
    readonly property bool secured: net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Owe
    readonly property bool enterprise: [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192,
        WifiSecurityType.Leap, WifiSecurityType.DynamicWep].indexOf(net.security) >= 0
    readonly property bool needsPw: secured && !enterprise && !net.known && !net.connected
    readonly property bool connecting: (panel.attempt !== null && panel.attempt.name === net.name) || net.state === ConnectionState.Connecting
    readonly property bool failed: panel.err === net.name
    readonly property int level: Icons.wifiLevel(net.signalStrength)
    readonly property var scan: panel.info[net.name] ?? null

    function connect() {
        if (needsPw) {
            if (panel.pw.length < 8) {
                panel.err = net.name
                panel.errText = "At least 8 characters"
                return
            }
            panel.err = ""
            panel.attempt = { name: net.name, wasKnown: false }
            net.connectWithPsk(panel.pw)
        } else {
            panel.err = ""
            panel.attempt = { name: net.name, wasKnown: net.known }
            net.connect()
        }
    }

    onExpandedChanged: {
        pwField.text = panel.pw
        if (expanded && needsPw)
            pwField.focusInput()
    }
    Component.onCompleted: if (expanded) pwField.text = panel.pw

    Connections {
        target: row.net
        function onConnectedChanged() {
            if (!row.net.connected || row.panel.attempt === null || row.panel.attempt.name !== row.net.name)
                return
            row.panel.attempt = null
            row.panel.sel = "" // connected: close the row, as in the design
            row.panel.pw = ""
        }
        function onConnectionFailed(reason) {
            const a = row.panel.attempt
            if (a === null || a.name !== row.net.name)
                return
            row.panel.attempt = null
            row.panel.err = row.net.name
            row.panel.errText = reason === ConnectionFailReason.WifiNetworkLost ? "Network out of range"
                : row.secured ? "Wrong password" : "Couldn't connect"
            if (!a.wasKnown && row.net.known)
                row.net.forget() // drop the profile NetworkManager saved with the bad password
        }
    }

    height: body.height + 4
    color: expanded ? Theme.surface : "transparent"
    border.width: 2
    border.color: expanded ? Theme.border : "transparent"

    Column {
        id: body
        x: 2
        y: 2
        width: parent.width - 4

        Item { // the row itself
            width: parent.width
            height: 36

            Item { // signal bars, lit by level
                id: bars
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                Repeater {
                    model: [[1, 11, 3, 4], [5, 8, 3, 7], [9, 5, 3, 10], [13, 2, 2.5, 13]]
                    Rectangle {
                        required property var modelData
                        required property int index
                        x: modelData[0]
                        y: modelData[1]
                        width: modelData[2]
                        height: modelData[3]
                        color: row.level > index ? Theme.fg : Theme.border
                    }
                }
            }
            Text {
                x: bars.x + 16 + 8
                anchors.verticalCenter: parent.verticalCenter
                width: lockGlyph.x - x - 8
                text: row.net.name
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                id: lockGlyph
                x: tag.x - 8 - 16
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                visible: row.secured
                text: Icons.lock
                font.family: Icons.regular
                font.pixelSize: 16
                color: Theme.fgMuted
            }
            Text {
                id: tag
                x: parent.width - 8 - width
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(64, implicitWidth) // "Connected" is a little wider than the design's 64
                horizontalAlignment: Text.AlignRight
                text: row.net.connected ? "Connected" : row.net.known ? "Saved"
                    : row.scan ? row.panel.band(row.scan.freq).replace(" GHz", "G") : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
            MouseArea {
                anchors.fill: parent
                onClicked: row.panel.pick(row.net.name)
            }
        }

        Column { // opened
            visible: row.expanded
            x: 8
            width: parent.width - 16
            spacing: 8
            bottomPadding: 8

            Text {
                width: parent.width
                text: [row.panel.securityLabel(row.net), row.scan ? row.panel.band(row.scan.freq) : "",
                    Math.round(row.net.signalStrength * 100) + "%", row.scan ? row.scan.rate : ""]
                    .filter(s => s !== "").join(" · ")
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Text {
                visible: row.enterprise && !row.net.known
                width: parent.width
                text: "Needs an enterprise sign-in: set it up with nmtui"
                wrapMode: Text.Wrap
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            PanelInput {
                id: pwField
                visible: row.needsPw
                width: parent.width
                password: true
                placeholder: "Password"
                error: row.failed
                onEdited: {
                    row.panel.pw = text
                    row.panel.err = ""
                }
                onAccepted: row.connect()
            }

            Row {
                visible: row.failed
                spacing: 8
                Text {
                    text: Icons.warningCircle
                    font.family: Icons.regular
                    font.pixelSize: 16
                    color: Theme.alert
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.panel.errText
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fg
                }
            }

            Item {
                visible: row.connecting
                width: parent.width
                height: 16
                Text {
                    id: connectingText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connecting"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fgMuted
                }
                Rectangle {
                    x: connectingText.width + 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    height: 4
                    color: Theme.border
                    Rectangle {
                        width: parent.width * 0.6
                        height: 4
                        color: Theme.fg
                    }
                }
            }

            Row {
                id: actions
                visible: !row.connecting
                width: parent.width
                spacing: 4
                readonly property var shown: [!row.net.connected && !(row.enterprise && !row.net.known),
                    row.net.connected, row.net.known]
                readonly property int count: shown.filter(s => s).length
                readonly property real buttonWidth: (width - (count - 1) * 4) / Math.max(count, 1)

                PanelButton {
                    visible: actions.shown[0]
                    width: actions.buttonWidth
                    primary: true
                    label: "Connect"
                    onPressed: row.connect()
                }
                PanelButton {
                    visible: actions.shown[1]
                    width: actions.buttonWidth
                    label: "Disconnect"
                    onPressed: {
                        row.net.disconnect()
                        row.panel.sel = ""
                    }
                }
                PanelButton {
                    visible: actions.shown[2]
                    width: actions.buttonWidth
                    muted: true
                    label: "Forget"
                    onPressed: {
                        row.net.forget()
                        row.panel.sel = ""
                    }
                }
            }
        }
    }
}
