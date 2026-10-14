pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
        volume:  [260, 24, 320, 140],
        record:  [240, 24, 340, 172],
        battery: [260, 24, 340, 148],
        event:   [280, 24, 340, 128],
        build:   [320, 24, 440, 192],
    })
    readonly property var timeouts: ({ notify: 8000, volume: 2500, battery: 3000, event: 6000, build: 6000 })

    property var active: null // current transient: { kind, data, persistent }
    property var queued: null
    property bool recording: false
    property bool media: false
    property bool expanded: false

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

    Timer {
        id: timer
        interval: root.active ? (root.timeouts[root.active.kind] ?? 0) : 0
        onTriggered: root.next()
    }

    // Test hook until the real sources are wired:
    //   qs ipc call island test volume|battery|event|build|notify|buildfail
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
