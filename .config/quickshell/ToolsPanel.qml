import QtQuick
import QtQuick.Controls
import Quickshell

// Tools panel (owner, 2026-10-17; the "Dev tools panel" design since 2026-10-20): comes out of the
// frame under the tools chip (wrench), 380 wide, its right edge on the chip's. Closes on an
// outside click or Escape; SUPER + X toggles it (Tools.qml).
// Screen: Pick colour (the panel closes, hyprpicker) and Read text (OCR a region), two tiles; the
// recent colours below as swatches, a click copies one (the last copied ringed, its hex at the
// end). Keep awake left the panel: its switch is in quick settings, the wrench lights up while on.
// Clipboard (the clipboard in, the result back): what it holds (clip-tool peek: a badge, a
// preview only for a JWT's header, JSON and URL-encoded text, owner 2026-10-20), the transform
// that fits tinted blue, one that failed red; Decode JWT, Format JSON, then Base64 and URL as
// split buttons, encode (↑) and decode (↓). Generate: the value itself on each row, UUID, ISO
// and Unix time (live) and lorem ipsum; a click copies what is shown, then a new UUID comes.
// Decode JWT copies the payload and pushes JwtView.qml (the header and payload, its expiry).
// Localhost: one row (how many servers, how many on the LAN) pushing LocalhostView.qml on a
// StackView, as quick settings' views: it slides in from the right, back or Escape pops it,
// closing returns to the top level, the panel keeps the top level's height.
// The note line under it all reports each result: green done, red failed, neutral otherwise.
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width + reveal.overhang - implicitWidth // the body's right edge on the chip's
    anchor.rect.y: block.height + 6
    implicitWidth: reveal.implicitWidth
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }
    color: "transparent"
    grabFocus: false // an outside click goes through EdgePanel's focus grab, so closing can slide
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: {
        if (!visible) {
            say("", "")
            Tools.failed = ""
            stack.pop(null, StackView.Immediate)
        } else {
            now = new Date()
            Tools.peek()
            Tools.readPorts()
        }
    }

    // The note line: what happened ("ok", "error" or "info") and a detail at its end, cleared
    // after 2 s (an error after 4, it has more to read).
    property string note: ""
    property string noteKind: ""
    property string noteDetail: ""
    function say(kind, text, detail) {
        noteKind = kind
        note = text
        noteDetail = detail ?? ""
        if (text !== "")
            noteTimer.restart()
    }
    Timer {
        id: noteTimer
        interval: panel.noteKind === "error" ? 4000 : 2000
        onTriggered: panel.say("", "")
    }
    // qs ipc call tools qr <port>: the Localhost view with that server open.
    function openLocalhost(port) {
        stack.pop(null, StackView.Immediate)
        stack.push(localhostView, { openPort: port }, visible ? StackView.PushTransition : StackView.Immediate)
        visible = true
    }
    Component {
        id: localhostView
        LocalhostView { onBack: stack.pop() }
    }
    Component {
        id: jwtView
        JwtView { onBack: stack.pop() }
    }
    Connections {
        target: Tools
        function onJwtDecoded(header, payload) {
            if (panel.visible)
                stack.push(jwtView, { header: header, payload: payload })
        }
        function onLocalhostRequested(screen, port) {
            if (screen === panel.bar.modelData.name)
                panel.openLocalhost(port)
        }
        function onClipDone(message, ok) { // an error's reason goes on a second line
            const cut = ok ? -1 : message.indexOf(": ")
            if (cut > 0)
                panel.say("error", message.slice(0, cut), message.slice(cut + 2))
            else
                panel.say(ok ? "ok" : "error", message)
        }
    }

    // The transform that fits what the clipboard holds.
    readonly property string suggested: ({ jwt: "jwt", json: "json", base64: "b64d", url: "urld" })[Tools.clipboard.kind] ?? ""
    readonly property bool detected: suggested !== ""

    // The times on the Generate list tick while the panel is open.
    property var now: new Date()
    Timer {
        running: panel.visible
        interval: 1000
        repeat: true
        onTriggered: panel.now = new Date()
    }
    function iso(d) { // as clip-tool's: seconds and the offset, 2026-10-20T19:10:07+03:00
        const p = n => String(n).padStart(2, "0")
        const off = -d.getTimezoneOffset()
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "T" + p(d.getHours())
            + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds()) + (off >= 0 ? "+" : "-")
            + p(Math.floor(Math.abs(off) / 60)) + ":" + p(Math.abs(off) % 60)
    }

    property string lastColour: ""
    property string hoverColour: ""

    // Buttons on a card: one step lighter than the card itself.
    readonly property color lift: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12))
    readonly property color liftHover: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.18))
    function tint(hue, amount) { return Qt.tint(Edge.fill, Qt.rgba(hue.r, hue.g, hue.b, amount)) }

    component ToolCaption: Text {
        leftPadding: 4
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }

    // A screen tool: its icon in its hue, a name and what it does.
    component ToolTile: Rectangle {
        id: tile
        property string glyph
        property color hue
        property string label
        property string status
        signal clicked
        height: 56
        radius: 12
        color: tileHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: tile.glyph
            font.family: Icons.regular
            font.pixelSize: 20
            color: tile.hue
        }
        Column {
            x: 42
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 8
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: tile.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: tile.status
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
        MouseArea {
            id: tileHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }

    // A transform button on the clipboard card; `glyph` before the label, `corners` rounds only
    // the outer side of a split button's half ("left", "right" or "" for both).
    component CardButton: Item {
        id: cardButton
        property string label
        property string glyph
        property string corners: ""
        property string action // clip-tool's: run on a click, tinted when it fits or failed
        readonly property bool fits: panel.suggested === action
        readonly property bool failed: Tools.failed === action
        height: 32
        Rectangle { // radius 8 on the outer corners, 3 where the halves meet
            anchors.fill: parent
            radius: cardButton.corners === "" ? 8 : 3
            color: cardButton.failed ? Edge.alertTint
                : cardButton.fits ? panel.tint(Theme.hue5, cardHover.containsMouse ? 0.25 : 0.15)
                : cardHover.containsMouse ? panel.liftHover : panel.lift
            Rectangle {
                visible: cardButton.corners !== ""
                x: cardButton.corners === "left" ? 0 : parent.width - width
                width: Math.min(parent.width, 16)
                height: parent.height
                radius: 8
                color: parent.color
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: cardButton.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: cardButton.glyph
                font.family: cardButton.fits ? Icons.fill : Icons.regular
                font.pixelSize: 14
                color: cardButton.failed ? Theme.alert : Theme.hue5
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cardButton.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: cardButton.failed ? Theme.alert : cardButton.fits ? Theme.fg : Theme.fgMuted
            }
        }
        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Tools.clip(cardButton.action)
        }
    }
    // Encode and decode side by side: the wide half encodes, the narrow one decodes.
    component SplitButton: Row {
        id: split
        property string label
        property string encode
        property string decode
        spacing: 2
        CardButton {
            width: split.width - 46
            corners: "left"
            label: split.label + " ↑"
            action: split.encode
        }
        CardButton {
            width: 44
            corners: "right"
            label: "↓"
            action: split.decode
        }
    }

    // A Generate row: the kind, the value itself, a copy mark; a click copies the value shown.
    component GenRow: Rectangle {
        id: gen
        property string label
        property string value
        property string done // the note: "Copied UUID"
        signal copied
        width: parent.width
        height: 36
        radius: 8
        color: genHover.containsMouse ? panel.lift : "transparent"
        Text {
            x: 8
            width: 48
            anchors.verticalCenter: parent.verticalCenter
            text: gen.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.hue6
        }
        Text {
            x: 58
            width: parent.width - x - 32
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: gen.value
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fg
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.copy
            font.family: Icons.regular
            font.pixelSize: 14
            color: genHover.containsMouse ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            id: genHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: gen.value !== ""
            onClicked: {
                Tools.copy(gen.value)
                panel.say("ok", gen.done, gen.value)
                gen.copied()
            }
        }
    }

    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        bodyWidth: 380
        bodyHeight: column.implicitHeight + 24

        focus: true
        Keys.onEscapePressed: stack.depth > 1 ? stack.pop() : reveal.close()

        // A view slides in from the right over the top level, and back out.
        StackView {
            id: stack
            width: parent.width
            height: reveal.bodyHeight
            clip: true
            initialItem: topLevel
            readonly property int pace: Settings.look.animations ? 250 : 0
            pushEnter: Transition { XAnimator { from: stack.width; to: 0; duration: stack.pace; easing.type: Easing.OutCubic } }
            pushExit: Transition { XAnimator { from: 0; to: -stack.width / 3; duration: stack.pace; easing.type: Easing.OutCubic } }
            popEnter: Transition { XAnimator { from: -stack.width / 3; to: 0; duration: stack.pace; easing.type: Easing.OutCubic } }
            popExit: Transition { XAnimator { from: 0; to: stack.width; duration: stack.pace; easing.type: Easing.OutCubic } }
        }

        Item { // the top level
            id: topLevel
            Column {
                id: column
                x: 16
                y: 8
                width: stack.width - 32
                spacing: 14

                Column { // the screen tools and the recent colours
                    width: parent.width
                    spacing: 8
                    Row {
                        width: parent.width
                        spacing: 8
                        readonly property real cell: (width - spacing) / 2
                        ToolTile {
                            width: parent.cell
                            glyph: Icons.eyedropper
                            hue: Theme.hue1
                            label: "Pick colour"
                            status: "From the screen"
                            onClicked: {
                                panel.visible = false
                                Tools.pickColour()
                            }
                        }
                        ToolTile {
                            width: parent.cell
                            glyph: Icons.textT
                            hue: Theme.hue4
                            label: "Read text"
                            status: "Region to clipboard"
                            onClicked: {
                                panel.visible = false
                                Tools.readText()
                            }
                        }
                    }
                    Item {
                        visible: Tools.colours.length > 0
                        width: parent.width
                        height: 36
                        Row {
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Repeater {
                                model: Tools.colours
                                Rectangle {
                                    id: swatch
                                    required property string modelData
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: modelData
                                    Rectangle { // the last one copied: a ring in its own colour
                                        visible: panel.lastColour === swatch.modelData
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        radius: 11
                                        color: "transparent"
                                        border.width: 2
                                        border.color: swatch.modelData
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onContainsMouseChanged: panel.hoverColour = containsMouse ? swatch.modelData : ""
                                        onClicked: {
                                            Tools.copy(swatch.modelData)
                                            panel.lastColour = swatch.modelData
                                            panel.say("ok", "Copied " + swatch.modelData)
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: panel.hoverColour || panel.lastColour || Tools.colours[0] || ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }
                    }
                }

                Column { // the clipboard in, the result back
                    width: parent.width
                    spacing: 6
                    ToolCaption { text: "Clipboard" }
                    Rectangle {
                        width: parent.width
                        height: clipColumn.implicitHeight + 24
                        radius: 12
                        color: Edge.control
                        Column {
                            id: clipColumn
                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 10
                            Item { // what it holds: a JWT's header or a URL itself, else its kind and size
                                width: parent.width
                                height: 20
                                readonly property var cb: Tools.clipboard
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.clipboardText
                                    font.family: Icons.regular
                                    font.pixelSize: 16
                                    color: panel.detected ? Theme.hue5 : Theme.fgMuted
                                }
                                Text {
                                    x: 26
                                    width: badge.x - x - 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    readonly property string count: parent.cb.size + (parent.cb.size === 1 ? " character" : " characters")
                                    text: parent.cb.kind === "jwt" || parent.cb.kind === "url" ? parent.cb.preview[0] ?? ""
                                        : parent.cb.kind === "json" ? parent.cb.preview.length + (parent.cb.preview.length === 1 ? " line" : " lines")
                                        : parent.cb.kind === "empty" ? "The clipboard is empty"
                                        : parent.cb.kind === "binary" ? "Not text (an image or a file)"
                                        : parent.cb.kind === "" ? "Reading the clipboard" : count
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: parent.cb.kind === "jwt" || parent.cb.kind === "url" ? Theme.fg : Theme.fgMuted
                                }
                                Rectangle {
                                    id: badge
                                    visible: badgeText.text !== ""
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: visible ? badgeText.implicitWidth + 16 : 0
                                    height: 20
                                    radius: 6
                                    color: panel.detected ? panel.tint(Theme.hue5, 0.15) : panel.lift
                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: ({ jwt: "JWT", json: "JSON", base64: "Base64", url: "URL", text: "Text" })[parent.parent.cb.kind] ?? ""
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: panel.detected ? Theme.hue5 : Theme.fgMuted
                                    }
                                }
                            }
                            Rectangle { // JSON: its first lines (formatted after Format JSON)
                                visible: Tools.clipboard.kind === "json"
                                width: parent.width
                                height: jsonText.implicitHeight + 20
                                radius: 8
                                color: Edge.fill
                                clip: true
                                Text {
                                    id: jsonText
                                    x: 10
                                    y: 10
                                    width: parent.width - 20
                                    elide: Text.ElideRight
                                    text: (Tools.clipboard.preview ?? []).join("\n")
                                    textFormat: Text.PlainText
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    lineHeight: 1.2
                                    color: Theme.fgMuted
                                }
                            }
                            Grid {
                                width: parent.width
                                columns: 2
                                spacing: 6
                                readonly property real cell: (width - spacing) / 2
                                CardButton {
                                    width: parent.cell
                                    glyph: Icons.key
                                    label: "Decode JWT"
                                    action: "jwt"
                                }
                                CardButton {
                                    width: parent.cell
                                    label: "Format JSON"
                                    action: "json"
                                }
                                SplitButton {
                                    width: parent.cell
                                    label: "Base64"
                                    encode: "b64e"
                                    decode: "b64d"
                                }
                                SplitButton {
                                    width: parent.cell
                                    label: "URL"
                                    encode: "urle"
                                    decode: "urld"
                                }
                            }
                        }
                    }
                }

                Column { // the values themselves: a click copies what is shown
                    width: parent.width
                    spacing: 6
                    ToolCaption { text: "Generate · click to copy" }
                    Rectangle {
                        width: parent.width
                        height: genColumn.implicitHeight + 12
                        radius: 12
                        color: Edge.control
                        Column {
                            id: genColumn
                            x: 6
                            y: 6
                            width: parent.width - 12
                            spacing: 2
                            GenRow {
                                label: "UUID"
                                value: Tools.uuid
                                done: "Copied UUID"
                                onCopied: Tools.freshUuid()
                            }
                            GenRow {
                                label: "ISO"
                                value: panel.iso(panel.now)
                                done: "Copied ISO time"
                            }
                            GenRow {
                                label: "Unix"
                                value: String(Math.floor(panel.now.getTime() / 1000))
                                done: "Copied Unix time"
                            }
                            GenRow {
                                label: "Lorem"
                                value: Tools.lorem
                                done: "Copied lorem ipsum"
                            }
                        }
                    }
                }

                Rectangle { // your dev servers: pushes the Localhost view
                    width: parent.width
                    height: 48
                    radius: 12
                    color: localHover.containsMouse ? Edge.controlHover : Edge.control
                    readonly property int lan: Tools.ports.filter(p => p.lan).length
                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.qrCode
                        font.family: Icons.regular
                        font.pixelSize: 20
                        color: Theme.hue3
                    }
                    Column {
                        x: 42
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "Localhost"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: Theme.fg
                        }
                        Text {
                            text: Tools.ports.length === 0 ? "No dev servers"
                                : Tools.ports.length + (Tools.ports.length === 1 ? " server" : " servers")
                                    + (parent.parent.lan > 0 ? " · " + parent.parent.lan + " on the LAN" : "")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: parent.parent.lan > 0 ? Theme.hue3 : Theme.fgMuted
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.caretRight
                        font.family: Icons.regular
                        font.pixelSize: 14
                        color: Theme.fgMuted
                    }
                    MouseArea {
                        id: localHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: stack.push(localhostView)
                    }
                }

                Rectangle { // the note line; an error's reason on a second line
                    visible: panel.note !== ""
                    readonly property bool twoLines: panel.noteKind === "error" && panel.noteDetail !== ""
                    width: parent.width
                    height: twoLines ? reason.y + reason.height + 9 : 32
                    radius: 8
                    color: panel.noteKind === "ok" ? panel.tint(Theme.hue3, 0.15)
                        : panel.noteKind === "error" ? Edge.alertTint : Edge.control
                    Text {
                        id: noteIcon
                        x: 10
                        y: 9
                        text: panel.noteKind === "ok" ? Icons.check : panel.noteKind === "error" ? Icons.warningCircle : Icons.info
                        font.family: Icons.regular
                        font.pixelSize: 14
                        color: panel.noteKind === "ok" ? Theme.hue3 : panel.noteKind === "error" ? Theme.alert : Theme.fgMuted
                    }
                    Text {
                        id: noteText
                        x: 32
                        y: 8
                        width: Math.min(implicitWidth, parent.width - x - 10)
                        elide: Text.ElideRight
                        text: panel.note
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: panel.noteKind === "error" ? Theme.alert : Theme.fg
                    }
                    Text {
                        id: reason
                        visible: parent.twoLines
                        x: 32
                        y: noteText.y + noteText.height + 2
                        width: parent.width - x - 10
                        wrapMode: Text.Wrap
                        text: panel.noteDetail
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Text {
                        visible: !parent.twoLines
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        y: 8
                        width: Math.max(0, parent.width - noteText.x - noteText.width - 22)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        text: panel.noteDetail
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
            }
        }
    }
}
