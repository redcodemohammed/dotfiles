pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and disk use for the corner widget's rings (CornerWidget.qml; owner, 2026-10-18 for
// the bar's system block, which went on 2026-10-20 with its panel, the temperature, the history
// and the top processes). Every 2 s: CPU use from /proc/stat deltas, memory from /proc/meminfo
// (used = total - available). Disks every 30 s (df, real filesystems only, / first).
Singleton {
    id: root

    property real cpu: 0 // percent, all cores
    property real memUsed: 0 // bytes
    property real memTotal: 0
    readonly property real mem: memTotal > 0 ? memUsed / memTotal * 100 : 0
    property var disks: [] // [{target, size, used, percent}] in bytes, / first
    readonly property real rootDisk: disks.length > 0 ? disks[0].percent : 0

    property var lastCpu: null // [busy, total] from the previous tick

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }
    Process {
        id: sampler
        command: ["sh", "-c", "head -n 1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0, available = 0
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/)
                    if (f[0] === "cpu") {
                        const v = f.slice(1).map(Number)
                        const all = v.reduce((a, b) => a + b, 0)
                        const busy = all - v[3] - (v[4] || 0) // idle and iowait
                        if (root.lastCpu !== null && all > root.lastCpu[1])
                            root.cpu = (busy - root.lastCpu[0]) / (all - root.lastCpu[1]) * 100
                        root.lastCpu = [busy, all]
                    } else if (f[0] === "MemTotal:") {
                        total = Number(f[1]) * 1024
                    } else if (f[0] === "MemAvailable:") {
                        available = Number(f[1]) * 1024
                    }
                }
                root.memTotal = total
                root.memUsed = total - available
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskReader.running = true
    }
    Process {
        id: diskReader
        command: ["df", "-B1", "--output=target,size,used,avail", "-x", "tmpfs", "-x", "devtmpfs",
            "-x", "efivarfs", "-x", "overlay", "-x", "squashfs", "-x", "fuse.portal"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                for (const line of text.trim().split("\n").slice(1)) { // the header goes
                    const f = line.trim().split(/\s+/)
                    if (f.length < 4) continue
                    // percent as df counts it: of the space users can have (ext4 keeps ~5% for root)
                    const used = Number(f[2]), avail = Number(f[3])
                    rows.push({ target: f[0], size: Number(f[1]), used: used,
                        percent: used + avail > 0 ? used / (used + avail) * 100 : 0 })
                }
                rows.sort((a, b) => a.target === "/" ? -1 : b.target === "/" ? 1 : a.target.localeCompare(b.target))
                root.disks = rows
            }
        }
    }
}
