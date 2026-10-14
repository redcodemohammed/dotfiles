pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The shell's one notification server (org.freedesktop.Notifications).
// Every notification is kept (tracked) for the inbox. unread counts arrivals
// since the inbox was last opened; the inbox resets it (build step 8).
Singleton {
    id: root

    property int unread: 0
    property bool dnd: false
    readonly property var list: server.trackedNotifications.values

    // Notifications currently shown as popups, newest first. Leaving this list
    // only hides the popup; the notification stays in the inbox.
    property var popups: []

    function hidePopup(notification) {
        popups = popups.filter(n => n !== notification)
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true
            root.unread += 1
            notification.closed.connect(() => root.hidePopup(notification))
            if (!root.dnd)
                root.popups = [notification, ...root.popups]
        }
    }
}
