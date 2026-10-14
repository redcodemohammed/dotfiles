pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The shell's one notification server (org.freedesktop.Notifications).
// entries is the inbox, newest first: a copy of each notification's text plus
// its arrival time, and the live object while the sender keeps it open.
// unread counts arrivals since the inbox was last opened.
// The inbox is saved to the state dir (plain text, capped at 200) and restored on start.
Singleton {
    id: root

    property int unread: 0
    property bool dnd: false
    property bool inboxOpen: false
    property var entries: []
    readonly property int historyCap: 200

    // Notifications currently shown as popups, newest first. Leaving this list
    // only hides the popup; the entry stays in the inbox.
    property var popups: []

    function hidePopup(notification) {
        popups = popups.filter(n => n !== notification)
    }

    function setInbox(open) {
        inboxOpen = open
        if (open)
            unread = 0
    }

    // Enter: run the sender's default action, if it is still listening.
    function invoke(entry) {
        const n = entry.notification
        const action = n ? n.actions.find(a => a.identifier === "default") : null
        if (!action)
            return false
        action.invoke()
        return true
    }

    // X: drop from the inbox and close it at the sender.
    function dismiss(entry) {
        entries = entries.filter(e => e !== entry)
        if (entry.notification)
            entry.notification.dismiss()
    }

    function clearAll() {
        for (const e of entries)
            if (e.notification)
                e.notification.dismiss()
        entries = []
    }

    // Persistence. Live notification objects and image hints are not saved.
    FileView {
        id: store
        path: Quickshell.statePath("notifications.json")
        blockLoading: true
        atomicWrites: true
        printErrors: false // the file is missing on first run
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: store.setText(JSON.stringify(root.entries.map(e => ({
            id: e.id,
            appName: e.appName,
            appIcon: e.appIcon,
            summary: e.summary,
            body: e.body,
            urgent: e.urgent,
            time: e.time.toISOString(),
        }))))
    }

    onEntriesChanged: saveTimer.restart()

    Component.onCompleted: {
        try {
            const saved = JSON.parse(store.text() || "[]")
            entries = saved.map(e => Object.assign(e, { image: "", time: new Date(e.time), notification: null }))
        } catch (err) {
            console.warn("notifications: could not read history:", err)
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true

            // Carried over from before a reload: reattach to its saved entry, nothing new.
            if (notification.lastGeneration) {
                const known = root.entries.find(e => e.id === notification.id && !e.notification)
                if (known) {
                    known.notification = notification
                    notification.closed.connect(() => { known.notification = null })
                    return
                }
            }

            const entry = {
                id: notification.id,
                appName: notification.appName,
                appIcon: notification.appIcon,
                image: notification.image,
                summary: notification.summary,
                body: notification.body,
                urgent: notification.urgency === NotificationUrgency.Critical,
                time: new Date(),
                notification: notification,
            }
            root.entries = [entry, ...root.entries].slice(0, root.historyCap)
            if (!root.inboxOpen)
                root.unread += 1
            notification.closed.connect(() => {
                root.hidePopup(notification)
                entry.notification = null // sender closed it; the inbox keeps the copy
            })
            if (!root.dnd && !root.inboxOpen)
                root.popups = [notification, ...root.popups]
        }
    }

    // SUPER + I runs: qs ipc call inbox toggle
    IpcHandler {
        target: "inbox"
        function toggle(): void { root.setInbox(!root.inboxOpen) }
    }
}
