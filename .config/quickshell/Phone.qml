pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
    function markAllRead() {
        if (unread > 0)
            setNotifications(notifications.map(n => Object.assign({}, n, { unread: false })))
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
                connected = true
            break
        case "device.disconnected":
            if (ours)
                connected = false
            break
        case "battery.update":
            if (ours) {
                battery = p.charge
                charging = p.charging
            }
            break
        case "notification":
            if (ours) {
                const n = { id: p.id, app: p.appName || "", title: p.title || "", text: p.text || "",
                            replyId: p.requestReplyId || "", time: hhmm(), unread: true }
                setNotifications([n].concat(notifications.filter(x => x.id !== p.id)))
            }
            break
        case "notification.canceled":
            if (ours)
                setNotifications(notifications.filter(x => x.id !== p.id))
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
