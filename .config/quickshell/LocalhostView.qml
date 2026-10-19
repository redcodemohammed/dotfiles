import QtQuick
import Quickshell

// The tools panel's Localhost view (owner, 2026-10-20, the "Dev tools panel" design): opened by
// the Localhost row or `qs ipc call tools qr <port>`. Your dev servers' ports (dev-ports: known
// runtimes only), look again in the header. A server bound to the LAN opens to a QR of
// http://<LAN address>:<port> (lan-qr) with its link and Copy, for the phone; one bound to
// localhost only says how to start it so the phone can reach it. With one LAN server it opens
// by itself. Scrolls inside the panel's fixed height.
Item {
    id: view
    readonly property string viewName: "localhost"
    signal back
    property int openPort: 0 // the server shown with its QR (0: none)

    function show(port) {
        openPort = openPort === port ? 0 : port
        if (openPort !== 0)
            Tools.showQr(openPort)
        else
            Tools.hideQr()
    }
    Component.onCompleted: {
        Tools.readPorts()
        if (openPort !== 0)
            Tools.showQr(openPort)
    }
    Component.onDestruction: Tools.hideQr()
    Connections {
        target: Tools
        function onPortsChanged() {
            const lan = Tools.ports.filter(p => p.lan)
            if (view.openPort === 0 && lan.length === 1)
                view.show(lan[0].port)
        }
    }

    property bool copied: false
    Timer {
        id: copiedTimer
        interval: 2000
        onTriggered: view.copied = false
    }

    ViewHeader {
        id: header
        title: "Localhost"
        onBack: view.back()
        Rectangle { // look again
            width: 28
            height: 28
            radius: 8
            color: againHover.containsMouse ? Edge.controlHover : Edge.control
            Text {
                anchors.centerIn: parent
                text: Icons.arrowClockwise
                font.family: Icons.regular
                font.pixelSize: 15
                color: againHover.containsMouse ? Theme.fg : Theme.fgMuted
            }
            MouseArea {
                id: againHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Tools.readPorts()
            }
        }
    }

    Item { // no dev servers
        visible: Tools.ports.length === 0
        y: header.height
        width: parent.width
        height: parent.height - y
        Column {
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 48
                height: 48
                radius: 12
                color: Edge.control
                Text {
                    anchors.centerIn: parent
                    text: Icons.qrCode
                    font.family: Icons.regular
                    font.pixelSize: 22
                    color: Theme.hue3
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "No dev servers running"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Start one (node, vite, next, python) and it shows up here with its port."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                lineHeight: 1.2
                color: Theme.fgMuted
            }
        }
    }

    Flickable {
        visible: Tools.ports.length > 0
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
            spacing: 8

            Text {
                leftPadding: 4
                text: "Dev servers"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Repeater {
                model: Tools.ports
                Rectangle { // one server: on the LAN (green, opens to its QR) or localhost only
                    id: server
                    required property var modelData
                    readonly property bool lan: modelData.lan
                    readonly property bool open: lan && view.openPort === modelData.port
                    width: column.width
                    height: serverColumn.implicitHeight + 24
                    radius: 12
                    color: open ? Qt.tint(Edge.fill, Qt.rgba(Theme.hue3.r, Theme.hue3.g, Theme.hue3.b, 0.15))
                        : serverHover.containsMouse && lan ? Edge.controlHover : Edge.control

                    Column {
                        id: serverColumn
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 34
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: server.lan ? Icons.broadcast : Icons.laptop
                                font.family: server.open ? Icons.fill : Icons.regular
                                font.pixelSize: 18
                                color: server.lan ? Theme.hue3 : Theme.fgMuted
                            }
                            Column {
                                x: 30
                                width: parent.width - x - 24
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: ":" + server.modelData.port + " · " + server.modelData.name + " · " + server.modelData.folder
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: Theme.fg
                                }
                                Text {
                                    text: server.lan ? "On the LAN" : "Localhost only"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: server.lan ? Theme.hue3 : Theme.fgMuted
                                }
                            }
                            Text {
                                visible: server.lan
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: server.open ? Icons.caretUp : Icons.caretRight
                                font.family: Icons.regular
                                font.pixelSize: 14
                                color: Theme.fgMuted
                            }
                            MouseArea {
                                id: serverHover
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: server.lan
                                onClicked: view.show(server.modelData.port)
                            }
                        }

                        Text { // localhost only: how the phone could reach it
                            visible: !server.lan
                            width: parent.width
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                            text: "The phone can't reach it. Start it again bound to the LAN, with <font color=\"" + Theme.hue2
                                + "\">--host</font> (vite, next) or <font color=\"" + Theme.hue2 + "\">--bind 0.0.0.0</font> (python)."
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            lineHeight: 1.2
                            color: Theme.fgMuted
                        }

                        Column { // open: the QR, its link, Copy
                            visible: server.open
                            width: parent.width
                            spacing: 8
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 184
                                height: 184
                                radius: 12
                                color: "white" // lan-qr's PNG is black on white: phone cameras read that
                                Image {
                                    anchors.centerIn: parent
                                    width: 168
                                    height: 168
                                    smooth: false // crisp modules: a scaled QR must stay readable
                                    source: server.open ? Tools.qrImage : ""
                                }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: Tools.qrUrl
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fg
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: "Scan it with the phone on this Wi-Fi"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fgMuted
                            }
                            PanelButton {
                                width: parent.width
                                icon: view.copied ? Icons.check : Icons.copy
                                label: view.copied ? "Copied" : "Copy the link"
                                available: Tools.qrUrl !== ""
                                onPressed: {
                                    Tools.copy(Tools.qrUrl)
                                    view.copied = true
                                    copiedTimer.restart()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
