import QtQuick
import Quickshell

// Sound panel (owner, 2026-10-17): drops from the bar's volume block like the Pomodoro panel, in
// place of the island view it opened before: IslandVolume's expanded view (volume, mic and
// brightness levels, the output and input device lists; a click picks the default). The volume
// keys still show the island's compact pill.
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width - implicitWidth
    anchor.rect.y: block.height + 4
    implicitWidth: body.width
    implicitHeight: body.height
    color: "transparent"
    grabFocus: false // Reveal's focus grab
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: if (!visible) closedAt = Date.now()

    Reveal { id: reveal; window: panel; target: body } // slides in and out like a window
    Rectangle {
        id: body
        width: 320
        height: IslandState.volumeHeight
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: reveal.close()

        IslandVolume {
            anchors.fill: parent
            open: true
        }
    }
}
