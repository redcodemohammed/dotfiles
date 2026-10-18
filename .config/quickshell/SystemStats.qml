pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, disks, temperature and the busiest processes, for the bar's system block and its
// panel (owner, 2026-10-18; the spec had cut these from the bar, the owner asked for them back).
// Every 2 s: CPU use from /proc/stat deltas, memory from /proc/meminfo (used = total - available),
// the CPU package temperature (thermal zone x86_pkg_temp, else coretemp, else the first zone).
// Disks every 30 s (df, real filesystems only). Top processes (.local/bin/sys-top) only while the
// panel is open: watchingTop.
Singleton {
    id: root

    property real cpu: 0 // percent, all cores
    property real memUsed: 0 // bytes
    property real memTotal: 0
    readonly property real mem: memTotal > 0 ? memUsed / memTotal * 100 : 0
    property real temp: -1 // degrees C; -1 without a sensor
    property var disks: [] // [{target, size, used, percent}] in bytes, / first
    readonly property real rootDisk: disks.length > 0 ? disks[0].percent : 0
    property var top: [] // [{name, cpu, mem}]
    property bool watchingTop: false

    // The last minute, oldest first: 30 samples, one per tick.
    readonly property int historyLength: 30
    property var cpuHistory: []
    property var memHistory: []

    property var lastCpu: null // [busy, total] from the previous tick

    function push(list, value) {
        const next = list.concat([value])
        return next.length > historyLength ? next.slice(next.length - historyLength) : next
    }

    function gigabytes(bytes) {
        return (bytes / 1073741824).toFixed(bytes >= 107374182400 ? 0 : 1)
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }
    Process {
        id: sampler
        command: ["sh", "-c", `
            head -n 1 /proc/stat
            grep -E '^(MemTotal|MemAvailable):' /proc/meminfo
            t=""
            for z in /sys/class/thermal/thermal_zone*; do
                [ "$(cat "$z/type" 2>/dev/null)" = x86_pkg_temp ] && { t="$z/temp"; break; }
            done
            if [ -z "$t" ]; then
                for h in /sys/class/hwmon/hwmon*; do
                    [ "$(cat "$h/name" 2>/dev/null)" = coretemp ] && { t="$h/temp1_input"; break; }
                done
            fi
            [ -z "$t" ] && [ -r /sys/class/thermal/thermal_zone0/temp ] && t=/sys/class/thermal/thermal_zone0/temp
            [ -n "$t" ] && echo "temp $(cat "$t")"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0, available = 0, temp = -1
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
                    } else if (f[0] === "temp") {
                        temp = Number(f[1]) / 1000
                    }
                }
                root.memTotal = total
                root.memUsed = total - available
                root.temp = temp
                root.cpuHistory = root.push(root.cpuHistory, root.cpu)
                root.memHistory = root.push(root.memHistory, root.mem)
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

    // sys-top samples for 1 s; the next run starts 1 s after it ends, so about every 2 s.
    onWatchingTopChanged: if (watchingTop) topReader.running = true
    Timer {
        id: topDelay
        interval: 1000
        onTriggered: if (root.watchingTop) topReader.running = true
    }
    Process {
        id: topReader
        command: [Quickshell.env("HOME") + "/.local/bin/sys-top", "3"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.top = JSON.parse(text) } catch (err) { root.top = [] }
            }
        }
        onExited: if (root.watchingTop) topDelay.restart()
    }
}
