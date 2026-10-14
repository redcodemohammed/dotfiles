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

    Workspaces {
        id: workspaces
        screen: modelData
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }

    Clock {
        anchors.centerIn: parent
    }

    WindowTitle {
        screen: modelData
        anchors.left: workspaces.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }
}
