pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics for the island's media state (owner's addition), shared by every screen's island so the
// mode and the fetched lyrics follow the notch from screen to screen.
// Source: LRCLIB (lrclib.net, owner's choice): searched by title and artist, the result closest
// to the track's length (within 3 s) wins, synced over plain. Looked up only while the mode is
// on, once per track; title and artist are what lrclib.net receives.
Singleton {
    id: root
    property bool shown: false // the mode, toggled in the expanded media notch
    readonly property var player: IslandState.mediaPlayer
    readonly property string trackKey: player ? player.trackTitle + "|" + player.trackArtist : ""
    property string key: ""        // the track the lyrics below belong to
    property string requestKey: "" // the track being looked up
    property string status: ""     // loading, synced, plain, instrumental, none
    property var lines: []         // synced: [{ t: seconds, text }]
    property string plain: ""
    readonly property int line: { // index of the line being sung, -1 before the first
        if (status !== "synced" || !player)
            return -1
        let i = -1
        for (let k = 0; k < lines.length && lines[k].t <= player.position + 0.3; k++)
            i = k
        return i
    }
    readonly property bool compact: shown && status === "synced" // compact notch shows the line
    readonly property string now: line >= 0 ? (lines[line].text || "♪") : "♪"

    onShownChanged: if (shown) fetch()
    onTrackKeyChanged: if (shown) fetch()

    function fetch() {
        if (!player || trackKey === "" || trackKey === key || lookup.running)
            return
        requestKey = trackKey
        status = "loading"
        lookup.command = ["curl", "-sf", "-G", "--max-time", "8",
            "-A", "hypr-dotfiles island (github.com/redcodemohammed/dotfiles)",
            "--data-urlencode", "track_name=" + player.trackTitle,
            "--data-urlencode", "artist_name=" + player.trackArtist,
            "https://lrclib.net/api/search"]
        lookup.running = true
    }

    function apply(json) {
        if (requestKey !== trackKey)
            return // the track changed while looking up; onExited looks up the new one
        let results = []
        try { results = JSON.parse(json) } catch (err) {}
        const len = player && player.lengthSupported ? player.length : 0
        if (len > 0) {
            results = results.filter(r => Math.abs(r.duration - len) <= 3)
            results.sort((a, b) => Math.abs(a.duration - len) - Math.abs(b.duration - len))
        }
        const synced = results.find(r => r.syncedLyrics)
        const plainHit = results.find(r => r.plainLyrics)
        const parsed = []
        plain = ""
        if (synced) {
            for (const text of synced.syncedLyrics.split("\n")) {
                const m = text.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s?(.*)$/)
                if (m)
                    parsed.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3] })
            }
            status = "synced"
        } else if (plainHit) {
            plain = plainHit.plainLyrics
            status = "plain"
        } else {
            status = results.some(r => r.instrumental) ? "instrumental" : "none"
        }
        lines = parsed
        key = requestKey
    }

    Process {
        id: lookup
        stdout: StdioCollector {
            id: lookupOut
            onStreamFinished: root.apply(lookupOut.text)
        }
        onExited: code => {
            if (code !== 0 && root.requestKey === root.trackKey) {
                root.status = "none" // offline, timeout or an HTTP error
                root.key = root.requestKey
            }
            if (root.shown && root.trackKey !== root.key)
                Qt.callLater(root.fetch)
        }
    }
}
