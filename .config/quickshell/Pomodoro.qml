pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Pomodoro timer (owner, 2026-10-17). Focus 25 min, short break 5, every 4th break long (15);
// all three are set in the panel. A phase that ends waits for the owner: the island asks
// "Start break?" / "Back to focus?" and nothing runs on its own. Do Not Disturb is on during a
// focus phase (running or paused) and goes back to what it was after. Today's finished focus
// sessions are counted. State lives in ~/.local/state/pomodoro.json with the phase's end time
// (not a countdown), so a Quickshell reload or a new login keeps a running timer exact.
//   SUPER + P: qs ipc call pomodoro toggle   (start / pause / resume / start the waiting phase)
Singleton {
    id: root

    // idle | focus | short | long
    property string phase: "idle"
    property bool running: false
    property double endsAt: 0      // while running: when the phase ends (ms since epoch)
    property double remaining: 0   // while paused: ms left
    property string waiting: ""    // a phase that ended and the one it offers: "short" | "long" | "focus"
    property int cycle: 0          // focus sessions finished in this round of `every`
    property int today: 0
    property string day: ""
    property bool dndBefore: false // DND as it was before focus turned it on
    property var settings: ({ focus: 25, short: 5, long: 15, every: 4 })

    property double now: Date.now()
    readonly property double left: running ? Math.max(0, endsAt - now) : remaining
    readonly property bool active: phase !== "idle" || waiting !== ""
    readonly property string clock: {
        const s = Math.ceil(left / 1000)
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
    }
    readonly property string phaseName: phase === "focus" ? "Focus" : phase === "short" ? "Short break"
        : phase === "long" ? "Long break" : "Pomodoro"
    function minutes(p) { return p === "focus" ? settings.focus : p === "short" ? settings.short : settings.long }
    function label(p) { return p === "focus" ? "focus" : p === "short" ? "short break" : "long break" }

    function begin(p) {
        if (p === "focus" && phase !== "focus") {
            dndBefore = Notifs.dnd
            Notifs.dnd = true
        } else if (p !== "focus" && phase === "focus") {
            Notifs.dnd = dndBefore
        }
        phase = p
        waiting = ""
        remaining = minutes(p) * 60000
        endsAt = Date.now() + remaining
        running = true
        save()
    }
    function pause() {
        if (!running) return
        remaining = Math.max(0, endsAt - Date.now())
        running = false
        save()
    }
    function resume() {
        if (running || phase === "idle") return
        endsAt = Date.now() + remaining
        running = true
        save()
    }
    // SUPER + P and the panel's main button.
    function toggle() {
        if (waiting !== "") {
            IslandState.dropPomodoro()
            begin(waiting)
        }
        else if (phase === "idle") begin("focus")
        else if (running) pause()
        else resume()
    }
    // Running: the phase ends now (a skipped focus session isn't counted). Waiting: an offered
    // break is skipped (focus starts), an offered focus is declined (the timer stops).
    function skip() {
        if (waiting === "focus") {
            waiting = ""
            IslandState.dropPomodoro()
            save()
        } else if (waiting !== "") {
            IslandState.dropPomodoro()
            begin("focus")
        } else if (phase !== "idle") {
            finish(false)
        }
    }
    function reset() {
        if (phase === "focus") Notifs.dnd = dndBefore
        phase = "idle"
        running = false
        waiting = ""
        remaining = 0
        cycle = 0
        IslandState.dropPomodoro()
        save()
    }

    // A phase ran out (or was skipped): wait for the owner, and say so in the island.
    function finish(counted) {
        const ended = phase
        if (ended === "focus") {
            Notifs.dnd = dndBefore
            if (counted) {
                rollDay()
                today++
                cycle++
            }
            waiting = cycle > 0 && cycle % settings.every === 0 ? "long" : "short"
            if (waiting === "long") cycle = 0
        } else {
            waiting = "focus"
        }
        phase = "idle"
        running = false
        remaining = 0
        save()
        IslandState.push("pomodoro", { ended: ended }, true)
    }

    function rollDay() {
        const d = Qt.formatDate(new Date(), "yyyy-MM-dd") // local date (toISOString is UTC: 03:00 here)
        if (d !== day) {
            day = d
            today = 0
        }
    }
    function setMinutes(p, value) {
        const s = Object.assign({}, settings)
        s[p] = Math.max(5, Math.min(120, value)) // the panel steps by 5
        settings = s
        save()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now()
            if (root.endsAt - root.now <= 0)
                root.finish(true)
        }
    }

    // --- state file ---
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/pomodoro.json"
    property bool loaded: false
    function save() {
        if (!loaded) return
        store.setText(JSON.stringify({
            phase, running, endsAt, remaining, waiting, cycle, today, day, dndBefore, settings,
        }))
    }
    FileView {
        id: store
        path: root.statePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const s = JSON.parse(text())
                root.phase = s.phase ?? "idle"
                root.running = !!s.running
                root.endsAt = s.endsAt ?? 0
                root.remaining = s.remaining ?? 0
                root.waiting = s.waiting ?? ""
                root.cycle = s.cycle ?? 0
                root.today = s.today ?? 0
                root.day = s.day ?? ""
                root.dndBefore = !!s.dndBefore
                root.settings = Object.assign({}, root.settings, s.settings ?? {})
            } catch (err) {}
            root.rollDay()
            root.loaded = true
            if (root.phase === "focus")
                Notifs.dnd = true
            if (root.waiting !== "") // ended while Quickshell was away: ask again
                IslandState.push("pomodoro", { ended: root.waiting === "focus" ? "short" : "focus" }, true)
        }
        onLoadFailed: { // first run: no file yet
            root.rollDay()
            root.loaded = true
        }
    }

    IpcHandler {
        target: "pomodoro"
        function toggle(): void { root.toggle() }
        function skip(): void { root.skip() }
        function reset(): void { root.reset() }
        function state(): string {
            return JSON.stringify({ phase: root.phase, running: root.running, clock: root.clock,
                                    waiting: root.waiting, cycle: root.cycle, today: root.today })
        }
    }
}
