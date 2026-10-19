import QtQuick
import Quickshell
import Quickshell.Io

// One saved connection's own settings (owner, 2026-10-17: they belong with the network, not in
// Settings): Auto-connect, Metered, DNS Auto / 1.1.1.1 / 8.8.8.8 (with their IPv6 twins; the
// router's DNS is then ignored) and, for Wi-Fi, Share network (QR). Shown in a saved Wi-Fi
// network's open row (NetworkRow.qml) and under an Ethernet card (NetworkConnCard.qml).
// The profile: `uuid` when given (Ethernet: the device's), else found by `ssid` (NetworkManager
// names a Wi-Fi profile after its SSID). Read and changed with nmcli; a change to the profile in
// use is re-applied to `device` (nmcli device reapply), no reconnect. Read when it shows.
Column {
    id: root
    property string uuid: ""      // the profile; empty: look it up by ssid
    property string ssid: ""      // Wi-Fi: the network's name (and the QR's)
    property string device: ""    // where it would be active
    property bool shareable: false // Wi-Fi with a security the QR format knows
    property bool active: false   // in use on `device` now: changes are re-applied
    property bool showSwitches: true // Auto-connect, Metered
    property bool showDns: true      // the DNS choice (a Wi-Fi network's is on its Settings card)
    readonly property string profile: uuid !== "" ? uuid : found
    property string found: ""

    property bool autoconnect: false
    property bool metered: false
    property bool ipv6: true
    property int dnsChoice: 0 // index in dnsOptions, -1 for servers set some other way
    readonly property var dnsOptions: [
        { label: "Auto", v4: "", v6: "" },
        { label: "1.1.1.1", v4: "1.1.1.1 1.0.0.1", v6: "2606:4700:4700::1111 2606:4700:4700::1001" },
        { label: "8.8.8.8", v4: "8.8.8.8 8.8.4.4", v6: "2001:4860:4860::8888 2001:4860:4860::8844" },
    ]

    spacing: 4
    width: parent.width
    onVisibleChanged: visible ? refresh() : hideQr()
    Component.onCompleted: if (visible) refresh()
    onUuidChanged: if (visible) refresh()
    onSsidChanged: if (visible) refresh()

    function refresh() {
        if (reader.running || (uuid === "" && ssid === ""))
            return
        reader.command = ["sh", "-c", '
            u=$1
            [ -n "$u" ] || u=$(nmcli -g connection.uuid connection show id "$2" 2>/dev/null | head -n 1)
            [ -n "$u" ] || exit 0
            echo "UUID:$u"
            nmcli -t -f connection.autoconnect,connection.metered,ipv4.dns,ipv4.ignore-auto-dns,ipv6.method connection show uuid "$u"',
            "sh", uuid, ssid]
        reader.running = true
    }
    function modify(args) {
        if (profile === "" || writer.running)
            return
        writer.command = ["sh", "-c", '
            u=$1; d=$2; r=$3; shift 3
            nmcli connection modify uuid "$u" "$@" && [ "$r" = 1 ] && nmcli device reapply "$d" >/dev/null
            true', "sh", profile, device, active ? "1" : "0"].concat(args)
        writer.running = true
    }
    function setDns(i) {
        const o = dnsOptions[i]
        const ignore = i === 0 ? "no" : "yes"
        const args = ["ipv4.dns", o.v4, "ipv4.ignore-auto-dns", ignore]
        if (ipv6)
            args.push("ipv6.dns", o.v6, "ipv6.ignore-auto-dns", ignore)
        dnsChoice = i
        modify(args)
    }
    function field(line) { // nmcli -t: key:value, value may hold escaped colons
        const i = line.indexOf(":")
        return i < 0 ? null : [line.slice(0, i), line.slice(i + 1).replace(/\\:/g, ":")]
    }

    Process {
        id: reader
        stdout: StdioCollector {
            id: readOut
            onStreamFinished: {
                const v = {}
                for (const line of readOut.text.split("\n")) {
                    const f = root.field(line)
                    if (f)
                        v[f[0]] = f[1]
                }
                if (root.uuid === "")
                    root.found = v["UUID"] ?? ""
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

    // Share network (QR): ~/.local/bin/wifi-qr writes it to $XDG_RUNTIME_DIR, removed when hidden.
    readonly property string qrPath: Quickshell.env("XDG_RUNTIME_DIR") + "/network-qr.svg"
    property bool qrOpen: false
    property string qrSource: ""
    function showQr() {
        qrOpen = true
        qrMaker.command = [Quickshell.env("HOME") + "/.local/bin/wifi-qr", profile, ssid, qrPath,
            String(Theme.bg).slice(1), String(Theme.fg).slice(1)]
        qrMaker.running = true
    }
    function hideQr() {
        if (!qrOpen && qrSource === "")
            return
        qrOpen = false
        qrSource = ""
        Quickshell.execDetached(["rm", "-f", qrPath])
    }
    Process {
        id: qrMaker
        onExited: code => {
            if (code === 0 && root.qrOpen)
                root.qrSource = "file://" + root.qrPath
        }
    }

    // ---- the settings (only for a saved profile)
    PanelSwitchRow {
        visible: root.showSwitches && root.profile !== ""
        label: "Auto-connect"
        on: root.autoconnect
        onToggled: {
            root.autoconnect = !root.autoconnect
            root.modify(["connection.autoconnect", root.autoconnect ? "yes" : "no"])
        }
    }
    PanelSwitchRow {
        visible: root.showSwitches && root.profile !== ""
        label: "Metered connection"
        on: root.metered
        onToggled: {
            root.metered = !root.metered
            root.modify(["connection.metered", root.metered ? "yes" : "no"])
        }
    }
    Text {
        visible: root.showDns && root.profile !== ""
        text: "DNS"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fg
    }
    Row {
        visible: root.showDns && root.profile !== ""
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
                height: 32
                radius: 8
                color: on ? Edge.accentTint : area.containsMouse ? Edge.controlHover : Edge.control
                Text {
                    anchors.centerIn: parent
                    text: dnsButton.modelData.label
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: dnsButton.on ? Theme.fg : Theme.fgMuted
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.setDns(dnsButton.index)
                }
            }
        }
    }
    Item { width: 1; height: 4; visible: root.shareable && root.profile !== "" }
    PanelButton {
        visible: root.shareable && root.profile !== ""
        width: parent.width
        icon: Icons.qrCode
        label: root.qrOpen ? "Hide QR code" : "Share network (QR)"
        onPressed: root.qrOpen ? root.hideQr() : root.showQr()
    }
    Rectangle {
        visible: root.qrOpen
        width: parent.width
        height: qrColumn.implicitHeight + 28
        radius: 12 // a card
        color: Edge.control
        Column {
            id: qrColumn
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            spacing: 8
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 176
                height: 176
                sourceSize: Qt.size(176, 176)
                source: root.qrSource
                cache: false
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Scan to join " + root.ssid
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
    }
}
