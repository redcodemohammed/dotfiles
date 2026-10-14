import QtQuick
import Quickshell.Services.Pipewire

// Island volume state (design: Desktop prototype, isVolume / isVolumeOpen).
// Compact 260x24: speaker, level bar, number. Expanded: Volume, Mic (and Brightness on hardware
// that has it) as label, bar, number; then the output and input device lists, always visible
// (owner, 2026-10-15): the current device has the amber marker, clicking one makes it the default.
// Clicking the bar's volume block opens this expanded panel.
// Level bars: foreground fill on a muted track. Muting changes the glyph only.
// Brightness keys show the same pill with a sun and the brightness level (owner's choice).
Item {
    id: root
    required property bool open
    readonly property bool isBrightness: IslandState.kind === "brightness"
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
        width: parent.width - 32 // the island's chevron sits top right
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
            text: root.isBrightness ? Icons.sun
                : root.muted ? Icons.speakerSlash
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
            level: root.isBrightness ? IslandState.brightness : root.muted ? 0 : root.volume
        }
        Text {
            width: 24
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round((root.isBrightness ? IslandState.brightness : root.volume) * 100)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
    }

    // Expanded (the island draws the chevron top right)
    Column {
        visible: root.open
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        LevelRow { label: "Volume"; level: root.volume; off: root.muted }
        LevelRow { label: "Mic"; level: root.micVolume; off: root.micMuted; visible: root.source !== null }
        LevelRow { label: "Brightness"; level: IslandState.brightness; visible: IslandState.hasBrightness }

        IslandDeviceList {
            title: "Output"
            nodes: IslandState.audioSinks
            current: root.sink
            onPicked: node => Pipewire.preferredDefaultAudioSink = node
        }
        IslandDeviceList {
            title: "Input"
            nodes: IslandState.audioSources
            current: root.source
            onPicked: node => Pipewire.preferredDefaultAudioSource = node
        }
    }
}
