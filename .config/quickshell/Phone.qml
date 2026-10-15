pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The phone bridge (owner's design "Phone bridge", 2026-10-15). kcd, a headless KDE Connect daemon
// (AUR kcd 1.22, user socket kcd.socket; pairing code checked before install), is paired with the
// owner's phone. `kcd watch --json` streams its events as NDJSON ({type, deviceId, payload}), a
// state.snapshot first on every watch connection; pairing changes restart the watch for a fresh
// one. This keeps the paired phone's name, connection and battery, and its notifications (newest
// first, kept in $XDG_RUNTIME_DIR across shell reloads; the phone resends its current ones on
// reconnect) for the bar block and the panel.
Singleton {
    id: root
    property string deviceId: ""
    property string name: ""
    property bool paired: false
    property bool connected: false
    property int battery: -1 // percent, -1 unknown
    property bool charging: false
    property var notifications: [] // { id, app, title, text, replyId, time, unread }
    readonly property int unread: notifications.filter(n => n.unread).length

    function hhmm() {
        const d = new Date()
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
    }
    function setNotifications(list) {
        notifications = list
        store.setText(JSON.stringify(list))
    }
    function markRead(id) {
        setNotifications(notifications.map(n => n.id === id ? Object.assign({}, n, { unread: false }) : n))
    }
    function clearAll() { // this list only; the phone keeps its notifications
        setNotifications([])
    }
    function dismiss(id) { // on the phone too
        setNotifications(notifications.filter(n => n.id !== id))
        Quickshell.execDetached(["kcd", "dismiss", deviceId, id])
    }
    function reply(replyId, text) {
        Quickshell.execDetached(["kcd", "reply", deviceId, replyId, text])
    }
    // kcd has no disconnect (a paired phone always comes back); Reconnect announces the laptop for
    // 20 s so the phone dials in at once instead of waiting for kcd's back-off. Advertise-only mode
    // never accepts a pairing.
    function reconnect() {
        if (!advertiser.running)
            advertiser.running = true
    }
    Process {
        id: advertiser
        command: ["timeout", "20", "kcd", "pair", "--advertise-only"]
    }
    // Settings (the panel's Settings tab), kept in ~/.local/state/phone/settings.json. kcd's side
    // (plugins, battery alerts, muted apps as "silent") is written by ~/.local/bin/kcd-settings 1.5 s
    // after the last change, which restarts kcd. Reply from desktop is the panel's own. Muted apps
    // are dropped from the Inbox; every app seen gets a switch (knownApps).
    readonly property string settingsPath: Quickshell.env("HOME") + "/.local/state/phone/settings.json"
    property var settings: ({ notification: true, clipboard: true, share: true, mousepad: true,
                              batteryAlerts: true, replyFromDesktop: true, mutedApps: [], knownApps: [] })
    property bool applying: false
    function setSetting(key, value) {
        const s = Object.assign({}, settings)
        s[key] = value
        settings = s
        saveSettings(key !== "replyFromDesktop" && key !== "knownApps")
    }
    function toggleApp(app) {
        const muted = settings.mutedApps.indexOf(app) >= 0
        setSetting("mutedApps", muted ? settings.mutedApps.filter(a => a !== app) : settings.mutedApps.concat([app]))
        if (!muted)
            setNotifications(notifications.filter(n => n.app !== app))
    }
    function saveSettings(toKcd) {
        settingsSaver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh",
            settingsPath, JSON.stringify(settings)]
        settingsSaver.running = true
        if (toKcd)
            applyTimer.restart()
    }
    Process { id: settingsSaver }
    Timer {
        id: applyTimer
        interval: 1500
        onTriggered: {
            root.applying = true
            applier.command = [Quickshell.env("HOME") + "/.local/bin/kcd-settings", root.settingsPath]
            applier.running = true
        }
    }
    Process {
        id: applier
        stderr: StdioCollector { id: applyErr }
        onExited: code => {
            root.applying = false
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Phone", "-u", "critical", "Phone settings not applied",
                    applyErr.text.trim() || "kcd-settings failed"])
        }
    }
    FileView {
        path: root.settingsPath
        printErrors: false
        onLoaded: {
            try {
                root.settings = Object.assign({}, root.settings, JSON.parse(text()))
            } catch (err) {}
        }
    }
    // An incoming call (kcd telephony): { name, number, muted } while the phone rings. kcd can mute
    // the ringer but not reject (the Android app can't).
    property var call: null
    function muteCall() {
        Quickshell.execDetached(["kcd", "call", "mute", deviceId])
        if (call)
            call = Object.assign({}, call, { muted: true })
    }

    function unpair() {
        Quickshell.execDetached(["kcd", "unpair", deviceId])
    }

    // Actions (the panel's Actions tab). kcd can't stop a ring (touch the phone) or send a link
    // (Send clipboard covers it); the phone's clipboard lands in yours without an event.
    function ring() {
        Quickshell.execDetached(["kcd", "findmyphone", deviceId])
    }
    function sendClipboard() {
        Quickshell.execDetached(["kcd", "clipboard", deviceId])
    }
    function pickAndSend() { // a file picker, then kcd share
        if (!picker.running)
            picker.running = true
    }
    Process {
        id: picker
        command: ["zenity", "--file-selection", "--title=Send to phone"]
        stdout: StdioCollector {
            id: picked
            onStreamFinished: {
                const f = picked.text.trim()
                if (f !== "")
                    root.sendFile(f)
            }
        }
    }
    function sendFile(path) {
        addTransfer({ name: path.split("/").pop(), up: true, current: 0, total: 0, state: "sending", error: "" })
        Quickshell.execDetached(["kcd", "share", deviceId, path])
    }
    // Transfers, newest first, the last five: { name, up, current, total, state, error }, state
    // sending / receiving / done / failed. Received files land in ~/Downloads/kcd (kcd's default).
    property var transfers: []
    function addTransfer(t) {
        transfers = [t].concat(transfers.filter(x => x.name !== t.name)).slice(0, 5)
    }
    function changeTransfer(name, change, fallback) {
        const i = transfers.findIndex(x => x.name === name)
        if (i < 0) {
            addTransfer(Object.assign({ name: name, up: false, current: 0, total: 0, state: "receiving", error: "" },
                fallback, change))
            return
        }
        const list = transfers.slice()
        list[i] = Object.assign({}, list[i], change)
        transfers = list
    }

    // A verification code in a notification: a 4-8 digit number next to a code-ish word.
    function codeIn(text) {
        if (!/code|otp|verif|passcode|pin|رمز|كود/i.test(text))
            return ""
        const m = text.match(/(?:^|\D)(\d{4,8})(?!\d)/)
        return m ? m[1] : ""
    }

    function handle(line) {
        let e
        try {
            e = JSON.parse(line)
        } catch (err) {
            return
        }
        const p = e.payload || {}
        const ours = e.deviceId === undefined || e.deviceId === deviceId
        switch (e.type) {
        case "state.snapshot": {
            const d = (p.devices || []).find(d => d.state === "PAIRED") ?? null
            deviceId = d ? d.id : ""
            name = d ? d.name : ""
            paired = d !== null
            connected = d !== null && d.connected
            battery = d && d.battery ? d.battery.charge : -1
            charging = d && d.battery ? d.battery.charging : false
            break
        }
        case "device.connected":
            if (ours)
                connected = true // the battery comes with the phone's next report (kcd caches no reading)
            break
        case "device.disconnected":
            if (ours) {
                connected = false
                call = null
            }
            break
        case "telephony.ringing":
            if (ours)
                call = { name: p.contactName || p.phoneNumber || "Unknown caller", number: p.phoneNumber || "", muted: false }
            break
        case "telephony.canceled":
        case "telephony.missed":
            if (ours)
                call = null
            break
        case "battery.update":
            if (ours) {
                battery = p.charge
                charging = p.charging
            }
            break
        case "notification":
            if (ours && settings.knownApps.indexOf(p.appName || "") < 0 && (p.appName || "") !== "")
                setSetting("knownApps", settings.knownApps.concat([p.appName]))
            if (ours && settings.mutedApps.indexOf(p.appName || "") < 0) {
                const n = { id: p.id, app: p.appName || "", title: p.title || "", text: p.text || "",
                            replyId: p.requestReplyId || "", time: hhmm(), unread: true }
                setNotifications([n].concat(notifications.filter(x => x.id !== p.id)))
            }
            break
        case "notification.canceled":
            if (ours)
                setNotifications(notifications.filter(x => x.id !== p.id))
            break
        case "share.progress":
            if (ours)
                changeTransfer(p.file, { current: p.current, total: p.total }, { state: "receiving" })
            break
        case "share.complete":
            if (ours)
                changeTransfer(p.file, { state: p.success === false ? "failed" : "done", error: p.error || "" }, {})
            break
        case "device.added":
        case "device.removed":
        case "pair.accepted":
        case "pair.rejected":
            restartWatch.start() // a fresh snapshot
            break
        }
    }

    Process {
        id: watch
        running: true
        command: ["kcd", "watch", "--json"]
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        onExited: restartWatch.start() // kcd missing or the daemon down: try again
    }
    Timer {
        id: restartWatch
        interval: 3000
        onTriggered: {
            watch.running = false
            watch.running = true
        }
    }

    // qs ipc call phone open: the panel on the focused screen's bar (Bar.qml listens).
    // qs ipc call phone test: two sample notifications (test hook; ids start with "test-").
    signal panelRequested(string screen)
    IpcHandler {
        target: "phone"
        function open(): void {
            const m = Hyprland.focusedMonitor
            if (m)
                root.panelRequested(m.name)
        }
        function test(): void {
            root.setNotifications([
                { id: "test-1", app: "Telegram", title: "Sara", text: "Can you send the logo files when you get a minute?",
                  replyId: "test-reply", time: root.hhmm(), unread: true },
                { id: "test-2", app: "Messages", title: "Zain", text: "Your verification code is 482913. Do not share it.",
                  replyId: "", time: root.hhmm(), unread: true },
            ].concat(root.notifications))
        }
        function testCall(): void {
            root.call = { name: "Bahaa", number: "+964 770 123 4567", muted: false }
        }
        function endCall(): void {
            root.call = null
        }
        function clearTest(): void {
            root.setNotifications(root.notifications.filter(n => !String(n.id).startsWith("test-")))
        }
    }

    FileView {
        id: store
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/phone-notifications.json"
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text())
                if (Array.isArray(list))
                    root.notifications = list
            } catch (err) {}
        }
    }
}
