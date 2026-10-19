import QtQuick
import Quickshell.Services.Pipewire

// Quick settings' sound view (owner, 2026-10-20; the sound panel before, SoundPanel.qml): opened
// by the volume level's › or `qs ipc call panel toggle sound`. The output and input devices (a
// click makes one the default, the current one in its hue), then every app playing or recording
// with its own level and device (AppStream.qml). The levels themselves stay on the top level.
// Scrolls inside the panel's fixed height.
Item {
    id: view
    readonly property string viewName: "sound"
    signal back

    // A device row: its icon and name; the current one tinted with the hue, its icon filled.
    component Device: Rectangle {
        id: device
        required property var modelData
        property var current
        property string glyph
        property color hue
        signal picked
        readonly property bool isCurrent: modelData === current
        width: parent.width
        height: 40
        radius: 8
        color: isCurrent ? Qt.tint(Edge.fill, Qt.rgba(hue.r, hue.g, hue.b, deviceHover.containsMouse ? 0.25 : 0.15))
            : deviceHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            id: deviceIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: device.glyph
            font.family: device.isCurrent ? Icons.fill : Icons.regular
            font.pixelSize: 16
            color: device.isCurrent ? device.hue : Theme.fgMuted
        }
        Text {
            x: 40
            width: parent.width - x - 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: device.modelData.nickname || device.modelData.description || device.modelData.name
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        MouseArea {
            id: deviceHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: device.picked()
        }
    }

    component Caption: Text {
        leftPadding: 4
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }

    ViewHeader {
        id: header
        title: "Sound"
        onBack: view.back()
    }

    Flickable {
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
            spacing: 4

            Caption { text: "Output" }
            Repeater {
                model: IslandState.audioSinks
                Device {
                    current: Pipewire.defaultAudioSink
                    glyph: Icons.speakerHigh
                    hue: Theme.hue6
                    onPicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            Item { width: 1; height: 8 }
            Caption { text: "Input" }
            Repeater {
                model: IslandState.audioSources
                Device {
                    current: Pipewire.defaultAudioSource
                    glyph: Icons.microphone
                    hue: Theme.hue1
                    onPicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }

            Item { width: 1; height: 8 }
            Caption { text: "Apps" }
            Caption {
                visible: Sound.streams.length === 0
                text: "No app is playing or recording"
                color: Theme.fgDim
            }
            Rectangle { // the apps, on one card
                visible: Sound.streams.length > 0
                width: parent.width
                height: apps.implicitHeight + 24
                radius: 12
                color: Edge.control
                Column {
                    id: apps
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 12
                    Repeater {
                        model: Sound.playing.concat(Sound.recording)
                        AppStream { required property var modelData; node: modelData }
                    }
                }
            }
        }
    }
}
