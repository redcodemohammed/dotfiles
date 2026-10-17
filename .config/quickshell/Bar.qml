import QtQuick
import Quickshell

// Top bar, one per screen: 32px tall, floating 6px from the screen's top and sides. The bar is
// transparent; each widget sits on its own block in the bar colour, 6px apart, so the widgets
// float (owner, 2026-10-15). The bar centre belongs to the island, a notch from the top edge.
// Profiles (spec, "Monitors and bars"): the main screen (the G5) gets the full bar, the others a
// slim one (workspaces, window title, clock; the laptop's adds network and battery). A screen on
// its own gets the full bar, and so does the laptop when the G5 is away. Screens are matched by
// model, like the Hyprland rules match by description. Quickshell makes and drops a bar per screen
// as they come and go, so no hotplug tool is needed (owner, 2026-10-15). The right screen's media
// item is left out: the island shows what plays (owner).
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    readonly property bool laptop: modelData.name.startsWith("eDP")
    readonly property bool mainPresent: [...Quickshell.screens].some(s => s.model === "Odyssey G5")
    readonly property bool full: Quickshell.screens.length === 1 || modelData.model === "Odyssey G5"
        || (laptop && !mainPresent)
    // The settings panel can hide the slim bars (Bar & island, "Bars on other screens").
    visible: full || Settings.bar.otherScreens

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

    NetworkPanel { // drops from the network block, flush with the bar's right edge
        id: networkPanel
        bar: bar
    }
    PhoneCall { // while the phone rings: under the phone block, above the panel
        id: phoneCall
        bar: bar
        block: phoneBlock
    }
    Inbox { // drops from the bell (Notifs.inboxOpen); a slim bar has no bell: from the power block
        bar: bar
        block: bellBlock.visible ? bellBlock : toolsBlock
    }
    ToolsPanel { // drops from the power block at the far right; SUPER + X (Tools.qml)
        id: toolsPanel
        bar: bar
        block: toolsBlock
        onSettingsRequested: { settingsPanel.closedAt = 0; settingsPanel.toggle() }
    }
    SettingsPanel { // from the tools panel's Settings button, under the same block
        id: settingsPanel
        bar: bar
        block: toolsBlock
    }
    Connections {
        target: Settings
        function onPanelRequested(screen) {
            if (screen === bar.modelData.name)
                settingsPanel.toggle()
        }
    }
    Connections {
        target: Tools
        function onPanelRequested(screen) {
            if (screen === bar.modelData.name)
                toolsPanel.toggle()
        }
    }
    PomodoroPanel { // drops from the Pomodoro block
        id: pomodoroPanel
        bar: bar
        block: pomodoroBlock
    }
    PhonePanel { // drops from the phone block, its right edge on the block's
        id: phonePanel
        bar: bar
        block: phoneBlock
        below: phoneCall.visible ? phoneCall.implicitHeight + 4 : 0
    }
    Connections { // qs ipc call phone open, on this screen
        target: Phone
        function onPanelRequested(screen) {
            if (screen === bar.modelData.name && bar.full && Phone.paired)
                phonePanel.toggle()
        }
    }
    Connections { // the island's Wi-Fi pill, clicked on this screen
        target: NetState
        function onPanelRequested(screen) {
            if (screen === bar.modelData.name && !networkPanel.visible)
                networkPanel.toggle()
        }
    }

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
            visible: bar.full && tray.width > 0 // main bar only (spec)
            Tray {
                id: tray
                window: bar
            }
        }
        BarBlock { // between the tray and the status icons; the bar centre belongs to the island
            Clock {}
        }
        BarBlock {
            visible: bar.full && keyboardLayout.keymap !== "" // its condition, not its visible: a child of a hidden block reads as hidden
            KeyboardLayout {
                id: keyboardLayout
            }
        }
        BarBlock { // the phone bridge (owner's design): while a phone is paired; click: its panel
            id: phoneBlock
            visible: bar.full && Phone.paired
            clickable: true
            onClicked: phonePanel.toggle()
            PhoneStatus {}
        }
        BarBlock { // Pomodoro (owner, 2026-10-17): glyph and time left; click: its panel
            id: pomodoroBlock
            visible: bar.full
            clickable: true
            onClicked: pomodoroPanel.toggle()
            PomodoroStatus {}
        }
        BarBlock { // screen recording: muted when idle, red while recording; click: the island panel
            visible: bar.full
            clickable: true
            onClicked: IslandState.showRecording()
            Text {
                text: Icons.record
                font.family: Recording.active ? Icons.fill : Icons.regular
                font.pixelSize: 16
                color: Recording.active ? Theme.alert : Theme.fgMuted
            }
        }
        BarBlock { // mic and camera: red, only while something captures (spec)
            visible: bar.full && capture.live // its condition, not its visible: a child of a hidden block reads as hidden
            CaptureIndicator {
                id: capture
            }
        }
        BarBlock { // click: the volume island with the device lists
            visible: bar.full && volume.sink !== null
            clickable: true
            onClicked: IslandState.showVolume()
            Volume {
                id: volume
            }
        }
        BarBlock { // click: the network panel
            visible: bar.full || bar.laptop
            clickable: true
            onClicked: networkPanel.toggle()
            Network {}
        }
        BarBlock { // hidden without an adapter; click: bluetui in a terminal (owner's choice)
            visible: bar.full && bluetooth.adapter !== null
            clickable: true
            onClicked: Quickshell.execDetached(["alacritty", "--class", "bluetui", "-e", "bluetui"])
            BluetoothStatus {
                id: bluetooth
            }
        }
        BarBlock { // laptop only: hidden without a laptop battery
            visible: (bar.full || bar.laptop) && battery.device.ready && battery.device.isLaptopBattery
            Battery {
                id: battery
            }
        }
        BarBlock {
            id: bellBlock
            visible: bar.full
            NotificationCount {}
        }
        BarBlock { // tools panel (owner, 2026-10-17): power options, tools, settings
            id: toolsBlock
            clickable: true
            onClicked: toolsPanel.toggle()
            Text { // accent while Keep awake holds the idle chain
                text: Icons.power
                font.family: Tools.keepAwake ? Icons.fill : Icons.regular
                font.pixelSize: 16
                color: Tools.keepAwake ? Theme.accent : Theme.fgMuted
            }
        }
    }
}
