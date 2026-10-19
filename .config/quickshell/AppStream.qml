import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// One app's audio stream in the sound panel's Apps tab (owner, 2026-10-17). The app's icon
// (a click mutes it; muted: dimmed, with the slash glyph over it), its name and what it plays,
// the level in %, a slider (click, drag or scroll), and the device it uses as a pill: a click opens
// the list, Default follows the system default. Playback streams pick an output, recording ones an
// input. The device is moved with WirePlumber's target.object in PipeWire's default metadata
// (`pw-metadata <id> target.object <device>`; deleted for Default), which moves the stream at
// once (tested 2026-10-17); `targets` (Sound.qml) holds what is set.
Column {
    id: row
    required property var node
    property bool picking: false
    readonly property var props: node.properties ?? {}
    readonly property bool recording: (props["media.class"] ?? "").startsWith("Stream/Input")
    readonly property string appName: props["application.name"] || node.description || node.name
    readonly property string media: props["media.name"] ?? ""
    readonly property string icon: props["application.icon-name"] || props["application.process.binary"] || ""
    readonly property real level: node.audio ? node.audio.volume : 0
    readonly property bool muted: node.audio ? node.audio.muted : false
    readonly property var devices: recording ? Sound.inputs : Sound.outputs
    readonly property string target: Sound.targets[node.id] ?? ""
    readonly property var current: devices.find(d => d.name === target) ?? null

    spacing: 4
    width: parent.width

    function setLevel(v) {
        if (node.audio)
            node.audio.volume = Math.max(0, Math.min(1, v))
    }

    Item {
        width: parent.width
        height: 32
        Item {
            id: iconBox
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            opacity: row.muted ? 0.4 : 1
            IconImage {
                anchors.fill: parent
                source: Quickshell.iconPath(row.icon.toLowerCase(), row.recording ? "audio-input-microphone" : "audio-volume-high")
            }
            MouseArea {
                anchors.fill: parent
                onClicked: if (row.node.audio) row.node.audio.muted = !row.muted
            }
        }
        Text {
            visible: row.muted
            anchors.centerIn: iconBox
            text: row.recording ? Icons.microphoneSlash : Icons.speakerSlash
            font.family: Icons.fill
            font.pixelSize: 16
            color: Theme.fg
        }
        Column {
            x: 32
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32 - pct.implicitWidth - 8
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: row.appName
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: row.muted ? Theme.fgMuted : Theme.fg
            }
            Text {
                visible: row.media !== "" && row.media !== row.appName
                width: parent.width
                elide: Text.ElideRight
                text: row.media
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }
        Text {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.muted ? "Muted" : Math.round(row.level * 100) + "%"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
    }

    // Level and device on one line (owner, 2026-10-20, with quick settings' look): a pill track
    // in the stream's hue with a round knob (click or drag sets it, the wheel steps 5%), then the
    // device as a small pill; a click on it lists the devices under it as rounded rows, the one
    // in use tinted.
    readonly property color hue: recording ? Theme.hue1 : Theme.hue6
    readonly property color lift: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)) // on the apps card
    readonly property color liftHover: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.18))
    Item {
        width: parent.width
        height: 28
        Item {
            id: track
            width: parent.width - devicePill.width - 12
            height: parent.height
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: row.lift
                Rectangle {
                    visible: !row.muted
                    width: Math.max(height, parent.width * row.level)
                    height: parent.height
                    radius: 4
                    color: row.hue
                }
            }
            Rectangle { // the knob
                x: (parent.width - width) * (row.muted ? 0 : Math.min(row.level, 1))
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: Theme.fg
            }
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => row.setLevel(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) row.setLevel(mouse.x / width) }
                onWheel: wheel => row.setLevel(row.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
        Rectangle { // the device in use
            id: devicePill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(pillRow.implicitWidth + 20, 130)
            height: 24
            radius: height / 2
            color: row.picking ? Qt.tint(Edge.fill, Qt.rgba(row.hue.r, row.hue.g, row.hue.b, 0.22))
                : pillHover.containsMouse ? row.liftHover : row.lift
            Row {
                id: pillRow
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.recording ? Icons.microphone : Icons.speakerHigh
                    font.family: Icons.regular
                    font.pixelSize: 12
                    color: row.hue
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 130 - 20 - 18)
                    elide: Text.ElideRight
                    text: row.current ? (row.current.nickname || row.current.description) : "Default"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: Theme.fg
                }
            }
            MouseArea {
                id: pillHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: row.picking = !row.picking
            }
        }
    }
    Column { // the devices, while picking
        visible: row.picking
        width: parent.width
        spacing: 4
        topPadding: 4
        Repeater {
            model: row.picking ? [null].concat(row.devices) : []
            Rectangle {
                required property var modelData
                readonly property bool chosen: modelData === row.current
                width: row.width
                height: 32
                radius: 8
                color: chosen ? Qt.tint(Edge.fill, Qt.rgba(row.hue.r, row.hue.g, row.hue.b, pickHover.containsMouse ? 0.25 : 0.15))
                    : pickHover.containsMouse ? row.liftHover : row.lift
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    elide: Text.ElideRight
                    text: parent.modelData ? (parent.modelData.nickname || parent.modelData.description) : "Default"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: parent.chosen ? row.hue : Theme.fg
                }
                MouseArea {
                    id: pickHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Sound.route(row.node, parent.modelData)
                        row.picking = false
                    }
                }
            }
        }
    }
}
