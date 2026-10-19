import QtQuick
import Quickshell
import Quickshell.Io

// The network panel's VPN tab (owner's design "Network manager"; the kill switch is left out, the
// owner's choice). NetworkManager's VPN profiles, WireGuard and the VPN plugins (OpenVPN, Fortinet,
// strongSwan), read with nmcli when the tab shows: a row each with a shield (filled while on), the
// name and the protocol or Connected. Open: protocol, server and a ping to it, then Connect (accent,
// dimmed without a network; one VPN at a time) or Disconnect. Import profile: a file picker
// (zenity) for a WireGuard .conf or an OpenVPN .ovpn/.conf, imported with nmcli and set not to start
// on its own; a notification says how it went. Connect on open Wi-Fi: NetState brings up the last
// VPN used when an open network connects. Connecting and the active VPN live in NetState.
// swanctl connections (NetState.swanConns, strongSwan's own daemon) join the list, tagged
// "swanctl"; a muted line says when that daemon is down or not reachable yet.
Column {
    id: root
    required property var panel
    readonly property bool live: panel.visible && panel.tab === "vpn"
    property var profiles: [] // NetworkManager's: { uuid, name, proto, tag, server }
    readonly property var all: profiles.concat(NetState.swanConns.map(c => ({
        uuid: "swan:" + c.name, name: c.name, proto: "IPsec (swanctl)", tag: "swanctl", server: c.remote
    }))).sort((a, b) => a.name.localeCompare(b.name))
    property bool loaded: false
    property string sel: "" // the open row
    property string latency: "" // ping to the open row's server

    onLiveChanged: {
        if (live)
            load()
        else
            sel = ""
    }
    onSelChanged: {
        latency = ""
        ping()
    }

    function load() {
        if (!loader.running)
            loader.running = true
        NetState.refreshSwan()
    }
    // One line per VPN: uuid, type, name (nmcli -t escaped), then the details holding the server.
    Process {
        id: loader
        command: ["sh", "-c", '
            nmcli -t -f UUID,TYPE,NAME connection show | while IFS= read -r line; do
                uuid=${line%%:*}; rest=${line#*:}; type=${rest%%:*}; name=${rest#*:}
                case $type in
                    wireguard) detail=$(nmcli -g wireguard.peers connection show uuid "$uuid") ;;
                    vpn) detail="$(nmcli -g vpn.service-type connection show uuid "$uuid") $(nmcli -g vpn.data connection show uuid "$uuid")" ;;
                    *) continue ;;
                esac
                printf "%s\t%s\t%s\t%s\n" "$uuid" "$type" "$name" "$detail"
            done']
        stdout: StdioCollector {
            id: loadOut
            onStreamFinished: {
                const list = []
                for (const line of loadOut.text.split("\n")) {
                    const f = line.split("\t")
                    if (f.length < 4)
                        continue
                    const detail = NetState.unescaped(f[3])
                    const proto = f[1] === "wireguard" ? "WireGuard"
                        : detail.indexOf("openvpn") >= 0 ? "OpenVPN"
                        : detail.indexOf("fortisslvpn") >= 0 ? "Fortinet"
                        : detail.indexOf("strongswan") >= 0 ? "IPsec"
                        : "VPN"
                    const m = detail.match(/endpoint=([^\s;]+)/) || detail.match(/(?:remote|gateway|address) = ([^,\s]+)/)
                    list.push({ uuid: f[0], name: NetState.unescaped(f[2]), proto: proto, tag: proto, server: m ? m[1] : "" })
                }
                root.profiles = list
                root.loaded = true
            }
        }
    }

    function host(server) { // "host:port", "[v6]:port" or "host"
        const v6 = server.match(/^\[(.+)\]/)
        if (v6)
            return v6[1]
        const parts = server.split(":")
        return parts.length === 2 ? parts[0] : server
    }
    function ping() {
        const p = all.find(p => p.uuid === sel)
        if (!p || p.server === "" || pinger.running)
            return
        pinger.command = ["ping", "-c", "1", "-W", "2", "-n", host(p.server)]
        pinger.running = true
    }
    Process {
        id: pinger
        stdout: StdioCollector {
            id: pingOut
            onStreamFinished: {
                const m = pingOut.text.match(/time=([0-9.]+)/)
                root.latency = m ? Math.round(Number(m[1])) + " ms" : "no reply"
            }
        }
    }

    function importProfile() {
        panel.visible = false // the file picker needs the keyboard
        Quickshell.execDetached(["sh", "-c", '
            f=$(zenity --file-selection --title="Import VPN profile" --file-filter="VPN profiles | *.conf *.ovpn" --file-filter="All files | *") || exit 0
            if grep -qF "[Interface]" "$f"; then type=wireguard; else type=openvpn; fi
            if out=$(nmcli connection import type "$type" file "$f" 2>&1); then
                uuid=${out##*(}; uuid=${uuid%%)*}
                nmcli connection modify uuid "$uuid" connection.autoconnect no
                nmcli connection down uuid "$uuid" >/dev/null 2>&1
                notify-send -a Network "VPN profile imported" "$(basename "$f")"
            else
                notify-send -a Network -u critical "VPN import failed" "$(printf "%s" "$out" | tail -n 1)"
            fi'])
    }

    spacing: 8

    Text {
        text: NetState.vpnOn ? "Connected · " + NetState.vpnName
            : NetState.vpnState === "activating" ? "Connecting · " + NetState.vpnName
            : "VPN off"
        width: parent.width
        elide: Text.ElideRight
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }

    Row {
        visible: !NetState.linkUp
        spacing: 8
        Text {
            text: Icons.warningCircle
            font.family: Icons.regular
            font.pixelSize: 16
            color: Theme.alert
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "No network. VPN needs a connection."
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
    }

    Text {
        visible: root.loaded && root.all.length === 0
        width: parent.width
        text: "No VPN profiles yet"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fgMuted
    }

    Column {
        width: parent.width
        spacing: 4
        Repeater {
            model: root.all
            Rectangle {
                id: vpnRow
                required property var modelData
                readonly property bool expanded: root.sel === modelData.uuid
                readonly property bool active: NetState.vpnUuid === modelData.uuid
                readonly property bool on: active && NetState.vpnOn
                readonly property bool busy: NetState.vpnBusy === modelData.uuid || (active && NetState.vpnState === "activating")
                readonly property bool failed: NetState.vpnFailed === modelData.uuid
                width: root.width
                height: vpnBody.height + 4
                radius: 8
                color: expanded ? Edge.control : "transparent"

                Column {
                    id: vpnBody
                    x: 2
                    y: 2
                    width: parent.width - 4

                    Item { // the row
                        width: parent.width
                        height: 36
                        Text {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.shield
                            font.family: vpnRow.on ? Icons.fill : Icons.regular
                            font.pixelSize: 16
                            color: Theme.fg
                        }
                        Text {
                            x: 32
                            anchors.verticalCenter: parent.verticalCenter
                            width: vpnTag.x - x - 8
                            text: vpnRow.modelData.name
                            elide: Text.ElideRight
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: Theme.fg
                        }
                        Text {
                            id: vpnTag
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: vpnRow.on ? "Connected" : vpnRow.modelData.tag
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: Theme.fgMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.sel = vpnRow.expanded ? "" : vpnRow.modelData.uuid
                        }
                    }

                    Column { // opened
                        visible: vpnRow.expanded
                        x: 8
                        width: parent.width - 16
                        spacing: 8
                        bottomPadding: 8

                        Text {
                            width: parent.width
                            text: [vpnRow.modelData.proto, vpnRow.modelData.server, root.latency].filter(s => s !== "").join(" · ")
                            elide: Text.ElideRight
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }

                        Item {
                            visible: vpnRow.busy
                            width: parent.width
                            height: 16
                            Text {
                                id: vpnConnecting
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Connecting"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.fgMuted
                            }
                            Rectangle {
                                x: vpnConnecting.width + 8
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
                            visible: vpnRow.failed && !vpnRow.busy
                            width: parent.width
                            spacing: 8
                            Text {
                                id: vpnWarn
                                text: Icons.warningCircle
                                font.family: Icons.regular
                                font.pixelSize: 16
                                color: Theme.alert
                            }
                            Text {
                                width: parent.width - vpnWarn.width - 8
                                text: NetState.vpnFailText
                                wrapMode: Text.Wrap
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.fg
                            }
                        }

                        PanelButton {
                            visible: !vpnRow.on && !vpnRow.busy
                            width: parent.width
                            primary: true
                            label: "Connect"
                            available: NetState.linkUp
                            onPressed: NetState.vpnUp(vpnRow.modelData.uuid)
                        }
                        PanelButton {
                            visible: vpnRow.on
                            width: parent.width
                            label: "Disconnect"
                            onPressed: NetState.vpnDown(vpnRow.modelData.uuid)
                        }
                    }
                }
            }
        }
    }

    Text { // swanctl's daemon
        visible: NetState.swanStatus !== ""
        width: parent.width
        text: NetState.swanStatus === "denied" ? "strongSwan: no access yet (log in again for the vpn group)"
            : "strongSwan isn't running (swanctl connections show when it is)"
        wrapMode: Text.Wrap
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }

    PanelButton {
        width: parent.width
        icon: Icons.plus
        label: "Import profile (.conf)"
        onPressed: root.importProfile()
    }

    Rectangle {
        width: parent.width
        height: 2
        color: Theme.border
    }

    Item {
        width: parent.width
        height: 40
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Connect on open Wi-Fi"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        PanelSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: NetState.vpnAuto
            onToggled: NetState.setVpnAuto(!NetState.vpnAuto)
        }
    }
    Text { // which VPN that brings up
        visible: NetState.vpnAuto
        width: parent.width
        text: {
            const last = root.all.find(p => p.uuid === NetState.vpnLast)
            return last ? "Brings up " + last.name + ", the last VPN used" : "Connect a VPN once to choose which"
        }
        wrapMode: Text.Wrap
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
}
