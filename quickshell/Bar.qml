import QtQuick
import Quickshell

// Top bar, one per screen. Flush with the screen edges, 32px tall.
PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 32
    color: Theme.bg
}
