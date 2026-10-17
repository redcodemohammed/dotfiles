import QtQuick
import Quickshell

// Recording panel (owner, 2026-10-17): drops from the bar's record block like the Pomodoro panel, in
// place of the island view it opened before. Not recording: the setup (audio, frame rate, quality,
// Start; IslandRecord's setup view, 340x324); starting closes it, so it isn't in the video.
// Recording: the recording view (time, Pause/Resume, Stop and save, 340x172).
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
    Connections {
        target: Recording
        function onActiveChanged() {
            if (Recording.active && panel.visible)
                panel.visible = false // at once: the recording starts now
        }
    }

    Rectangle {
        id: body
        width: 340
        height: Recording.active ? 172 : 324
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: reveal.close()

        IslandRecord {
            anchors.fill: parent
            open: Recording.active
            setup: !Recording.active
        }
    }
}
