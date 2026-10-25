import QtQuick
import Quickshell
import Quickshell.Hyprland

// Recording panel (owner, 2026-10-17; the "Remaining panels" design since 2026-10-20): comes out of
// the frame under the bar's record block, 360 wide, its right edge on the block's. Not recording:
// the setup, all saved (Recording.set) and used by SUPER + R too: the screen it would record;
// Audio as two tiles, Desktop and Mic (lit in the accent while on), and Two tracks, a switch that
// only matters with both on; Frame rate (30-144) and Quality (gpu-screen-recorder presets) as
// segmented rows; Start recording (red). Starting closes the panel, so it isn't in the video.
// Recording: a REC pill, the time on a card with the screen, audio and size, Pause / Resume and
// Stop and save. The island keeps its own recording views (IslandRecord.qml).
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
    grabFocus: false // EdgePanel's focus grab
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }

    Connections {
        target: Recording
        function onActiveChanged() {
            if (Recording.active && panel.visible)
                panel.visible = false // at once: the recording starts now
        }
    }

    readonly property var info: Recording.info
    readonly property var monitor: Hyprland.focusedMonitor
    function time(secs) {
        return String(Math.floor(secs / 60)).padStart(2, "0") + ":" + String(secs % 60).padStart(2, "0")
    }
    function tint(c, a) { return Qt.tint(Edge.fill, Qt.rgba(c.r, c.g, c.b, a)) }
    readonly property color lift: tint(Theme.fg, 0.12) // a control on a card
    readonly property color danger: tint(Theme.alert, 0.22)
    readonly property color dangerHover: tint(Theme.alert, 0.32)

    component Caption: Text {
        leftPadding: 4
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }

    // A row of choices on one strip; the chosen one a step lighter.
    component Segments: Rectangle {
        id: segments
        property var options: [] // [{ label, value }]
        property var current
        signal chosen(var value)
        width: parent.width
        height: 38
        radius: 10
        color: Edge.control
        Row {
            x: 4
            y: 4
            spacing: 4
            Repeater {
                model: segments.options
                Rectangle {
                    id: segment
                    required property var modelData
                    readonly property bool on: segments.current === modelData.value
                    width: (segments.width - 8 - 4 * (segments.options.length - 1)) / segments.options.length
                    height: 30
                    radius: 7
                    color: on ? panel.lift : segmentHover.containsMouse ? Edge.controlHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: segment.modelData.label
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: segment.on ? Theme.fg : Theme.fgMuted
                    }
                    MouseArea {
                        id: segmentHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: segments.chosen(segment.modelData.value)
                    }
                }
            }
        }
    }

    // An audio source: lit in the accent while on.
    component AudioTile: Rectangle {
        id: tile
        property string label
        property string glyph
        property color hue
        property bool on
        signal clicked
        height: 56
        radius: 12
        color: on ? panel.tint(hue, tileHover.containsMouse ? 0.22 : 0.15)
            : tileHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: tile.glyph
            font.family: tile.on ? Icons.fill : Icons.regular
            font.pixelSize: 18
            color: tile.on ? tile.hue : Theme.fgMuted
        }
        Column {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: tile.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                text: tile.on ? "On" : "Off"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: tile.on ? tile.hue : Theme.fgMuted
            }
        }
        MouseArea {
            id: tileHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }

    component WideButton: Rectangle {
        id: wide
        property string label
        property string glyph: ""
        property bool red
        signal clicked
        height: 44
        radius: 8
        color: red ? (wideHover.containsMouse ? panel.dangerHover : panel.danger)
            : wideHover.containsMouse ? Edge.controlHover : Edge.control
        Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: wide.glyph
                font.family: Icons.fill
                font.pixelSize: 15
                color: wide.red ? Theme.alert : Theme.fgMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: wide.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
        }
        MouseArea {
            id: wideHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: wide.clicked()
        }
    }

    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        bodyWidth: 360
        bodyHeight: (Recording.active ? recording.implicitHeight : setup.implicitHeight) + 24

        focus: true
        Keys.onEscapePressed: reveal.close()

        Item { // the title, and REC while recording
            id: title
            x: 16
            y: 8
            width: parent.width - 32
            height: 32
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Recording.active ? "Recording" : "Screen recording"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.fg
            }
            Rectangle {
                visible: Recording.active
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: recRow.implicitWidth + 20
                height: 24
                radius: 12
                color: Recording.paused ? Edge.control : panel.danger
                Row {
                    id: recRow
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: Recording.paused ? Theme.fgMuted : Theme.alert
                    }
                    Text {
                        text: Recording.paused ? "Paused" : "REC"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Recording.paused ? Theme.fgMuted : Theme.fg
                    }
                }
            }
        }

        Column { // not recording: the setup
            id: setup
            visible: !Recording.active
            x: 16
            y: title.y + title.height + 6
            width: parent.width - 32
            spacing: 14

            Text {
                leftPadding: 4
                width: parent.width
                elide: Text.ElideRight
                text: panel.monitor ? panel.monitor.name + " · " + panel.monitor.width + "×" + panel.monitor.height
                    + " · saved in ~/Videos/Recordings" : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

            Column {
                width: parent.width
                spacing: 6
                Caption { text: "Audio" }
                Row {
                    width: parent.width
                    spacing: 6
                    AudioTile {
                        width: (parent.width - 6) / 2
                        label: "Desktop"
                        glyph: Icons.speakerHigh
                        hue: Theme.accent
                        on: Recording.systemSetting
                        onClicked: Recording.set("system", !Recording.systemSetting)
                    }
                    AudioTile {
                        width: (parent.width - 6) / 2
                        label: "Mic"
                        glyph: Icons.microphone
                        hue: Theme.accent
                        on: Recording.micSetting
                        onClicked: Recording.set("mic", !Recording.micSetting)
                    }
                }
                Rectangle { // two tracks: only with both sources on
                    readonly property bool usable: Recording.micSetting && Recording.systemSetting
                    width: parent.width
                    height: 40
                    radius: 8
                    color: Edge.control
                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Two tracks"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: parent.usable ? Theme.fg : Theme.fgMuted
                    }
                    Text {
                        anchors.right: tracksSwitch.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.usable ? "mic and desktop apart" : "needs both"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgDim
                    }
                    PanelSwitch {
                        id: tracksSwitch
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        available: parent.usable
                        on: parent.usable && Recording.separateSetting
                        onToggled: Recording.set("separate", !Recording.separateSetting)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6
                Caption { text: "Frame rate (fps)" }
                Segments {
                    options: [30, 60, 120, 144].map(n => ({ label: String(n), value: n }))
                    current: Recording.fpsSetting
                    onChosen: (value) => Recording.set("fps", value)
                }
            }

            Column {
                width: parent.width
                spacing: 6
                Caption { text: "Quality" }
                Segments {
                    options: Recording.qualities
                    current: Recording.qualitySetting
                    onChosen: (value) => Recording.set("quality", value)
                }
            }

            WideButton {
                width: parent.width
                red: true
                glyph: Icons.record
                label: "Start recording"
                onClicked: Recording.start()
            }

            Caption {
                width: parent.width
                wrapMode: Text.Wrap
                text: "The panel closes first, so it isn't in the video. SUPER + R starts one too."
            }
        }

        Column { // recording
            id: recording
            visible: Recording.active
            x: 16
            y: title.y + title.height + 6
            width: parent.width - 32
            spacing: 14

            Rectangle {
                width: parent.width
                height: recInfo.implicitHeight + 32
                radius: 12
                color: Edge.control
                Column {
                    id: recInfo
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panel.time(Recording.elapsed)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 36
                        font.weight: Font.Medium
                        color: Recording.paused ? Theme.fgMuted : Theme.fg
                    }
                    Repeater {
                        model: panel.info ? [
                            panel.info.monitor + " · " + panel.info.width + "×" + panel.info.height + " · "
                                + panel.info.fps + " fps · " + Recording.qualityLabel(panel.info.quality || "very_high"),
                            [panel.info.system ? "Desktop audio" : "", panel.info.mic ? "Mic" : ""].filter(t => t !== "").join(" and ")
                                + (panel.info.system || panel.info.mic ? "" : "No audio")
                                + (panel.info.separate && panel.info.mic && panel.info.system ? " · two tracks" : "")
                                + " · " + (Recording.size || "…"),
                        ] : []
                        Text {
                            required property string modelData
                            width: recInfo.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: modelData
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6
                WideButton {
                    width: (parent.width - 6) / 2
                    glyph: Recording.paused ? Icons.play : Icons.pause
                    label: Recording.paused ? "Resume" : "Pause"
                    onClicked: Recording.pause()
                }
                WideButton {
                    width: (parent.width - 6) / 2
                    red: true
                    glyph: Icons.stop
                    label: "Stop and save"
                    onClicked: Recording.stop()
                }
            }

            Caption {
                text: "Saved to ~/Videos/Recordings, with a notification."
            }
        }
    }
}
