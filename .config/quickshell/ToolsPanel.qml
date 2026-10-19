import QtQuick
import Quickshell

// Tools panel (owner, 2026-10-17; power moved to PowerPanel.qml 2026-10-18): drops from the
// bar's tools block (wrench), 360 wide, 4px under the bar, its right edge on the block's. Closes
// on an outside click or Escape; SUPER + X toggles it (Tools.qml).
// Tools (step 2): Pick colour (the panel closes, hyprpicker; recent colours below as swatches, a
// click copies one), Keep awake (on/off; pauses the idle chain), Text from screen (OCR).
// Clipboard and Generate (step 3; equal grids, three a row, since 2026-10-18): Clipboard (format
// JSON, decode JWT, base64 and URL encode/decode: the clipboard in, the result back), Generate
// (UUID, ISO and Unix time, lorem ipsum: copied). Localhost QR: your dev servers' ports (known
// runtimes only, dev-ports); a LAN one shows a QR of http://<LAN address>:<port> for the phone,
// a localhost-only one says to start it with --host. The note line reports each result.
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
            closedAt = Date.now()
            note = ""
            Tools.hideQr()
        } else {
            Tools.readPorts()
        }
    }

    // A short line under the tools (e.g. "Copied #f5a524"), cleared after 2 s.
    property string note: ""
    onNoteChanged: if (note !== "") noteTimer.restart()
    Timer {
        id: noteTimer
        interval: 2000
        onTriggered: panel.note = ""
    }

    Connections {
        target: Tools
        function onClipDone(message) { panel.note = message }
    }

    // A small text button for the Web section.
    component Chip: Rectangle {
        id: chip
        property string label
        signal clicked
        width: chipText.implicitWidth + 16
        height: 28
        radius: 8
        color: chipHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fg
        }
        MouseArea {
            id: chipHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    // A tool button: glyph and label; `lit` (Keep awake) shows it lit, with the accent glyph.
    component ToolTile: Rectangle {
        id: tile
        property string glyph
        property string label
        property bool lit: false
        signal clicked
        height: 64
        radius: 12 // a card
        color: lit ? Edge.accentTint : tileHover.containsMouse ? Edge.controlHover : Edge.control
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.glyph
                font.family: tile.lit ? Icons.fill : Icons.regular
                font.pixelSize: 20
                color: tile.lit ? Theme.accent : Theme.fg
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: tile.lit ? Theme.fg : Theme.fgMuted
            }
        }
        MouseArea {
            id: tileHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }


    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        bodyWidth: 360
        bodyHeight: column.implicitHeight + 24

        focus: true
        Keys.onEscapePressed: reveal.close()

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Text {
                text: "Tools"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Row {
                width: parent.width
                spacing: 4
                readonly property real cell: (width - 2 * spacing) / 3
                ToolTile {
                    width: parent.cell
                    glyph: Icons.eyedropper
                    label: "Pick colour"
                    onClicked: {
                        panel.visible = false
                        Tools.pickColour()
                    }
                }
                ToolTile {
                    width: parent.cell
                    glyph: Icons.coffee
                    label: Tools.keepAwake ? "Awake: on" : "Keep awake"
                    lit: Tools.keepAwake
                    onClicked: Tools.setKeepAwake(!Tools.keepAwake)
                }
                ToolTile {
                    width: parent.cell
                    glyph: Icons.textT
                    label: "Read text"
                    onClicked: {
                        panel.visible = false
                        Tools.readText()
                    }
                }
            }

            Row { // recent colours: a click copies
                visible: Tools.colours.length > 0
                spacing: 4
                Repeater {
                    model: Tools.colours
                    Rectangle {
                        required property string modelData
                        width: 32
                        height: 32
                        radius: 8
                        color: modelData
                        border.width: swatchHover.containsMouse ? 2 : 0 // a ring on hover
                        border.color: Theme.fg
                        MouseArea {
                            id: swatchHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Tools.copy(parent.modelData)
                                panel.note = "Copied " + parent.modelData
                            }
                        }
                    }
                }
            }

            // Web tools as two grids of equal buttons, three a row (owner, 2026-10-18).
            Repeater {
                model: [
                    { title: "Clipboard", tools: [ // the clipboard in, the result back
                        { a: "json", t: "Format JSON" }, { a: "jwt", t: "Decode JWT" },
                        { a: "b64e", t: "Base64 encode" }, { a: "b64d", t: "Base64 decode" },
                        { a: "urle", t: "URL encode" }, { a: "urld", t: "URL decode" },
                    ] },
                    { title: "Generate", tools: [ // copied fresh
                        { a: "uuid", t: "UUID" }, { a: "iso", t: "ISO time" },
                        { a: "unix", t: "Unix time" }, { a: "lorem", t: "Lorem ipsum" },
                    ] },
                ]
                Column {
                    required property var modelData
                    width: column.width
                    spacing: 8
                    Text {
                        topPadding: 4
                        text: parent.modelData.title
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Grid {
                        id: grid
                        columns: 3
                        spacing: 4
                        readonly property real cell: (parent.width - 2 * spacing) / 3
                        Repeater {
                            model: parent.parent.modelData.tools
                            Chip {
                                required property var modelData
                                width: grid.cell
                                height: 32
                                label: modelData.t
                                onClicked: Tools.clip(modelData.a)
                            }
                        }
                    }
                }
            }

            Text {
                text: Tools.ports.length > 0 ? "Localhost QR · open on the phone" : "Localhost QR · no dev servers running"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }

            Repeater { // one row per dev server port
                model: Tools.ports
                Rectangle {
                    required property var modelData
                    width: column.width
                    height: 28
                    color: portHover.containsMouse && modelData.lan ? Theme.surfaceSelected : "transparent"
                    Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 16 - hint.implicitWidth
                        elide: Text.ElideRight
                        text: ":" + modelData.port + "  " + modelData.name + " · " + modelData.folder
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: modelData.lan ? Theme.fg : Theme.fgMuted
                    }
                    Text {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.lan ? "QR" : "local only" // bound to 127.0.0.1: start it with --host to reach it
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: modelData.lan ? Theme.accent : Theme.fgDim
                    }
                    MouseArea {
                        id: portHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.modelData.lan
                        onClicked: Tools.showQr(parent.modelData.port)
                    }
                }
            }

            Column { // the QR for the chosen port, with its address
                visible: Tools.qrImage !== ""
                width: parent.width
                spacing: 4
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 160
                    height: 160
                    smooth: false // crisp modules: a scaled QR must stay readable
                    source: Tools.qrImage
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tools.qrUrl
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fg
                    }
                    Chip {
                        label: "Copy"
                        onClicked: {
                            Tools.copy(Tools.qrUrl)
                            panel.note = "Copied " + Tools.qrUrl
                        }
                    }
                }
            }

            Text {
                visible: panel.note !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: panel.note
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
    }
}
