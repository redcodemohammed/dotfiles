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

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true
            root.unread += 1
        }
    }
}
