import QtQuick
import Quickshell
import Quickshell.Wayland

// One per screen: a sheet in the background colour just above the wallpaper (layer Bottom: under
// windows and the bar), shown only while the entrance plays. It starts opaque and fades out over
// 1200 ms (600 at first: owner asked for slower), so the wallpaper fades up. Clicks pass through (empty mask). Entrance.qml.
PanelWindow {
    id: cover
    required property var modelData
    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "entrance"
    mask: Region {}
    color: "transparent"
    visible: Entrance.covered || fade.running

    Connections {
        target: Entrance
        function onCoveredChanged() { if (Entrance.covered) sheet.opacity = 1 }
    }

    Rectangle {
        id: sheet
        anchors.fill: parent
        color: Theme.bg
    }

    Connections {
        target: Entrance
        function onRunChanged() {
            sheet.opacity = 1
            fade.restart()
        }
    }

    SequentialAnimation {
        id: fade
        PauseAnimation { duration: 100 } // the bars start first
        NumberAnimation {
            target: sheet
            property: "opacity"
            to: 0
            duration: 1200
            easing.type: Easing.InOutCubic
        }
    }
}
