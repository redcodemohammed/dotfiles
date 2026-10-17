import QtQuick
import Quickshell.Io

// One active connection's card in the network panel's Settings tab (owner, 2026-10-17: Ethernet
// too, not only Wi-Fi). Title (network name or "Ethernet · <device>", its kind), then rows:
// Wi-Fi: Signal, Band, Security; Ethernet: Speed (/sys/class/net/<dev>/speed: nmcli says
// "unknown" for USB adapters), MAC; both: Internet, IP address, Gateway, DNS. Under them the
// connection's settings (NetworkProfile.qml): Auto-connect, Metered and DNS, for both (owner: the
// only place for them; a Wi-Fi row keeps Connect, Forget and Share). Read with nmcli for
// its device whenever the tab shows. A click on a row copies its value (`settings.copy`).
Rectangle {
    id: card
    required property var conn      // { kind: "wifi" | "wired", device, title }
    required property var settings  // NetworkSettings: panel, net, scan, internetText, copy, copied
    readonly property bool wifi: conn.kind === "wifi"
    property string ip: ""
    property string gateway: ""
    property string dns: ""
    property string mac: ""
    property string speed: ""
    property string uuid: ""

    function refresh() {
        if (!reader.running)
            reader.running = true
    }
    Component.onCompleted: refresh()
    onConnChanged: refresh()
    Connections {
        target: card.settings
        function onLiveChanged() { if (card.settings.live) card.refresh() }
    }

    Process {
        id: reader
        command: ["sh", "-c", '
            nmcli -t -f GENERAL.CON-UUID,GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$1"
            s=$(cat /sys/class/net/"$1"/speed 2>/dev/null); [ "${s:--1}" -gt 0 ] 2>/dev/null && echo "SPEED:$s"',
            "sh", card.conn.device]
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                const ips = [], dns = [], v = {}
                for (const line of out.text.split("\n")) {
                    const f = card.settings.panel.fields(line)
                    if (f.length < 2)
                        continue
                    const key = f[0].replace(/\[\d+\]$/, "")
                    const val = f.slice(1).join(":")
                    if (key === "IP4.ADDRESS") ips.push(val.replace(/\/\d+$/, ""))
                    else if (key === "IP4.DNS") dns.push(val)
                    else v[key] = val
                }
                card.ip = ips.join(", ")
                card.gateway = v["IP4.GATEWAY"] ?? ""
                card.dns = dns.join(", ")
                card.mac = v["GENERAL.HWADDR"] ?? ""
                card.uuid = v["GENERAL.CON-UUID"] ?? ""
                const s = Number(v["SPEED"] ?? 0)
                card.speed = s >= 1000 ? (s / 1000) + " Gb/s" : s > 0 ? s + " Mb/s" : "Unknown"
            }
        }
    }

    readonly property var rows: {
        const s = settings
        const common = [
            ["Internet", s.internetText],
            ["IP address", ip || "…"],
            ["Gateway", gateway || "…"],
            ["DNS", dns || "…"],
        ]
        if (wifi && s.net)
            return [
                ["Signal", Math.round(s.net.signalStrength * 100) + "%"],
                ["Band", s.scan ? s.panel.band(s.scan.freq) + " · " + s.scan.rate : "…"],
                ["Security", s.panel.securityLabel(s.net)],
            ].concat(common)
        return [["Speed", speed || "…"]].concat(common, [["MAC address", mac || "…"]])
    }

    width: parent.width
    height: body.implicitHeight + 28
    color: "transparent"
    border.width: 2
    border.color: Theme.border

    Column {
        id: body
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 4
        Item {
            width: parent.width
            height: 20
            Text {
                width: parent.width - kind.implicitWidth - 8
                text: card.conn.title
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fg
            }
            Text {
                id: kind
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: card.wifi ? "Wi-Fi" : "Ethernet"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
        Repeater {
            model: card.rows
            Item { // click copies the value
                id: infoRow
                required property var modelData
                width: body.width
                height: 16
                Text {
                    width: 96
                    text: infoRow.modelData[0]
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                Text {
                    x: 104
                    width: copiedHint.x - x - 8
                    text: infoRow.modelData[1]
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fg
                }
                Text {
                    id: copiedHint
                    anchors.right: parent.right
                    text: card.settings.copied === card.conn.device + infoRow.modelData[0] ? "Copied" : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: infoRow.modelData[1] !== "…"
                    onClicked: card.settings.copy(card.conn.device + infoRow.modelData[0], infoRow.modelData[1])
                }
            }
        }
        NetworkProfile { // the connection's own settings: Auto-connect, Metered, DNS (owner:
            visible: card.uuid !== ""  // the same for Wi-Fi and Ethernet)
            topPadding: 8
            uuid: card.uuid
            device: card.conn.device
            active: true
        }
    }
}
