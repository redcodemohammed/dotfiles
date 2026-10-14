pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The shell's one notification server (org.freedesktop.Notifications).
// entries is the inbox, newest first: a copy of each notification's text plus
// its arrival time, and the live object while the sender keeps it open.
// unread counts arrivals since the inbox was last opened.
Singleton {
    id: root

    property int unread: 0
    property bool dnd: false
    property bool inboxOpen: false
    property var entries: []

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

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true
            const entry = {
                appName: notification.appName,
                appIcon: notification.appIcon,
                image: notification.image,
                summary: notification.summary,
                body: notification.body,
                urgent: notification.urgency === NotificationUrgency.Critical,
                time: new Date(),
                notification: notification,
            }
            root.entries = [entry, ...root.entries]
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
