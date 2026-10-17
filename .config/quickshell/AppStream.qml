import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// One app's audio stream in the sound panel's Apps tab (owner, 2026-10-17). The app's icon
// (a click mutes it; muted: dimmed, with the slash glyph over it), its name and what it plays,
// the level in %, a slider (click, drag or scroll), and the device it uses: a click opens the
// list, Default follows the system default. Playback streams pick an output, recording ones an
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

    // Level: a track and its fill; click or drag sets it, the wheel steps 5%.
    Item {
        width: parent.width
        height: 16
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            color: Theme.border
            Rectangle {
                width: parent.width * (row.muted ? 0 : row.level)
                height: parent.height
                color: Theme.fg
            }
        }
        MouseArea {
            anchors.fill: parent
            onPressed: mouse => row.setLevel(mouse.x / width)
            onPositionChanged: mouse => { if (pressed) row.setLevel(mouse.x / width) }
            onWheel: wheel => row.setLevel(row.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    // The device: the current one, a click lists the others.
    Rectangle {
        width: parent.width
        height: 24
        color: deviceHover.containsMouse ? Theme.surfaceSelected : "transparent"
        Text {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 8
            elide: Text.ElideRight
            text: (row.recording ? "Input: " : "Output: ")
                + (row.current ? (row.current.nickname || row.current.description) : "Default")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
        MouseArea {
            id: deviceHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.picking = !row.picking
        }
    }
    Repeater {
        model: row.picking ? [null].concat(row.devices) : []
        Rectangle {
            required property var modelData
            readonly property bool chosen: modelData === row.current
            width: row.width
            height: 24
            color: pickHover.containsMouse ? Theme.surfaceSelected : "transparent"
            Rectangle {
                width: 2
                height: parent.height
                visible: parent.chosen
                color: Theme.accent
            }
            Text {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 16
                elide: Text.ElideRight
                text: parent.modelData ? (parent.modelData.nickname || parent.modelData.description) : "Default"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fg
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
