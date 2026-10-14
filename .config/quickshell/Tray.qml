import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// What is running? Tray icons at 16px. App icons keep their own colors.
// Left click activates (or opens the menu for menu-only items), right click opens the menu.
Row {
    id: root
    required property var window
    spacing: 8

    Repeater {
        model: SystemTray.items

        IconImage {
            id: icon
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            source: modelData.icon
            implicitSize: 16

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    const item = icon.modelData
                    if (mouse.button === Qt.LeftButton && !item.onlyMenu) {
                        item.activate()
                    } else if (item.hasMenu) {
                        const pos = icon.mapToItem(null, 0, icon.height + 4)
                        item.display(root.window, pos.x, pos.y)
                    }
                }
            }
        }
    }
}
