import QtQuick
import Quickshell
import Quickshell.Hyprland

// Popup stack: top-right, flush with the right edge, 4px below the bar.
// Focused monitor only. Newest on top, 4px apart, at most 3 visible.
PanelWindow {
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    visible: monitor && monitor.focused && Notifs.popups.length > 0
    anchors {
        top: true
        right: true
    }
    margins.top: 4
    exclusiveZone: 0 // sit below the bar's reserved space, reserve nothing
    color: "transparent"
    implicitWidth: 360
    implicitHeight: stack.implicitHeight

    Column {
        id: stack
        spacing: 4

        Repeater {
            model: Notifs.popups.slice(0, 3)
            Popup {}
        }
    }
}
