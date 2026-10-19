import QtQuick
import Quickshell

// The tools panel's JWT view (owner, 2026-10-20, the "Dev tools panel" design): pushed when Decode
// JWT works, which has copied the payload (clip-tool jwt). The algorithm in the header; a card
// saying how long the token is valid for, or how long ago it expired (from exp and iat, green or
// red; neutral without exp); the header and the payload; Copy header and Copy payload, the one on
// the clipboard ticked. The signature is never checked. Scrolls inside the panel's fixed height.
Item {
    id: view
    readonly property string viewName: "jwt"
    signal back
    property var header: ({})
    property var payload: ({})

    property string copied: "payload" // Decode JWT copied it
    property real now: Date.now() / 1000
    Timer {
        running: true
        interval: 30000
        repeat: true
        onTriggered: view.now = Date.now() / 1000
    }

    readonly property bool hasExp: typeof payload.exp === "number"
    readonly property bool expired: hasExp && payload.exp < now
    function span(seconds) { // 1 h 58 min, 3 d 4 h, 12 min, under a minute
        const s = Math.abs(seconds)
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + " d " + h + " h" : h > 0 ? h + " h " + m + " min" : m > 0 ? m + " min" : "under a minute"
    }
    function when(t) { // today: 19:10, else 2026-10-20 19:10
        const d = new Date(t * 1000)
        const p = n => String(n).padStart(2, "0")
        const time = p(d.getHours()) + ":" + p(d.getMinutes())
        return d.toDateString() === new Date().toDateString() ? time
            : d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + time
    }
    readonly property color hue: !hasExp ? Theme.fgMuted : expired ? Theme.alert : Theme.hue3

    ViewHeader {
        id: titleRow
        title: "JWT"
        onBack: view.back()
        Rectangle {
            visible: typeof view.header.alg === "string"
            width: algText.implicitWidth + 16
            height: 22
            radius: 6
            color: Qt.tint(Edge.fill, Qt.rgba(Theme.hue5.r, Theme.hue5.g, Theme.hue5.b, 0.15))
            Text {
                id: algText
                anchors.centerIn: parent
                text: view.header.alg ?? ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: Theme.hue5
            }
        }
    }

    Flickable {
        y: titleRow.height + 8
        width: parent.width
        height: parent.height - y
        contentHeight: column.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            x: 16
            width: parent.width - 32
            spacing: 10

            Rectangle { // valid for, or expired
                width: parent.width
                height: 52
                radius: 12
                color: !view.hasExp ? Edge.control : view.expired ? Edge.alertTint
                    : Qt.tint(Edge.fill, Qt.rgba(Theme.hue3.r, Theme.hue3.g, Theme.hue3.b, 0.15))
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.timer
                    font.family: Icons.regular
                    font.pixelSize: 18
                    color: view.hue
                }
                Column {
                    x: 40
                    width: parent.width - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: !view.hasExp ? "No expiry" : view.expired ? "Expired " + view.span(view.now - view.payload.exp) + " ago"
                            : "Valid for " + view.span(view.payload.exp - view.now)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: view.hasExp ? view.hue : Theme.fg
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: [view.hasExp ? "exp " + view.when(view.payload.exp) : "",
                            typeof view.payload.iat === "number" ? "issued " + view.when(view.payload.iat) : ""]
                            .filter(t => t !== "").join(" · ") || "The token has no exp claim"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
            }

            Repeater {
                model: [{ title: "Header", value: view.header }, { title: "Payload", value: view.payload }]
                Column {
                    required property var modelData
                    width: column.width
                    spacing: 6
                    Text {
                        leftPadding: 4
                        text: parent.modelData.title
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Rectangle {
                        width: parent.width
                        height: block.implicitHeight + 24
                        radius: 12
                        color: Edge.control
                        Text {
                            id: block
                            x: 12
                            y: 12
                            width: parent.width - 24
                            wrapMode: Text.WrapAnywhere // long claims (a URL, a list) break, not overflow
                            textFormat: Text.PlainText
                            text: JSON.stringify(parent.parent.modelData.value, null, 2)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            lineHeight: 1.2
                            color: Theme.fg
                        }
                    }
                }
            }

            Text {
                leftPadding: 4
                text: "Signature not checked: decoding only."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Row {
                width: parent.width
                spacing: 6
                readonly property real cell: (width - spacing) / 2
                PanelButton {
                    width: parent.cell
                    icon: view.copied === "header" ? Icons.check : Icons.copy
                    label: view.copied === "header" ? "Header copied" : "Copy header"
                    onPressed: {
                        Tools.copy(JSON.stringify(view.header, null, 2))
                        view.copied = "header"
                    }
                }
                PanelButton {
                    width: parent.cell
                    icon: view.copied === "payload" ? Icons.check : Icons.copy
                    label: view.copied === "payload" ? "Payload copied" : "Copy payload"
                    onPressed: {
                        Tools.copy(JSON.stringify(view.payload, null, 2))
                        view.copied = "payload"
                    }
                }
            }
        }
    }
}
