import QtQuick
import Quickshell.Services.Pipewire

// Default output: icon plus number, both gray. Muting changes the glyph, not the color.
Row {
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    visible: sink !== null
    spacing: 4

    // Node properties only stay live while a tracker binds the node.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: parent.muted ? Icons.speakerSlash
            : parent.volume <= 0 ? Icons.speakerNone
            : parent.volume < 0.5 ? Icons.speakerLow
            : Icons.speakerHigh
        font.family: Icons.regular
        font.pixelSize: 16
        color: Theme.fgMuted
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(parent.volume * 100)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fgMuted
    }
}
