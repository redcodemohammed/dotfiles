pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The workspaces saved to open again at login (owner, 2026-10-20): .local/bin/workspace-session
// keeps their IDs in its index.json, watched here so the bar's pills (WorkspaceSquare.qml) show a
// dot on them. A right click on a pill saves it, or forgets its save when it is empty.
Singleton {
    id: root
    property var ids: []

    function has(id) {
        return ids.indexOf(id) >= 0
    }
    // number: the pill's own (1 to N), for the notification
    function save(id, number) {
        Quickshell.execDetached(["workspace-session", "save", String(id), String(number)])
    }
    function forget(id, number) {
        Quickshell.execDetached(["workspace-session", "forget", String(id), String(number)])
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
