import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Island media state (design: Desktop prototype, isMediaCompact / isMediaOpen).
// Compact 280x24: bars glyph, title with the artist muted, elapsed.
// Expanded 440x172: 72px art, title, artist, album, source · output; elapsed, progress, length;
// shuffle and repeat toggles, previous / play-pause / next, output volume.
// The design's "Up next" is left out: MPRIS players publish no queue (no TrackList interface).
// Lyrics (owner's addition): a mode, toggled in the expanded notch, that stays on when it
// collapses. On: the expanded notch shows a lyrics view of the same size instead of the player,
// and the compact one shows the line being sung (microphone glyph) instead of title and artist.
// They come from LRCLIB (lrclib.net, owner's choice): searched by title and artist, the result
// closest to the track's length wins, synced over plain. Fetched only while the view is open,
// once per track. Synced lyrics show five lines with the sung one bright; without synced lyrics
// the compact notch keeps the title.
Item {
    id: root
    required property bool open
    readonly property var player: IslandState.mediaPlayer
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    function time(secs) {
        const s = Math.max(0, Math.floor(secs || 0))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    // MPRIS players don't push their position: refresh it while playing and shown, once a second,
    // or four times a second while lyrics follow the song.
    Timer {
        interval: root.lyricsOn ? 250 : 1000
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    // Lyrics
    property bool lyricsOn: false
    readonly property bool lyricsCompact: lyricsOn && lyricsStatus === "synced" // compact shows the line
    readonly property string lyricsNow: lyricsLine >= 0 ? (lyricsLines[lyricsLine].text || "♪") : "♪"
    readonly property string trackKey: player ? player.trackTitle + "|" + player.trackArtist : ""
    property string lyricsKey: ""     // the track the lyrics below belong to
    property string requestKey: ""    // the track being looked up
    property string lyricsStatus: ""  // loading, synced, plain, instrumental, none
    property var lyricsLines: []      // synced: [{ t: seconds, text }]
    property string lyricsPlain: ""
    readonly property int lyricsLine: { // index of the line being sung, -1 before the first
        if (lyricsStatus !== "synced" || !player)
            return -1
        let i = -1
        for (let k = 0; k < lyricsLines.length && lyricsLines[k].t <= player.position + 0.3; k++)
            i = k
        return i
    }
    onLyricsOnChanged: if (lyricsOn) fetchLyrics()
    onTrackKeyChanged: if (lyricsOn) fetchLyrics()

    function fetchLyrics() {
        if (!player || trackKey === "" || trackKey === lyricsKey || lyricsFetch.running)
            return
        requestKey = trackKey
        lyricsStatus = "loading"
        lyricsFetch.command = ["curl", "-sf", "-G", "--max-time", "8",
            "-A", "hypr-dotfiles island (github.com/redcodemohammed/dotfiles)",
            "--data-urlencode", "track_name=" + player.trackTitle,
            "--data-urlencode", "artist_name=" + player.trackArtist,
            "https://lrclib.net/api/search"]
        lyricsFetch.running = true
    }

    function applyLyrics(json) {
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
        const plain = results.find(r => r.plainLyrics)
        lyricsLines = []
        lyricsPlain = ""
        if (synced) {
            for (const line of synced.syncedLyrics.split("\n")) {
                const m = line.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s?(.*)$/)
                if (m)
                    lyricsLines.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3] })
            }
            lyricsLines = lyricsLines // notify bindings
            lyricsStatus = "synced"
        } else if (plain) {
            lyricsPlain = plain.plainLyrics
            lyricsStatus = "plain"
        } else {
            lyricsStatus = results.some(r => r.instrumental) ? "instrumental" : "none"
        }
        lyricsKey = requestKey
    }

    Process {
        id: lyricsFetch
        stdout: StdioCollector {
            id: lyricsOut
            onStreamFinished: root.applyLyrics(lyricsOut.text)
        }
        onExited: code => {
            if (code !== 0 && root.requestKey === root.trackKey) {
                root.lyricsStatus = "none" // offline, timeout or an HTTP error
                root.lyricsKey = root.requestKey
            }
            if (root.lyricsOn && root.trackKey !== root.lyricsKey)
                Qt.callLater(root.fetchLyrics)
        }
    }

    component Button: Rectangle {
        id: button
        property string glyph
        property bool toggle: false  // shuffle, repeat: lit when on
        property bool on: false
        property bool primary: false // play/pause sits on the selected surface
        property bool available: true
        signal pressed()
        width: 40
        height: 40
        color: on || primary || area.containsMouse ? Theme.surfaceSelected : Theme.surface
        border.width: 2
        border.color: on ? Theme.fg : Theme.border
        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: Icons.regular
            font.pixelSize: 16
            color: !button.available ? Theme.fgDim : button.toggle && !button.on ? Theme.fgMuted : Theme.fg
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.available
            onClicked: button.pressed()
        }
    }

    // Compact
    Item {
        visible: !root.open
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Text {
            id: bars
            anchors.verticalCenter: parent.verticalCenter
            text: root.lyricsCompact ? Icons.microphoneStage : Icons.equalizer
            font.family: Icons.regular
            font.pixelSize: 16
            color: Theme.fg
        }
        Text {
            id: elapsedCompact
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.player ? root.time(root.player.position) : ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fgMuted
        }
        Item { // title, then the artist muted, cut to the space left; or the line being sung
            x: bars.width + 8
            width: elapsedCompact.x - x - 8
            height: parent.height
            Text {
                id: titleCompact
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width)
                text: root.lyricsCompact ? root.lyricsNow : root.player ? root.player.trackTitle : ""
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: titleCompact.width + 8
                width: parent.width - x
                visible: !root.lyricsCompact && width > 24
                text: root.player ? root.player.trackArtist : ""
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
        }
    }

    // Expanded player view (the island draws the chevron in the header's right corner)
    Column {
        visible: root.open && !root.lyricsOn
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Row {
            width: parent.width
            height: 72
            spacing: 12

            Rectangle { // cover art
                width: 72
                height: 72
                color: Theme.surfaceSelected
                border.width: 2
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: Icons.musicNote
                    font.family: Icons.regular
                    font.pixelSize: 24
                    color: Theme.fgMuted
                }
                Image {
                    id: art
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: status === Image.Ready
                    source: root.player ? root.player.trackArtUrl : ""
                    sourceSize.width: 136
                    sourceSize.height: 136
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 72 - 12 - 32 // leave room for the chevron
                spacing: 4
                Text {
                    width: parent.width
                    text: root.player ? root.player.trackTitle : ""
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
                Text {
                    width: parent.width
                    text: root.player ? root.player.trackArtist : ""
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.player ? root.player.trackAlbum : ""
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                Text {
                    width: parent.width
                    text: (root.player ? root.player.identity : "")
                        + (root.sink ? " · " + (root.sink.nickname || root.sink.description || root.sink.name) : "")
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }
        }

        Item { // elapsed, progress, length
            width: parent.width
            height: 16
            Text {
                id: elapsed
                anchors.verticalCenter: parent.verticalCenter
                text: root.player ? root.time(root.player.position) : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Text {
                id: length
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.player && root.player.lengthSupported ? root.time(root.player.length) : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Rectangle {
                x: elapsed.width + 8
                width: length.x - x - 8
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                color: Theme.border
                Rectangle {
                    height: 4
                    color: Theme.fg
                    width: root.player && root.player.length > 0
                        ? parent.width * Math.max(0, Math.min(root.player.position / root.player.length, 1)) : 0
                }
            }
        }

        Item { // controls
            width: parent.width
            height: 40

            Row {
                spacing: 4
                Button {
                    glyph: Icons.shuffle
                    toggle: true
                    on: root.player !== null && root.player.shuffle
                    available: root.player !== null && root.player.shuffleSupported
                    onPressed: root.player.shuffle = !root.player.shuffle
                }
                Button { // None -> Playlist -> Track -> None
                    glyph: root.player && root.player.loopState === MprisLoopState.Track ? Icons.repeatOnce : Icons.repeat
                    toggle: true
                    on: root.player !== null && root.player.loopState !== MprisLoopState.None
                    available: root.player !== null && root.player.loopSupported
                    onPressed: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                        : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                        : MprisLoopState.None
                }
                Button {
                    glyph: Icons.microphoneStage
                    toggle: true
                    on: root.lyricsOn
                    onPressed: root.lyricsOn = !root.lyricsOn
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Button {
                    glyph: Icons.skipBack
                    available: root.player !== null && root.player.canGoPrevious
                    onPressed: root.player.previous()
                }
                Button {
                    glyph: root.player && root.player.isPlaying ? Icons.pause : Icons.play
                    primary: true
                    available: root.player !== null && root.player.canTogglePlaying
                    onPressed: root.player.togglePlaying()
                }
                Button {
                    glyph: Icons.skipForward
                    available: root.player !== null && root.player.canGoNext
                    onPressed: root.player.next()
                }
            }

            Row { // output volume (shown, not set here: the volume keys and the volume island do that)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.muted ? Icons.speakerSlash
                        : root.volume <= 0 ? Icons.speakerNone
                        : root.volume < 0.5 ? Icons.speakerLow
                        : Icons.speakerHigh
                    font.family: Icons.regular
                    font.pixelSize: 16
                    color: Theme.fgMuted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.volume * 100)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }
        }
    }

    // Expanded lyrics view: same size as the player view. Title, the lyrics toggle (back to the
    // player) beside the island's chevron, then five lines with the sung one bright.
    Item {
        visible: root.open && root.lyricsOn
        x: 12
        y: 12
        width: parent.width - 24
        height: parent.height - 24

        Text {
            width: parent.width - 24 - 8 - 24 - 8
            height: 24
            verticalAlignment: Text.AlignVCenter
            text: root.player ? root.player.trackTitle + " · " + root.player.trackArtist : ""
            elide: Text.ElideRight
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: Theme.fg
        }
        Rectangle { // back to the player view
            x: parent.width - 24 - 8 - 24
            width: 24
            height: 24
            color: lyricsBack.containsMouse ? Theme.surfaceSelected : "transparent"
            Text {
                anchors.centerIn: parent
                text: Icons.microphoneStage
                font.family: Icons.regular
                font.pixelSize: 16
                color: Theme.fg
            }
            MouseArea {
                id: lyricsBack
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.lyricsOn = false
            }
        }

        Column { // synced: two lines before, the sung line, two after
            y: 32
            width: parent.width
            visible: root.lyricsStatus === "synced"
            Repeater {
                model: 5
                Text {
                    required property int index
                    readonly property int line: root.lyricsLine - 2 + index
                    width: parent.width
                    height: 20
                    verticalAlignment: Text.AlignVCenter
                    text: line >= 0 && line < root.lyricsLines.length ? (root.lyricsLines[line].text || "♪") : ""
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: index === 2 ? Theme.fg : Theme.fgMuted
                }
            }
        }

        Flickable { // plain lyrics: no timing, drag to scroll
            y: 32
            width: parent.width
            height: parent.height - 32
            visible: root.lyricsStatus === "plain"
            clip: true
            contentHeight: plainText.implicitHeight
            Text {
                id: plainText
                width: parent.width
                text: root.lyricsPlain
                wrapMode: Text.WordWrap
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
        }

        Text { // loading, nothing found, instrumental
            y: 32 + 40
            width: parent.width
            visible: ["loading", "none", "instrumental"].indexOf(root.lyricsStatus) >= 0
            horizontalAlignment: Text.AlignHCenter
            text: root.lyricsStatus === "loading" ? "Looking up lyrics…"
                : root.lyricsStatus === "instrumental" ? "Instrumental" : "No lyrics found"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fgMuted
        }
    }
}
