import QtQuick
import Quickshell.Io
import Quickshell.Networking

// The network panel's Settings tab (owner's design "Network manager"). For the Wi-Fi network in
// use: its details (signal, band and rate, security, IP address, gateway, DNS), Auto-connect and
// Metered (that network's profile), the DNS choice Auto / 1.1.1.1 / 8.8.8.8 (with their IPv6
// twins; the router's DNS is then ignored), and Forget this network. For the machine: Airplane
// mode (all radios, rfkill) and the wired devices. Profiles are read and changed with nmcli; a
// change is re-applied to the live connection (nmcli device reapply), no reconnect.
Column {
    id: root
    required property var panel
    readonly property var net: panel.wifi ? (panel.wifi.networks.values.find(n => n.connected) ?? null) : null
    readonly property string device: panel.wifi ? panel.wifi.name : ""
    readonly property var wired: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var scan: net ? (panel.info[net.name] ?? null) : null
    readonly property bool live: panel.visible && panel.tab === "settings"

    // From nmcli, for the connection in use
    property string uuid: ""
    property string ip: ""
    property string gateway: ""
    property string dns: ""
    property bool autoconnect: false
    property bool metered: false
    property bool ipv6: true
    property int dnsChoice: 0 // index in dnsOptions, -1 for servers set some other way
    readonly property var dnsOptions: [
        { label: "Auto", v4: "", v6: "" },
        { label: "1.1.1.1", v4: "1.1.1.1 1.0.0.1", v6: "2606:4700:4700::1111 2606:4700:4700::1001" },
        { label: "8.8.8.8", v4: "8.8.8.8 8.8.4.4", v6: "2001:4860:4860::8888 2001:4860:4860::8844" },
    ]

    onLiveChanged: if (live) refresh()
    onNetChanged: if (live) refresh()

    function refresh() {
        if (device === "" || reader.running)
            return
        reader.command = ["sh", "-c", '
            nmcli -t -f GENERAL.CON-UUID,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$1"
            uuid=$(nmcli -g GENERAL.CON-UUID device show "$1")
            [ -n "$uuid" ] && nmcli -t -f connection.autoconnect,connection.metered,ipv4.dns,ipv4.ignore-auto-dns,ipv6.method connection show uuid "$uuid"',
            "sh", device]
        reader.running = true
    }
    // nmcli connection modify on the connection in use, then reapply it to the device.
    function modify(args, reapply) {
        if (uuid === "" || writer.running)
            return
        writer.command = ["sh", "-c", '
            u=$1; d=$2; r=$3; shift 3
            nmcli connection modify uuid "$u" "$@" && [ "$r" = 1 ] && nmcli device reapply "$d" >/dev/null
            true', "sh", uuid, device, reapply ? "1" : "0"].concat(args)
        writer.running = true
    }
    function setDns(i) {
        const o = dnsOptions[i]
        const ignore = i === 0 ? "no" : "yes"
        const args = ["ipv4.dns", o.v4, "ipv4.ignore-auto-dns", ignore]
        if (ipv6)
            args.push("ipv6.dns", o.v6, "ipv6.ignore-auto-dns", ignore)
        dnsChoice = i
        modify(args, true)
    }

    Process {
        id: reader
        stdout: StdioCollector {
            id: readOut
            onStreamFinished: {
                const v = {}
                const ips = []
                const dns = []
                for (const line of readOut.text.split("\n")) {
                    const f = root.panel.fields(line)
                    if (f.length < 2)
                        continue
                    const key = f[0].replace(/\[\d+\]$/, "")
                    const val = f.slice(1).join(":")
                    if (key === "IP4.ADDRESS")
                        ips.push(val.replace(/\/\d+$/, ""))
                    else if (key === "IP4.DNS")
                        dns.push(val)
                    else
                        v[key] = val
                }
                root.uuid = v["GENERAL.CON-UUID"] ?? ""
                root.ip = ips.join(", ")
                root.gateway = v["IP4.GATEWAY"] ?? ""
                root.dns = dns.join(", ")
                root.autoconnect = v["connection.autoconnect"] === "yes"
                root.metered = v["connection.metered"] === "yes"
                root.ipv6 = ["disabled", "ignore"].indexOf(v["ipv6.method"]) < 0
                const manual = (v["ipv4.dns"] ?? "").split(",").filter(s => s !== "").join(" ")
                root.dnsChoice = v["ipv4.ignore-auto-dns"] !== "yes" && manual === "" ? 0
                    : root.dnsOptions.findIndex((o, i) => i > 0 && o.v4 === manual)
            }
        }
    }
    Process {
        id: writer
        onExited: root.refresh()
    }

    spacing: 8

    Column { // the connection in use
        width: parent.width
        spacing: 4
        Text {
            text: "Connection"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
        Rectangle {
            width: parent.width
            height: card.implicitHeight + 28
            color: "transparent"
            border.width: 2
            border.color: Theme.border
            Column {
                id: card
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 4
                Text {
                    width: parent.width
                    text: root.net ? root.net.name : "No network"
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
                Repeater {
                    model: root.net ? [
                        ["Signal", Math.round(root.net.signalStrength * 100) + "%"],
                        ["Band", root.scan ? root.panel.band(root.scan.freq) + " · " + root.scan.rate : "…"],
                        ["Security", root.panel.securityLabel(root.net)],
                        ["IP address", root.ip || "…"],
                        ["Gateway", root.gateway || "…"],
                        ["DNS", root.dns || "…"],
                    ] : [["Status", "Not connected"]]
                    Row {
                        required property var modelData
                        width: card.width
                        spacing: 8
                        Text {
                            width: 96
                            text: parent.modelData[0]
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }
                        Text {
                            width: parent.width - 104
                            text: parent.modelData[1]
                            elide: Text.ElideRight
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fg
                        }
                    }
                }
            }
        }
    }

    Repeater { // switches: the network's profile, then the machine
        model: [
            { label: "Auto-connect", key: "auto" },
            { label: "Metered connection", key: "metered" },
            { label: "Airplane mode", key: "airplane" },
        ]
        Item {
            id: switchRow
            required property var modelData
            readonly property bool forNetwork: modelData.key !== "airplane"
            width: root.width
            height: 40
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: switchRow.modelData.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            PanelSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                available: !switchRow.forNetwork || root.uuid !== ""
                on: switchRow.modelData.key === "auto" ? root.autoconnect
                    : switchRow.modelData.key === "metered" ? root.metered
                    : root.panel.airplane
                onToggled: {
                    if (switchRow.modelData.key === "auto") {
                        root.autoconnect = !root.autoconnect
                        root.modify(["connection.autoconnect", root.autoconnect ? "yes" : "no"], false)
                    } else if (switchRow.modelData.key === "metered") {
                        root.metered = !root.metered
                        root.modify(["connection.metered", root.metered ? "yes" : "no"], true)
                    } else {
                        root.panel.setAirplane(!root.panel.airplane)
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 4
        Text {
            text: "DNS"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
        Row {
            width: parent.width
            spacing: 4
            Repeater {
                model: root.dnsOptions
                Rectangle {
                    id: dnsButton
                    required property var modelData
                    required property int index
                    readonly property bool on: root.dnsChoice === index
                    width: (parent.width - 8) / 3
                    height: 40
                    color: area.containsMouse && root.uuid !== "" ? Theme.surface : Theme.bg
                    border.width: 2
                    border.color: on ? Theme.accent : Theme.border
                    opacity: root.uuid !== "" ? 1 : 0.5
                    Text {
                        anchors.centerIn: parent
                        text: dnsButton.modelData.label
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: dnsButton.on ? Theme.fg : Theme.fgMuted
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.uuid !== ""
                        onClicked: root.setDns(dnsButton.index)
                    }
                }
            }
        }
    }

    PanelButton {
        visible: root.net !== null && root.net.known
        width: parent.width
        danger: true
        label: "Forget this network"
        onPressed: root.net.forget()
    }

    Rectangle {
        width: parent.width
        height: 2
        color: Theme.border
    }

    Repeater { // wired devices
        model: root.wired
        Item {
            id: wiredRow
            required property var modelData
            width: root.width
            height: 24
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - wiredState.width - 8
                text: "Ethernet · " + wiredRow.modelData.name
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Text {
                id: wiredState
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: wiredRow.modelData.connected ? "Connected"
                    : wiredRow.modelData.hasLink ? "Not connected" : "No cable"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fg
            }
        }
    }
}
