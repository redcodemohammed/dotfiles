import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Top bar, one per screen: 32px tall, floating 6px from the screen's top and sides. The bar is
// transparent; each widget sits on its own block in the bar colour, 6px apart, so the widgets
// float (owner, 2026-10-15). The bar centre belongs to the island, a notch from the top edge.
// Profiles (spec, "Monitors and bars"): the main screen (monitors.lua's `main`) gets the full bar, the others a
// slim one (workspaces, window title, clock; the laptop's adds network and battery). A screen on
// its own gets the full bar, and so does the laptop when the G5 is away. Screens are matched by
// model, like the Hyprland rules match by description. Quickshell makes and drops a bar per screen
// as they come and go, so no hotplug tool is needed (owner, 2026-10-15). The right screen's media
// item is left out: the island shows what plays (owner).
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // From hyprland.lua (monitors.lua), through the environment. Unset (started elsewhere, or no
    // main screen named): every screen gets the full bar.
    readonly property string mainModel: Quickshell.env("DESKTOP_MAIN_MODEL") ?? ""
    readonly property string laptopOutput: Quickshell.env("DESKTOP_LAPTOP_OUTPUT") ?? ""
    readonly property bool laptop: laptopOutput !== "" && modelData.name === laptopOutput
    readonly property bool mainPresent: mainModel !== "" && [...Quickshell.screens].some(s => s.model === mainModel)
    readonly property bool full: Quickshell.screens.length === 1 || mainModel === "" || modelData.model === mainModel
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
    RecordPanel { // drops from the record block
        id: recordPanel
        bar: bar
        block: recordBlock
    }
    BluetoothPanel { // drops from the Bluetooth block
        id: bluetoothPanel
        bar: bar
        block: bluetoothBlock
    }
    SoundPanel { // drops from the volume block
        id: soundPanel
        bar: bar
        block: volumeBlock
    }
    Connections {
        target: Panels
        function onToggleRequested(name, screen) {
            if (screen !== bar.modelData.name)
                return
            if (name === "record") recordPanel.toggle()
            else if (name === "sound") soundPanel.toggle()
            else if (name === "bluetooth") bluetoothPanel.toggle()
            else if (name === "network") networkPanel.toggle()
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
        padding: 6 // the 20px workspaces sit 4px clear of the 2px border, as top and bottom (owner)
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

    // Right zone (owner, 2026-10-17: 13 blocks became 5): related items share one block, each a
    // BarCell with its own click and hover; a cell's panel drops under it. Groups: the tray behind
    // a chevron, layout and clock, phone / Pomodoro / record / capture, sound / network /
    // Bluetooth / battery, notifications and power. A group hides when all its cells do (its
    // conditions, not its cells' visible: a child of a hidden block reads as hidden).
    property bool trayOpen: false
    Row {
        anchors.right: parent.right
        height: parent.height
        spacing: 6

        BarBlock { // the tray behind a chevron (main bar only, spec): a click unfolds it inline
            visible: bar.full && SystemTray.items.values.length > 0
            padding: 2
            Row {
                Item { // unfolds on the window spring, folds on it reversed (owner: animate it)
                    height: 28
                    width: bar.trayOpen ? trayCell.implicitWidth : 0
                    visible: width > 0
                    clip: true
                    Behavior on width {
                        enabled: Settings.look.animations
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: bar.trayOpen ? [0.34, 1.3, 0.64, 1, 1, 1] // hyprland.lua "spring"
                                : [0.36, 0, 0.66, -0.3, 1, 1] // "springBack"
                        }
                    }
                    BarCell {
                        id: trayCell
                        anchors.right: parent.right // revealed from the chevron outwards
                        opacity: bar.trayOpen ? 1 : 0
                        Behavior on opacity {
                            enabled: Settings.look.animations
                            NumberAnimation { duration: 150 }
                        }
                        Tray {
                            window: bar
                        }
                    }
                }
                BarCell {
                    clickable: true
                    onClicked: bar.trayOpen = !bar.trayOpen
                    Text {
                        text: bar.trayOpen ? Icons.caretRight : Icons.caretLeft
                        font.family: Icons.regular
                        font.pixelSize: 16
                        color: Theme.fgMuted
                    }
                }
            }
        }

        BarBlock { // keyboard layout and the clock
            padding: 2
            Row {
                BarCell {
                    visible: bar.full && keyboardLayout.keymap !== ""
                    KeyboardLayout {
                        id: keyboardLayout
                    }
                }
                BarCell {
                    Clock {}
                }
            }
        }

        BarBlock { // phone, Pomodoro, recording, and mic / camera while live
            visible: bar.full
            padding: 2
            Row {
                BarCell { // the phone bridge (owner's design): while a phone is paired
                    id: phoneBlock
                    visible: Phone.paired
                    clickable: true
                    onClicked: phonePanel.toggle()
                    PhoneStatus {}
                }
                BarCell { // Pomodoro: glyph and time left
                    id: pomodoroBlock
                    clickable: true
                    onClicked: pomodoroPanel.toggle()
                    PomodoroStatus {}
                }
                BarCell { // screen recording: muted when idle, red while recording
                    id: recordBlock
                    clickable: true
                    onClicked: recordPanel.toggle()
                    Text {
                        text: Icons.record
                        font.family: Recording.active ? Icons.fill : Icons.regular
                        font.pixelSize: 16
                        color: Recording.active ? Theme.alert : Theme.fgMuted
                    }
                }
                BarCell { // mic and camera: red, only while something captures (spec)
                    visible: capture.live
                    CaptureIndicator {
                        id: capture
                    }
                }
            }
        }

        BarBlock { // sound, network, Bluetooth, battery
            visible: bar.full || bar.laptop
            padding: 2
            Row {
                BarCell {
                    id: volumeBlock
                    visible: bar.full && volume.sink !== null
                    clickable: true
                    onClicked: soundPanel.toggle()
                    Volume {
                        id: volume
                    }
                }
                BarCell {
                    clickable: true
                    onClicked: networkPanel.toggle()
                    Network {}
                }
                BarCell { // hidden without an adapter
                    id: bluetoothBlock
                    visible: bar.full && bluetooth.adapter !== null
                    clickable: true
                    onClicked: bluetoothPanel.toggle()
                    BluetoothStatus {
                        id: bluetooth
                    }
                }
                BarCell { // laptop only: hidden without a laptop battery
                    visible: battery.device.ready && battery.device.isLaptopBattery
                    Battery {
                        id: battery
                    }
                }
            }
        }

        BarBlock { // notifications and power
            padding: 2
            Row {
                BarCell {
                    id: bellBlock
                    visible: bar.full
                    NotificationCount {}
                }
                BarCell { // tools panel (owner, 2026-10-17): power options, tools, settings
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
    }
}
