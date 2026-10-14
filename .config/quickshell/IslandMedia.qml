import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Island media state (design: Desktop prototype, isMediaCompact / isMediaOpen).
// Compact 280x24: bars glyph, title with the artist muted, elapsed.
// Expanded 440x172: 72px art, title, artist, album, source · output; elapsed, progress, length;
// shuffle and repeat toggles, previous / play-pause / next, output volume.
// The design's "Up next" is left out: MPRIS players publish no queue (no TrackList interface).
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

    // MPRIS players don't push their position: refresh it once a second while playing and shown.
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
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
            text: Icons.equalizer
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
        Item { // title, then the artist muted, cut to the space left
            x: bars.width + 8
            width: elapsedCompact.x - x - 8
            height: parent.height
            Text {
                id: titleCompact
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width)
                text: root.player ? root.player.trackTitle : ""
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: titleCompact.width + 8
                width: parent.width - x
                visible: width > 24
                text: root.player ? root.player.trackArtist : ""
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
        }
    }

    // Expanded (the island draws the chevron in the header's right corner)
    Column {
        visible: root.open
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
}
