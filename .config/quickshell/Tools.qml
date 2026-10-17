pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The tools panel's shared side (owner, 2026-10-17): SUPER + X opens it on the focused screen
// (`qs ipc call tools toggle`); each bar's ToolsPanel listens for its own screen's name.
// Step 2: runs the screen tools (.local/bin/pick-colour, screen-ocr, keep-awake), keeps the
// keep-awake state (the bar's power glyph turns accent while it is on) and the recent colours.
Singleton {
    id: root
    signal panelRequested(string screen)

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
    signal clipDone(string message)
    function clip(action) {
        if (clipper.running) return
        clipper.command = [bin + "clip-tool", action]
        clipper.running = true
    }
    Process {
        id: clipper
        stdout: StdioCollector { id: clipOut }
        stderr: StdioCollector { id: clipErr }
        onExited: (code) => root.clipDone(code === 0 ? clipOut.text.trim() : clipErr.text.trim() || "Failed")
    }

    // Localhost QR: the dev servers (dev-ports, read when the panel opens), then lan-qr for one.
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
        // qs ipc call tools qr 5173: the panel's QR for that port (open the panel to see it)
        function qr(port: int): void { root.showQr(port) }
    }
}
