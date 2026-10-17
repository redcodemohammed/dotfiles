pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Networking

// Island state machine (island spec + design canvas "Desktop test").
// One state at a time: transient > recording > Pomodoro timer > media > nothing.
// A transient ends on its own timer; expanding stops the timer; closing an expanded
// transient dismisses it. One transient waits in the queue while another is expanded.
// ("transient" is a reserved word in QML, so the current one is held in `active`.)
Singleton {
    id: root

    // [compact w, h, expanded w, h]. Notification has no compact form: it opens expanded.
    readonly property var sizes: ({
        media:   [640, 24, 640, 172], // wide for long titles and lyric lines (owner; design 280/440); design 256 includes "Up next", which MPRIS can't fill
        notify:  [0,   0,  360, 232],
        volume:  [260, 24, 320, volumeHeight], // expanded grows with the device lists (owner)
        brightness: [260, 24, 320, volumeHeight], // compact: sun and level; expanded: the volume panel
        record:  [240, 24, 340, 172],
        recsetup: [0, 0, 340, 324], // recording setup (audio, fps, quality, Start): opens expanded
        battery: [260, 24, 340, 148],
        build:   [320, 24, 440, 192],
        connect: [260, 24, 0, 0], // Wi-Fi / Bluetooth events: compact only, a click opens the panel or bluetui
        pomodoro: [0, 0, 340, 116], // a Pomodoro phase ended (Pomodoro.qml): opens expanded, waits for an answer
        timer:   [160, 24, 340, 148], // a Pomodoro phase running or paused (IslandTimer.qml); above media (owner)
    })
    readonly property var timeouts: ({ notify: 8000, volume: 2500, brightness: 2500, battery: 3000, build: 6000, connect: 3000 })

    property var active: null // current transient: { kind, data, persistent }
    property var queued: null
    property bool recordingTest: false // test hook only
    readonly property bool recording: recordingTest || Recording.active // screen-record is running
    property bool mediaTest: false // test hook only: qs ipc call island test media
    readonly property bool media: mediaTest || (Settings.bar.islandMedia && mediaPlayer !== null) // off in the settings panel: no media state
    property bool expanded: false

    // Media (MPRIS): the playing player. After a pause it stays 30 s (owner's choice); a stop or
    // quit ends it at once. With several players, the first one playing wins.
    property var mediaPlayer: null
    readonly property var playingPlayer: Mpris.players.values.find(p => p.isPlaying) ?? null
    onPlayingPlayerChanged: updateMedia()
    Component.onCompleted: updateMedia()

    function updateMedia() {
        if (playingPlayer) {
            mediaPlayer = playingPlayer
            mediaPausedHold.stop()
        } else if (mediaPlayer && mediaPlayer.playbackState === MprisPlaybackState.Paused) {
            mediaPausedHold.restart()
        } else {
            mediaPlayer = null
        }
    }

    Timer {
        id: mediaPausedHold
        interval: 30000
        onTriggered: root.mediaPlayer = null
    }

    // Audio devices for the volume panel's lists: real outputs and inputs, not app streams.
    readonly property var audioSinks: (Pipewire.nodes?.values ?? []).filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var audioSources: (Pipewire.nodes?.values ?? []).filter(n => n.audio && !n.isSink && !n.isStream)
    // Expanded volume panel: padding 12, slider rows of 24 (8 apart), then each device list
    // (8 above it; divider, caption and rows as in IslandVolume.qml: 22 + 28 per device).
    readonly property int volumeHeight: {
        const rows = 2 + (hasBrightness ? 1 : 0)
        const list = n => 8 + 22 + 28 * n
        return 12 + rows * 24 + (rows - 1) * 8 + list(audioSinks.length) + list(audioSources.length) + 12
    }

    // The bar's record block. Recording: open its panel. Not recording: the setup panel (audio
    // choice, Start), which goes away once the recording starts.
    function showRecording() {
        queued = null
        if (Recording.active) {
            if (active)
                next() // back to the recording state underneath
            expand()
        } else {
            show({ kind: "recsetup", data: {}, persistent: true })
            expand()
        }
    }
    Connections {
        target: Recording
        function onActiveChanged() {
            if (Recording.active && root.active && root.active.kind === "recsetup")
                root.next()
        }
    }

    // The bar's volume block: open the expanded volume panel now, in place of whatever shows.
    function showVolume() {
        queued = null
        show({ kind: "volume", data: {}, persistent: false })
        expand()
    }

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
        : Pomodoro.phase !== "idle" ? "timer"
        : media ? "media"
        : ""
    readonly property bool open: expanded || kind === "notify" || kind === "pomodoro"
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

    // The Pomodoro question was answered elsewhere (SUPER + P, the panel): take it down.
    function dropPomodoro() {
        if (queued && queued.kind === "pomodoro")
            queued = null
        if (active && active.kind === "pomodoro")
            next()
    }

    function expand() {
        expanded = true
        timer.stop() // expanding cancels the timer
    }

    // A click on the compact island (Island.qml, with its screen's name). A Wi-Fi pill opens the
    // network panel on that screen's bar, a Bluetooth pill opens bluetui; the rest expand.
    function click(screen) {
        if (active && active.kind === "connect") {
            const d = active.data
            next()
            if (d.what === "wifi")
                NetState.panelRequested(screen)
            else
                Quickshell.execDetached(["alacritty", "--class", "bluetui", "-e", "bluetui"])
            return
        }
        expand()
    }

    // Wi-Fi and Bluetooth events (owner, 2026-10-15): a 260x24 pill for 3 s, like the battery's.
    // Wi-Fi connected (its name), and lost: the network dropped on its own, so not when Wi-Fi is
    // off, the hotspot starts, or the panel changed the connection in the last 15 s; a drop with a
    // new network within 2 s (switching) shows only the new one. Bluetooth: a device connected (its
    // battery when it reports one) or disconnected, not while the adapter turns off. Quiet for the
    // first 5 s, while NetworkManager and BlueZ load.
    property bool eventsReady: false
    Timer {
        running: true
        interval: 5000
        onTriggered: root.eventsReady = true
    }
    readonly property string wifiNow: NetState.wifiNet ? NetState.wifiNet.name : ""
    property string wifiLast: ""
    onWifiNowChanged: {
        const was = wifiLast
        wifiLast = wifiNow
        if (!eventsReady)
            return
        if (wifiNow !== "") {
            wifiLostWait.stop()
            push("connect", { what: "wifi", on: true, name: wifiNow }, false)
        } else if (was !== "") {
            wifiLostWait.name = was
            wifiLostWait.restart()
        }
    }
    Timer {
        id: wifiLostWait
        property string name
        interval: 2000
        onTriggered: {
            if (root.wifiNow !== "" || !Networking.wifiEnabled || NetState.hotspotOn
                    || Date.now() - NetState.userChangeAt < 15000)
                return
            root.push("connect", { what: "wifi", on: false, name: name }, false)
        }
    }
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                const a = Bluetooth.defaultAdapter
                if (!root.eventsReady || !a || a.state !== BluetoothAdapterState.Enabled)
                    return
                root.push("connect", { what: "bt", on: modelData.connected, name: modelData.name, device: modelData }, false)
            }
        }
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
            if (kind === "media") root.mediaTest = !root.mediaTest
            else if (kind === "record") root.recordingTest = !root.recordingTest
            else if (kind === "buildfail") root.push("build", { failed: true }, true)
            else if (kind === "wifi") root.push("connect", { what: "wifi", on: true, name: "Home-5G" }, false)
            else if (kind === "wifilost") root.push("connect", { what: "wifi", on: false, name: "Home-5G" }, false)
            else if (kind === "bt") root.push("connect", { what: "bt", on: true, name: "WH-1000XM4", device: null }, false)
            else if (kind === "btoff") root.push("connect", { what: "bt", on: false, name: "WH-1000XM4", device: null }, false)
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
            root.mediaTest = false
            root.recordingTest = false
        }
    }
}
