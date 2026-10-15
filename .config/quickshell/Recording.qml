pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording, shared by the bar and the island (owner's request, 2026-10-15).
// ~/.local/bin/screen-record runs gpu-screen-recorder and writes
// $XDG_RUNTIME_DIR/recording/state.json while recording; it pings this over IPC
// (qs ipc call recording refresh) after every change. The settings (mic, system sound, separate
// tracks, fps, quality) are saved in ~/.local/state/recording/settings.json and used by every
// recording, SUPER+R included.
Singleton {
    id: root
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/screen-record"
    readonly property string settingsPath: Quickshell.env("HOME") + "/.local/state/recording/settings.json"

    property var info: null // state.json while recording, else null
    readonly property bool active: info !== null
    readonly property bool paused: active && info.paused
    property int elapsed: 0 // seconds, paused time left out
    property string size: ""
    property bool micSetting: true
    property bool systemSetting: true
    property bool separateSetting: false
    property int fpsSetting: 60
    property string qualitySetting: "very_high"
    readonly property var qualities: [
        { value: "medium", label: "Medium" }, { value: "high", label: "High" },
        { value: "very_high", label: "Very high" }, { value: "ultra", label: "Ultra" },
    ]
    function qualityLabel(value) {
        const q = qualities.find(q => q.value === value)
        return q ? q.label : value
    }

    function start() { run("start") }
    function stop() { run("stop") }
    function pause() { run("pause") }
    function run(arg) {
        runner.command = [script, arg]
        runner.running = true
    }
    // Change one setting and save them all.
    function set(key, value) {
        if (key === "mic") micSetting = value
        else if (key === "system") systemSetting = value
        else if (key === "separate") separateSetting = value
        else if (key === "fps") fpsSetting = value
        else if (key === "quality") qualitySetting = value
        saver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh",
            settingsPath, JSON.stringify({ mic: micSetting, system: systemSetting,
                separate: separateSetting, fps: fpsSetting, quality: qualitySetting })]
        saver.running = true
    }
    function tick() {
        if (!active)
            return
        const now = Date.now()
        const pausedNow = info.paused ? now - info.pausedAt : 0
        elapsed = Math.max(0, Math.floor((now - info.started - info.pausedTotal - pausedNow) / 1000))
    }

    Process { id: runner }
    Process { id: saver }

    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/recording/state.json"
        printErrors: false
        onLoaded: {
            try { root.info = JSON.parse(text()) } catch (err) { root.info = null }
            root.tick()
        }
        onLoadFailed: root.info = null
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                root.micSetting = s.mic !== false
                root.systemSetting = s.system !== false
                root.separateSetting = s.separate === true
                root.fpsSetting = [30, 60, 120, 144].indexOf(s.fps) >= 0 ? s.fps : 60
                root.qualitySetting = root.qualities.some(q => q.value === s.quality) ? s.quality : "very_high"
            } catch (err) {}
        }
    }

    Timer { // the clock while recording
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        onTriggered: root.tick()
    }

    Timer { // the file size, every two seconds
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.active
        onTriggered: if (!sizer.running) sizer.running = true
    }
    Process {
        id: sizer
        command: ["stat", "-c", "%s", root.active ? root.info.file : "/dev/null"]
        stdout: StdioCollector {
            id: sizeOut
            onStreamFinished: {
                const bytes = Number(sizeOut.text.trim())
                root.size = bytes > 0 ? (bytes / 1048576).toFixed(1) + " MB" : "0 MB"
            }
        }
    }

    IpcHandler {
        target: "recording"
        function refresh(): void { stateFile.reload() }
    }
}
