import QtQuick
import Quickshell.Hyprland

// Island recording state (design: Desktop prototype, isRecord / isRecordOpen) and its setup panel
// (owner's addition: pick the audio, saved and used by SUPER+R too).
// Compact 240x24: red dot, Recording or Paused, mm:ss, stop. Expanded 340x172: the same with a
// big time; screen, audio and size lines; Pause/Resume and Stop and save (red border).
// Setup ("recsetup", opens expanded, 340x324): the screen it would record; Audio (Mic, Desktop,
// Two tracks), Frame rate (30-144) and Quality (gpu-screen-recorder presets) as button rows, all
// saved; Start recording.
Item {
    id: root
    required property bool open
    property bool setup: false
    readonly property var info: Recording.info
    readonly property var monitor: Hyprland.focusedMonitor

    function time(secs) {
        return String(Math.floor(secs / 60)).padStart(2, "0") + ":" + String(secs % 60).padStart(2, "0")
    }
    function audioText(mic, system) {
        return (mic ? "Mic on" : "Mic off") + " · " + (system ? "System audio on" : "System audio off")
    }

    // Compact
    Item {
        visible: !root.open && !root.setup
        anchors.fill: parent
        anchors.leftMargin: 8

        Text {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.record
            font.family: Icons.fill
            font.pixelSize: 14
            color: Theme.alert
        }
        Text {
            x: dot.width + 8
            anchors.verticalCenter: parent.verticalCenter
            text: Recording.paused ? "Paused" : "Recording"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        Text {
            anchors.right: stop.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.time(Recording.elapsed)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fgMuted
        }
        Item { // stop and save, without opening the panel
            id: stop
            anchors.right: parent.right
            width: 24
            height: parent.height
            Text {
                anchors.centerIn: parent
                text: Icons.stop
                font.family: Icons.regular
                font.pixelSize: 14
                color: Theme.fg
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Recording.stop()
            }
        }
    }

    // Expanded while recording (the island draws the chevron top right)
    Column {
        visible: root.open && !root.setup
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width - 32
            height: 24
            Text {
                id: bigDot
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.record
                font.family: Icons.fill
                font.pixelSize: 16
                color: Theme.alert
            }
            Text {
                x: bigDot.width + 8
                anchors.verticalCenter: parent.verticalCenter
                text: Recording.paused ? "Paused" : "Recording"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fg
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.time(Recording.elapsed)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                color: Theme.fg
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Repeater {
                model: root.info ? [
                    "Screen · " + root.info.monitor + " · " + root.info.width + "×" + root.info.height + " · "
                        + root.info.fps + " fps · " + Recording.qualityLabel(root.info.quality || "very_high"),
                    root.audioText(root.info.mic, root.info.system)
                        + (root.info.separate && root.info.mic && root.info.system ? " · two tracks" : ""),
                    "Size · " + (Recording.size || "…"),
                ] : []
                Text {
                    required property string modelData
                    width: parent.width
                    height: 16
                    text: modelData
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }
        }

        Row {
            width: parent.width
            spacing: 4
            IslandButton {
                width: (parent.width - 4) / 2
                label: Recording.paused ? "Resume" : "Pause"
                onPressed: Recording.pause()
            }
            IslandButton {
                width: (parent.width - 4) / 2
                label: "Stop and save"
                danger: true
                onPressed: Recording.stop()
            }
        }
    }

    // Setup: choose the audio (saved), then start
    Column {
        visible: root.setup
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width - 32
            height: 24
            Text {
                id: setupDot
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.record
                font.family: Icons.regular
                font.pixelSize: 16
                color: Theme.fgMuted
            }
            Text {
                x: setupDot.width + 8
                anchors.verticalCenter: parent.verticalCenter
                text: "Screen recording"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Theme.fg
            }
        }

        Text {
            width: parent.width
            height: 16
            text: root.monitor ? "Screen · " + root.monitor.name + " · " + root.monitor.width + "×"
                + root.monitor.height + " · saved in ~/Videos/Recordings" : ""
            elide: Text.ElideRight
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }

        Column { // audio: lit = on; two tracks only matters with both sources on
            width: parent.width
            spacing: 4
            Text {
                height: 16
                text: "Audio"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Row {
                width: parent.width
                spacing: 4
                IslandButton {
                    width: (parent.width - 8) / 3
                    label: "Mic"
                    on: Recording.micSetting
                    onPressed: Recording.set("mic", !Recording.micSetting)
                }
                IslandButton {
                    width: (parent.width - 8) / 3
                    label: "Desktop"
                    on: Recording.systemSetting
                    onPressed: Recording.set("system", !Recording.systemSetting)
                }
                IslandButton {
                    width: (parent.width - 8) / 3
                    label: "Two tracks"
                    available: Recording.micSetting && Recording.systemSetting
                    on: available && Recording.separateSetting
                    onPressed: Recording.set("separate", !Recording.separateSetting)
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Text {
                height: 16
                text: "Frame rate"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Row {
                width: parent.width
                spacing: 4
                Repeater {
                    model: [30, 60, 120, 144]
                    IslandButton {
                        required property var modelData
                        width: (parent.width - 12) / 4
                        label: modelData
                        on: Recording.fpsSetting === modelData
                        onPressed: Recording.set("fps", modelData)
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Text {
                height: 16
                text: "Quality"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Row {
                width: parent.width
                spacing: 4
                Repeater {
                    model: Recording.qualities
                    IslandButton {
                        required property var modelData
                        width: (parent.width - 12) / 4
                        label: modelData.label
                        on: Recording.qualitySetting === modelData.value
                        onPressed: Recording.set("quality", modelData.value)
                    }
                }
            }
        }

        IslandButton {
            width: parent.width
            label: "Start recording"
            danger: true
            onPressed: Recording.start()
        }
    }
}
