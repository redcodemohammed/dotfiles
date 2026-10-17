import QtQuick
import Quickshell

// Sound panel (owner, 2026-10-17): drops from the bar's volume block like the Pomodoro panel, in
// place of the island view it opened before: IslandVolume's expanded view (volume, mic and
// brightness levels, the output and input device lists; a click picks the default). The volume
// keys still show the island's compact pill. Tabs (owner, 2026-10-17): Devices (that view) and
// Apps (each app playing or recording: AppStream.qml, Sound.qml).
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
    onVisibleChanged: {
        if (!visible)
            closedAt = Date.now()
        else
            Sound.readTargets()
    }
    property string tab: "devices"

    Reveal { id: reveal; window: panel; target: body } // slides in and out like a window
    Rectangle {
        id: body
        width: 340
        height: tabs.height + 8 + (panel.tab === "devices" ? IslandState.volumeHeight : apps.implicitHeight + 24)
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: reveal.close()

        Row {
            id: tabs
            x: 12
            y: 12
            width: parent.width - 24
            SettingsTab { width: parent.width / 2; tab: panel.tab; label: "Devices"; section: "devices"; onChosen: panel.tab = section }
            SettingsTab { width: parent.width / 2; tab: panel.tab; label: "Apps"; section: "apps"; onChosen: panel.tab = section }
        }

        IslandVolume {
            visible: panel.tab === "devices"
            y: tabs.y + tabs.height
            width: parent.width
            height: IslandState.volumeHeight
            open: true
        }

        Column {
            id: apps
            visible: panel.tab === "apps"
            x: 12
            y: tabs.y + tabs.height + 12
            width: parent.width - 24
            spacing: 12

            Text {
                visible: Sound.streams.length === 0
                text: "No app is playing or recording"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }
            Text {
                visible: Sound.playing.length > 0
                text: "Playing"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Repeater {
                model: Sound.playing
                AppStream { required property var modelData; node: modelData }
            }
            Text {
                visible: Sound.recording.length > 0
                text: "Recording"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
            Repeater {
                model: Sound.recording
                AppStream { required property var modelData; node: modelData }
            }
        }
    }
}
