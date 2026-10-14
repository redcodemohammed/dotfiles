import QtQuick
import Quickshell

// Top bar, one per screen. Flush with the screen edges, 32px tall.
PanelWindow {
    id: bar
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

    // Right zone: status items, 8px apart, 8px from the edge.
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Tray {
            window: bar
            anchors.verticalCenter: parent.verticalCenter
        }
        Clock { // between the tray and the status icons; the bar centre belongs to the island
            anchors.verticalCenter: parent.verticalCenter
        }
        KeyboardLayout { // EN or AR (owner's request, not in the spec's bar table)
            anchors.verticalCenter: parent.verticalCenter
        }
        Volume {}
        Network {
            anchors.verticalCenter: parent.verticalCenter
        }
        Battery { // laptop only: hidden without a laptop battery
            anchors.verticalCenter: parent.verticalCenter
        }
        NotificationCount {}
    }

    WindowTitle {
        screen: modelData
        anchors.left: workspaces.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }
}
