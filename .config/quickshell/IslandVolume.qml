import QtQuick
import Quickshell.Services.Pipewire

// Island volume state (design: Desktop prototype, isVolume / isVolumeOpen).
// Compact 260x24: speaker, level bar, number. Expanded: output name, then
// Volume, Mic (and Brightness on hardware that has it) as label, bar, number.
// Level bars: foreground fill on a muted track. Muting changes the glyph only.
Item {
    id: root
    required property bool open
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    component Bar: Rectangle {
        property real level: 0
        height: 4
        color: Theme.border
        Rectangle {
            width: parent.width * Math.max(0, Math.min(parent.level, 1))
            height: 4
            color: Theme.fg
        }
    }

    component LevelRow: Item {
        property string label
        property real level
        property bool off
        width: parent.width
        height: 24
        Text {
            width: 80
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fgMuted
        }
        Bar {
            x: 88
            width: parent.width - 88 - 32
            anchors.verticalCenter: parent.verticalCenter
            level: parent.off ? 0 : parent.level
        }
        Text {
            width: 24
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(parent.level * 100)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
    }

    // Compact
    Item {
        visible: !root.open
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Text {
            id: speaker
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? Icons.speakerSlash
                : root.volume <= 0 ? Icons.speakerNone
                : root.volume < 0.5 ? Icons.speakerLow
                : Icons.speakerHigh
            font.family: Icons.regular
            font.pixelSize: 16
            color: Theme.fg
        }
        Bar {
            x: speaker.width + 8
            width: parent.width - x - 8 - 24
            anchors.verticalCenter: parent.verticalCenter
            level: root.muted ? 0 : root.volume
        }
        Text {
            width: 24
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
    }

    // Expanded (the island draws the chevron in the header row's right corner)
    Column {
        visible: root.open
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width
            height: 24
            Text {
                width: parent.width - 32
                anchors.verticalCenter: parent.verticalCenter
                text: "Output · " + (root.sink ? (root.sink.nickname || root.sink.description || root.sink.name) : "none")
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
        LevelRow { label: "Volume"; level: root.volume; off: root.muted }
        LevelRow { label: "Mic"; level: root.micVolume; off: root.micMuted; visible: root.source !== null }
        LevelRow { label: "Brightness"; level: 0; visible: IslandState.hasBrightness }
    }
}
