import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Volume OSD: bottom centre of the focused monitor, flush with the bottom edge.
// Same look as popups. Level bar: foreground fill on a muted track, no amber.
// Shows on a volume or mute change, hides 1.5 s after the last one.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    property bool shown: false

    visible: shown && monitor && monitor.focused
    anchors.bottom: true
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 280
    implicitHeight: 44

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root.flash() }
        function onMutedChanged() { root.flash() }
    }

    function flash() {
        shown = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        Row {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.muted ? Icons.speakerSlash
                    : root.volume <= 0 ? Icons.speakerNone
                    : root.volume < 0.5 ? Icons.speakerLow
                    : Icons.speakerHigh
                font.family: Icons.regular
                font.pixelSize: 16
                color: Theme.fg
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                height: 4
                color: Theme.border

                Rectangle {
                    width: parent.width * Math.min(root.muted ? 0 : root.volume, 1)
                    height: parent.height
                    color: Theme.fg
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volume * 100)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
        }
    }
}
