pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The workspaces saved to open again at login (owner, 2026-10-20): .local/bin/workspace-session
// keeps their IDs in its index.json, watched here so the bar's pills (WorkspaceSquare.qml) show a
// bookmark on them. A right click on a pill toggles its save: saved, updated if its windows changed,
// else forgotten (workspace-session toggle decides, comparing with the saved file).
Singleton {
    id: root
    property var ids: []

    function has(id) {
        return ids.indexOf(id) >= 0
    }
    // number: the pill's own (1 to N), for the notification
    function toggle(id, number) {
        Quickshell.execDetached(["workspace-session", "toggle", String(id), String(number)])
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/workspace-session/index.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text())
                root.ids = Array.isArray(list) ? list : []
            } catch (err) {
                root.ids = []
            }
        }
        onLoadFailed: root.ids = []
    }
}
