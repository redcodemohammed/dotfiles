import QtQuick
import Quickshell

// Top bar, one per screen: 32px tall, floating 6px from the screen's top and sides. The bar is
// transparent; each widget sits on its own block in the bar colour, 6px apart, so the widgets
// float (owner, 2026-10-15). The bar centre belongs to the island, a notch from the top edge.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    // Floats 6px from the screen's top and sides, like the window gaps (owner, 2026-10-15).
    margins {
        top: 6
        left: 6
        right: 6
    }
    implicitHeight: 32
    color: "transparent"

    BarBlock {
        id: workspacesBlock
        anchors.left: parent.left
        padding: 4 // the 24px squares sit 4px in, as from the top and bottom
        Workspaces {
            screen: bar.modelData
        }
    }

    BarBlock {
        anchors.left: workspacesBlock.right
        anchors.leftMargin: 6
        visible: title.text !== ""
        WindowTitle {
            id: title
            screen: bar.modelData
        }
    }

    // Right zone: one block per status item, 6px apart.
    Row {
        anchors.right: parent.right
        height: parent.height
        spacing: 6

        BarBlock {
            visible: tray.width > 0
            Tray {
                id: tray
                window: bar
            }
        }
        BarBlock { // between the tray and the status icons; the bar centre belongs to the island
            Clock {}
        }
        BarBlock {
            visible: keyboardLayout.keymap !== "" // its condition, not its visible: a child of a hidden block reads as hidden
            KeyboardLayout {
                id: keyboardLayout
            }
        }
        BarBlock {
            visible: volume.sink !== null
            Volume {
                id: volume
            }
        }
        BarBlock {
            Network {}
        }
        BarBlock { // laptop only: hidden without a laptop battery
            visible: battery.device.ready && battery.device.isLaptopBattery
            Battery {
                id: battery
            }
        }
        BarBlock {
            NotificationCount {}
        }
    }
}
