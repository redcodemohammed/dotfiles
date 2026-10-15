import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

// The bar's capture indicator (spec: "Am I being captured?", icon only, red, visible only while
// live; Fill for an alert). Mic: an app's capture stream linked to an audio input device or a
// virtual source (PipeWire link groups); capturing a speaker's monitor, e.g. recording desktop
// sound, doesn't count. Camera: any process holding /dev/video* open (fuser every 2 s; most apps
// open the camera directly, not through PipeWire). Its block shows while `live` (Bar.qml).
Row {
    id: root
    // Quickshell types an app's capture stream Audio|Stream|Source (AudioInStream), a mic or virtual
    // source Audio|Source; a speaker's monitor is captured from the sink node (Sink flag): not counted.
    readonly property bool micLive: Pipewire.linkGroups.values.some(g => g.source !== null && g.target !== null
        && g.target.type === PwNodeType.AudioInStream && g.source.type === PwNodeType.AudioSource)
    property bool cameraLive: false
    readonly property bool live: micLive || cameraLive

    spacing: 4

    Text {
        visible: root.micLive
        text: Icons.microphone
        font.family: Icons.fill
        font.pixelSize: 16
        color: Theme.alert
    }
    Text {
        visible: root.cameraLive
        text: Icons.webcam
        font.family: Icons.fill
        font.pixelSize: 16
        color: Theme.alert
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cameraCheck.running) cameraCheck.running = true
    }
    Process {
        id: cameraCheck
        command: ["sh", "-c", "fuser -s /dev/video* 2>/dev/null"]
        onExited: code => root.cameraLive = code === 0
    }
}
