pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Island state machine (island spec + design canvas "Desktop test").
// One state at a time: transient > recording > media > nothing.
// A transient ends on its own timer; expanding stops the timer; closing an expanded
// transient dismisses it. One transient waits in the queue while another is expanded.
// ("transient" is a reserved word in QML, so the current one is held in `active`.)
Singleton {
    id: root

    // [compact w, h, expanded w, h]. Notification has no compact form: it opens expanded.
    readonly property var sizes: ({
        media:   [280, 24, 440, 256],
        notify:  [0,   0,  360, 232],
        volume:  [260, 24, 320, hasBrightness ? 148 : 116], // design draws 140 and clips the 4th row
        brightness: [260, 24, 320, 148], // compact: sun and level; expanded: the volume panel
        record:  [240, 24, 340, 172],
        battery: [260, 24, 340, 148],
        build:   [320, 24, 440, 192],
    })
    readonly property var timeouts: ({ notify: 8000, volume: 2500, brightness: 2500, battery: 3000, build: 6000 })

    property var active: null // current transient: { kind, data, persistent }
    property var queued: null
    property bool recording: false
    property bool media: false
    property bool expanded: false

    // Backlight level 0-1 (laptop panel); -1 until read, and on hardware without a backlight.
    property real brightness: -1
    readonly property bool hasBrightness: brightness >= 0
    property bool brightnessStarted: false // the first read only sets the level, no island
    property bool brightnessPending: false // a change event came in while a read was running

    function readBrightness() {
        if (brightnessRead.running)
            brightnessPending = true
        else
            brightnessRead.running = true
    }

    readonly property string kind: active ? active.kind
        : recording ? "record"
        : media ? "media"
        : ""
    readonly property bool open: expanded || kind === "notify"
    readonly property var size: {
        const s = sizes[kind]
        if (!s) return [0, 0]
        return open ? [s[2], s[3]] : [s[0], s[1]]
    }

    // A new transient. persistent: no timer (urgent notification, critical battery, failed build).
    function push(kind, data, persistent) {
        const t = { kind: kind, data: data, persistent: !!persistent }
        // Same kind already showing (e.g. holding a volume key): refresh it, never queue it.
        if (active && active.kind === kind) {
            active = t
            if (t.persistent)
                timer.stop() // e.g. battery turning critical: it stays now
            else if (!expanded && timeouts[kind])
                timer.restart()
            return
        }
        if (active && open) {
            queued = t // queue one while something is open (a notification opens by itself)
            return
        }
        show(t)
    }

    function show(t) {
        active = t
        expanded = false
        timer.stop()
        if (!t.persistent && timeouts[t.kind])
            timer.start()
    }

    function next() {
        active = null
        expanded = false
        timer.stop()
        if (queued) {
            const q = queued
            queued = null
            show(q)
        }
    }

    function expand() {
        expanded = true
        timer.stop() // expanding cancels the timer
    }

    // Chevron. Expanded transient: dismiss. Expanded media or recording: back to compact.
    function collapse() {
        if (active)
            next()
        else
            expanded = false
    }

    // Volume: any change of the default output's volume or mute.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() { root.push("volume", {}, false) }
        function onMutedChanged() { root.push("volume", {}, false) }
    }

    // Battery (UPower): plug and unplug show it for 3 s; dropping to 20% on battery (UPower's own
    // "low" level) shows it once; 10% or less on battery stays with a red border until dismissed
    // (it comes back at the next percent) or plugged in.
    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool hasBattery: batteryDevice.ready && batteryDevice.isLaptopBattery
    readonly property int batteryLevel: Math.round(batteryDevice.percentage * 100) // percentage is 0-1
    readonly property bool batteryCritical: UPower.onBattery && batteryLevel <= 10
    readonly property bool pluggedIn: !UPower.onBattery
    property bool batteryLowShown: false

    onPluggedInChanged: {
        if (!hasBattery)
            return
        batteryLowShown = false
        push("battery", {}, batteryCritical)
    }
    onBatteryLevelChanged: {
        if (!hasBattery || !UPower.onBattery)
            return
        if (batteryCritical) {
            if (!(active && active.kind === "battery" && active.persistent))
                push("battery", {}, true)
        } else if (batteryLevel <= 20 && !batteryLowShown) {
            batteryLowShown = true
            push("battery", {}, false)
        }
    }

    // Power profile (power-profiles-daemon, which follows Fn+Q through the firmware platform
    // profile): any switch shows the battery pill with the new profile for 3 s. Changes in the
    // first seconds after start are the initial D-Bus read, not a switch.
    readonly property int powerProfile: PowerProfiles.profile
    onPowerProfileChanged: {
        if (!profileGrace.running)
            push("battery", { profile: true }, batteryCritical)
    }
    Timer {
        id: profileGrace
        running: true
        interval: 3000
    }

    // Brightness: the kernel sends a udev "change" event for every backlight write (keys, logind,
    // anything), so listen for those and re-read the level. No polling.
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(" change "))
                    root.readBrightness()
            }
        }
    }

    // brightnessctl -m prints "device,class,current,percent%,max". Fails without a backlight.
    Process {
        id: brightnessRead
        running: true // first read at startup
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            id: brightnessOut
            onStreamFinished: {
                const f = brightnessOut.text.trim().split(",")
                if (f.length < 5 || Number(f[4]) <= 0)
                    return
                root.brightness = Number(f[2]) / Number(f[4])
                if (root.brightnessStarted)
                    root.push("brightness", {}, false)
                root.brightnessStarted = true
            }
        }
        onExited: {
            if (root.brightnessPending) {
                root.brightnessPending = false
                Qt.callLater(() => brightnessRead.running = true)
            }
        }
    }

    Timer {
        id: timer
        interval: root.active ? (root.timeouts[root.active.kind] ?? 0) : 0
        onTriggered: root.next()
    }

    // Test hook until the real sources are wired:
    //   qs ipc call island test volume|brightness|battery|build|notify|buildfail
    //   qs ipc call island test media|record   (toggles the persistent states)
    //   qs ipc call island expand|collapse|clear
    IpcHandler {
        target: "island"
        function test(kind: string): void {
            if (kind === "media") root.media = !root.media
            else if (kind === "record") root.recording = !root.recording
            else if (kind === "buildfail") root.push("build", { failed: true }, true)
            else root.push(kind, {}, false)
        }
        // Build hook (bin/island-build). Failure persists with a red border until dismissed.
        function build(ok: bool, command: string, project: string, meta: string, lines: string, window: string): void {
            root.push("build", {
                failed: !ok,
                title: ok ? command + " · " + project : "Build failed · " + project,
                meta: meta,
                lines: lines.split("\n").slice(-4),
                window: window,
            }, !ok)
        }
        function state(): string {
            return JSON.stringify({ kind: root.kind, open: root.open, expanded: root.expanded,
                                    queued: root.queued ? root.queued.kind : null, timer: timer.running })
        }
        function expand(): void { root.expand() }
        function collapse(): void { root.collapse() }
        function clear(): void {
            root.queued = null
            root.next()
            root.media = false
            root.recording = false
        }
    }
}
