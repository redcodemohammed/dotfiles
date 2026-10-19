pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The tools panel's shared side (owner, 2026-10-17): SUPER + X opens it on the focused screen
// (`qs ipc call tools toggle`); each bar's ToolsPanel listens for its own screen's name.
// Step 2: runs the screen tools (.local/bin/pick-colour, screen-ocr, keep-awake), keeps the
// keep-awake state (the bar's wrench lights up while it is on; its switch is in quick settings)
// and the recent colours.
Singleton {
    id: root
    signal panelRequested(string screen)
    signal localhostRequested(string screen, int port) // the panel's Localhost view, that server open

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    property bool keepAwake: false
    property var colours: [] // newest first, up to 8

    function pickColour() { pickDelay.restart() }
    Timer { // the panel closes first: hyprpicker freezes the screen as it starts
        id: pickDelay
        interval: 150
        onTriggered: picker.running = true
    }
    function readText() { Quickshell.execDetached([bin + "screen-ocr"]) }
    function setKeepAwake(on) {
        keepAwake = on
        Quickshell.execDetached([bin + "keep-awake", on ? "on" : "off"])
    }
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]) }

    // Step 3, web dev tools. clip(action): .local/bin/clip-tool on the clipboard; its line (or
    // its error) comes back through clipDone for the panel's note.
    // `failed` names the action that failed last, for the panel's red button ("" once another
    // runs or the panel closes).
    signal clipDone(string message, bool ok)
    signal jwtDecoded(var header, var payload) // Decode JWT worked: the panel's JWT view
    property string failed: ""
    function clip(action) {
        if (clipper.running) return
        failed = ""
        clipper.action = action
        clipper.command = [bin + "clip-tool", action].concat(action === "jwt" ? ["--show"] : [])
        clipper.running = true
    }
    Process {
        id: clipper
        property string action
        stdout: StdioCollector { id: clipOut }
        stderr: StdioCollector { id: clipErr }
        onExited: (code) => {
            root.failed = code === 0 ? "" : action
            let message = clipOut.text.trim()
            if (code === 0 && action === "jwt") { // --show: {message, header, payload}
                try {
                    const d = JSON.parse(message)
                    message = d.message
                    root.jwtDecoded(d.header, d.payload)
                } catch (err) {}
            }
            root.clipDone(code === 0 ? message : clipErr.text.trim() || "Failed", code === 0)
            if (code === 0)
                root.peek()
        }
    }

    // What the clipboard holds (clip-tool peek), read when the panel opens and after each
    // transform: { kind, preview: [lines], size }. The preview is only for a JWT's header, JSON
    // and URL-encoded text (owner, 2026-10-20), never plain text or base64.
    property var clipboard: ({ kind: "", preview: [], size: 0 })
    function peek() { if (!peeker.running) peeker.running = true }
    Process {
        id: peeker
        command: [root.bin + "clip-tool", "peek"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.clipboard = JSON.parse(text) } catch (err) { root.clipboard = { kind: "", preview: [], size: 0 } }
            }
        }
    }

    // The values the panel's Generate list shows, so a click copies exactly what is on screen
    // (owner, 2026-10-20): a UUID from clip-tool (a new one after each copy) and its lorem ipsum.
    // The times are worked out in the panel, live.
    property string uuid: ""
    property string lorem: ""
    function freshUuid() { if (!uuidMaker.running) uuidMaker.running = true }
    Process {
        id: uuidMaker
        running: true
        command: [root.bin + "clip-tool", "uuid", "--stdout"]
        stdout: StdioCollector { onStreamFinished: root.uuid = text.trim() }
    }
    Process {
        running: true
        command: [root.bin + "clip-tool", "lorem", "--stdout"]
        stdout: StdioCollector { onStreamFinished: root.lorem = text.trim() }
    }

    // Localhost QR: the dev servers (dev-ports, read when the panel opens and by its Localhost
    // view), then lan-qr for one.
    property var ports: [] // [{port, name, pid, folder, lan}]
    property string qrUrl: ""
    property string qrImage: ""
    function readPorts() { portReader.running = true }
    function showQr(port) {
        qrUrl = ""
        qrImage = ""
        qrMaker.command = [bin + "lan-qr", String(port)]
        qrMaker.running = true
    }
    function hideQr() { qrUrl = ""; qrImage = "" }
    Process {
        id: portReader
        command: [root.bin + "dev-ports"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.ports = JSON.parse(text) } catch (err) { root.ports = [] }
            }
        }
    }
    Process {
        id: qrMaker
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\t")
                if (parts.length === 2) {
                    root.qrUrl = parts[0]
                    root.qrImage = "file://" + parts[1] + "?" + Date.now() // a new image each time
                }
            }
        }
    }

    Process { // runs while the screen is frozen for picking; the list changes when it ends
        id: picker
        command: [root.bin + "pick-colour"]
        onExited: colourFile.reload()
    }
    FileView {
        id: colourFile
        path: Quickshell.env("HOME") + "/.local/state/picked-colours"
        printErrors: false
        onLoaded: root.colours = text().split("\n").filter(c => /^#[0-9a-f]{6}$/.test(c))
    }
    Process { // keep-awake outlasts reloads (its PID file): read it back once
        running: true
        command: [root.bin + "keep-awake", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.keepAwake = text.trim() === "on"
        }
    }

    IpcHandler {
        target: "tools"
        function toggle(): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                root.panelRequested(monitor.name)
        }
        // qs ipc call tools qr 5173: the panel on the focused screen at its Localhost view, with
        // that server's QR
        function qr(port: int): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                root.localhostRequested(monitor.name, port)
        }
    }
}
