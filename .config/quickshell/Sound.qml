pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Per-app audio for the sound panel's Apps tab (owner, 2026-10-17): the apps' streams, the
// devices they can use, and which device each one is pinned to. Pinning writes WirePlumber's
// target.object into PipeWire's default metadata; `targets` (stream id -> device node.name) is
// read back from `pw-metadata` when the tab opens and kept up to date by route().
Singleton {
    id: root
    readonly property var streams: (Pipewire.nodes?.values ?? []).filter(n => n.isStream && n.audio)
    readonly property var playing: streams.filter(n => (n.properties["media.class"] ?? "").startsWith("Stream/Output"))
    readonly property var recording: streams.filter(n => (n.properties["media.class"] ?? "").startsWith("Stream/Input"))
    readonly property var outputs: (Pipewire.nodes?.values ?? []).filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: (Pipewire.nodes?.values ?? []).filter(n => n.audio && !n.isSink && !n.isStream)
    property var targets: ({})

    PwObjectTracker { // binds the streams, so their volume and mute are live and writable
        objects: root.streams
    }

    function route(stream, device) {
        const t = Object.assign({}, targets)
        if (device) {
            t[stream.id] = device.name
            Quickshell.execDetached(["pw-metadata", "-n", "default", String(stream.id), "target.object", device.name])
        } else {
            delete t[stream.id]
            Quickshell.execDetached(["pw-metadata", "-n", "default", "-d", String(stream.id), "target.object"])
        }
        targets = t
    }

    function readTargets() { reader.running = true }
    Process {
        id: reader
        command: ["pw-metadata", "-n", "default"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = {}
                const re = /update: id:(\d+) key:'target\.object' value:'([^']*)'/g // no matchAll in Qt's JS
                let m
                while ((m = re.exec(text)) !== null)
                    t[m[1]] = m[2].replace(/^\{"name":"(.*)"\}$/, "$1")
                root.targets = t
            }
        }
    }
}
