import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// Top bar, one per screen: the frame's top side (Frame.qml, owner, 2026-10-20; it floated 6px
// from the top and sides before). The bar window is transparent over the frame's band; each
// widget sits on its own coloured chip (BarChip.qml). The workspaces take the centre, the launcher and
// the compact island the left end (owner, 2026-10-20).
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
    // A turned (portrait) screen shows only the workspaces, along its bottom (owner, 2026-10-25:
    // the LF24T stood upright on the left): the launcher, the compact island, the title and the
    // right zone hide, and the band is the frame's bottom side instead of its top.
    readonly property bool onlyWorkspaces: modelData.height > modelData.width
    // The settings panel can hide the slim bars (Bar & island, "Bars on other screens").
    visible: full || Settings.bar.otherScreens

    anchors {
        top: !onlyWorkspaces
        bottom: onlyWorkspaces
        left: true
        right: true
    }
    // Flush with the top: 44px, the 32px blocks 6px from its top and bottom, its ends in line
    // with the frame's sides. Its height is the strip Hyprland keeps windows out of. At the
    // bottom it keeps out the band less the frame's side, since hyprland.lua's bottom gap
    // already counts the side (and the spacer below reserves the top side).
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: onlyWorkspaces ? implicitHeight - Settings.look.frame : implicitHeight
    margins {
        left: Settings.look.frame
        right: Settings.look.frame
    }
    implicitHeight: 44
    color: "transparent"

    Frame { // on every screen; without a bar its top is as wide as its sides
        screen: bar.modelData
        top: bar.visible && !bar.onlyWorkspaces ? bar.implicitHeight : Settings.look.frame
        bottom: bar.visible && bar.onlyWorkspaces ? bar.implicitHeight : Settings.look.frame
    }
    PanelWindow { // with the bar at the bottom: keeps windows off the frame's top side, as the bar does at the top
        screen: bar.modelData
        visible: bar.visible && bar.onlyWorkspaces
        anchors { top: true; left: true; right: true }
        implicitHeight: Settings.look.frame
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Settings.look.frame
        mask: Region {}
        color: "transparent"
    }

    PhoneCall { // while the phone rings: under the phone block, above the panel
        id: phoneCall
        bar: bar
        block: phoneBlock
    }
    Inbox { // drops from the Arch chip (Notifs.inboxOpen), on every bar
        bar: bar
        block: launcherBlock
    }
    ToolsPanel { // drops from the tools block (wrench); SUPER + X (Tools.qml)
        id: toolsPanel
        bar: bar
        block: toolsBlock
    }
    QuickPanel { // quick settings (owner, 2026-10-20): from the chip at the bar's right end
        id: quickPanel
        bar: bar
        block: quickBlock
        onSettingsRequested: { settingsPanel.closedAt = 0; settingsPanel.toggle() }
    }
    SettingsPanel { // from quick settings' Settings button, under the same chip
        id: settingsPanel
        bar: bar
        block: quickBlock
        onBackRequested: { quickPanel.closedAt = 0; quickPanel.toggle() }
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
    Connections {
        target: Panels
        function onToggleRequested(name, screen) {
            if (screen !== bar.modelData.name)
                return
            if (name === "record") recordPanel.toggle()
            else if (name === "pomodoro") pomodoroPanel.toggle()
            else if (name === "calendar") calendarPanel.toggle()
            else if (name === "sound") quickPanel.openView("sound") // quick settings' sound view
            else if (name === "bluetooth") quickPanel.openView("bluetooth")
            else if (name === "network") quickPanel.openView("network")
        }
    }
    CalendarPanel { // drops from the clock chip, centred under it
        id: calendarPanel
        bar: bar
        block: clockBlock
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
            if (screen === bar.modelData.name && quickPanel.shown !== "network")
                quickPanel.openView("network")
        }
    }

    // Chips (BarChip.qml, owner 2026-10-20): each item its own hue from the palette (hue1-hue6,
    // the accent round the colour wheel), placed so no two neighbours share one; 4px between the
    // chips of a group, 10px between groups. Red stays the alert's: a chip turns red while it
    // alerts (its widget's `ink`).
    // The Arch chip at the band's left end (owner, 2026-10-20): the notifications, in place of the
    // bell (Vicinae is SUPER + / only). A dot while something is unread; dimmed with Do Not
    // Disturb. Left click: the inbox; right click: Do Not Disturb.
    BarChip {
        id: launcherBlock
        visible: !bar.onlyWorkspaces
        anchors.left: parent.left
        y: 6
        hue: Theme.hue1
        clickable: true
        onClicked: Notifs.toggleInbox()
        Item {
            width: 16
            height: 16
            Text { // the Arch logo: Nerd Font's nf-linux-archlinux
                anchors.centerIn: parent
                text: "\uf303"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: Notifs.dnd ? Qt.rgba(Theme.hue1.r, Theme.hue1.g, Theme.hue1.b, 0.6) : Theme.hue1
            }
            Rectangle { // unread
                visible: Notifs.unread > 0
                x: 12
                y: -3
                width: 7
                height: 7
                radius: 3.5
                color: Theme.fg
            }
            MouseArea { // right click only: the chip takes the left one
                anchors.fill: parent
                anchors.margins: -8
                acceptedButtons: Qt.RightButton
                onClicked: Notifs.dnd = !Notifs.dnd
            }
        }
    }

    BarChip { // centred (owner, 2026-10-20): the left end is the launcher's and the island's
        id: workspacesBlock
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        neutral: true // its active workspace is the accent's
        padding: 6 // the 20px workspaces 6px clear of the chip's ends, as top and bottom
        Workspaces {
            screen: bar.modelData
        }
    }

    // The compact island (owner, 2026-10-20: in the band on a chip, so it never covers a
    // window): after the launcher, on the focused screen, while a state shows and isn't open
    // (the open form is Island.qml's, growing out of the corner). Its slot grows from nothing on
    // the window spring and the title after it slides along. It gets the room left of the
    // workspaces at most; a state's content elides in less (media's compact is 640px wide).
    Item {
        id: islandSlot
        visible: !bar.onlyWorkspaces
        anchors.left: launcherBlock.right
        y: 6
        height: 32
        readonly property var monitor: Hyprland.monitorFor(bar.modelData)
        readonly property bool shown: monitor !== null && monitor.focused
            && IslandState.kind !== "" && !IslandState.open && IslandState.size[0] > 0
        readonly property real room: workspacesBlock.x - x - 20 // 10 before the chip, 10 before the workspaces
        // What it shows is kept while it shrinks away, so it leaves with its content.
        property string kind: ""
        property real boxWidth: 0
        function keep() {
            if (!shown)
                return
            kind = IslandState.kind
            boxWidth = IslandState.size[0]
        }
        readonly property var live: [shown, IslandState.kind, IslandState.size]
        onLiveChanged: keep()
        readonly property real contentWidth: Math.max(0, Math.min(boxWidth, room - 8)) // the chip's 4px padding
        readonly property var info: IslandState.active ? IslandState.active.data : ({})
        readonly property bool alert: kind === "record" || (kind === "build" && info.failed)
            || (kind === "battery" && IslandState.batteryCritical) // as the open island's (Island.qml)

        width: shown ? contentWidth + 8 + 10 : 0
        clip: true
        Behavior on width {
            enabled: Settings.look.animations
            NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.3, 0.64, 1, 1, 1] } // hyprland.lua "spring"
        }

        BarChip {
            x: 10
            padding: 4
            hue: islandSlot.alert ? Theme.alert : Theme.hue2 // not the launcher's, its neighbour
            clickable: true
            onClicked: IslandState.click(bar.modelData.name) // opens it, out of the corner
            Item {
                width: islandSlot.contentWidth
                height: 24
                IslandVolume {
                    anchors.fill: parent
                    visible: islandSlot.kind === "volume" || islandSlot.kind === "brightness"
                    open: false
                }
                IslandBattery {
                    anchors.fill: parent
                    visible: islandSlot.kind === "battery"
                    open: false
                }
                IslandConnect {
                    anchors.fill: parent
                    visible: islandSlot.kind === "connect"
                }
                IslandTimer {
                    anchors.fill: parent
                    visible: islandSlot.kind === "timer"
                    open: false
                }
                IslandRecord {
                    anchors.fill: parent
                    visible: islandSlot.kind === "record"
                    open: false
                    setup: false
                }
                IslandMedia {
                    anchors.fill: parent
                    visible: islandSlot.kind === "media"
                    open: false
                }
                IslandBuild {
                    anchors.fill: parent
                    visible: islandSlot.kind === "build"
                    open: false
                    info: islandSlot.info
                }
            }
        }
    }

    BarChip { // the focused window's title, after the island; hidden when there's no room
        id: titleBlock
        anchors.left: islandSlot.right
        anchors.leftMargin: 10
        y: 6
        neutral: true
        readonly property real room: workspacesBlock.x - x - 10
        visible: !bar.onlyWorkspaces && title.text !== "" && room > 64
        WindowTitle {
            id: title
            screen: bar.modelData
            maxWidth: titleBlock.room - 2 * titleBlock.padding
        }
    }

    // Right zone, in groups (owner, 2026-10-17; separate chips since 2026-10-20): the tray behind
    // a chevron; the clock; phone / Pomodoro / record / capture; tools; quick settings (owner,
    // 2026-10-20: the layout and system chips went, the bell is the Arch chip, sound, network,
    // Bluetooth, battery and power are the one quick-settings chip). A chip's panel drops under it. A group
    // hides when all its chips do (its conditions, not its chips' visible: a child of a hidden row
    // reads as hidden), so the 10px gaps don't double up.
    property bool trayOpen: false
    Row {
        visible: !bar.onlyWorkspaces
        anchors.right: parent.right
        y: 6
        height: 32
        spacing: 10

        BarChip { // the tray behind a chevron (main bar only, spec): a click unfolds it inline
            visible: bar.full && SystemTray.items.values.length > 0
            neutral: true // the apps' icons bring their own colours
            clickable: true
            onClicked: bar.trayOpen = !bar.trayOpen
            Row {
                Item { // unfolds on the window spring, folds on it reversed (owner: animate it)
                    height: 24
                    width: bar.trayOpen ? tray.implicitWidth + 8 : 0
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
                    Tray {
                        id: tray
                        anchors.right: parent.right // revealed from the chevron outwards
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        window: bar
                        opacity: bar.trayOpen ? 1 : 0
                        Behavior on opacity {
                            enabled: Settings.look.animations
                            NumberAnimation { duration: 150 }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.trayOpen ? Icons.caretRight : Icons.caretLeft
                    font.family: Icons.regular
                    font.pixelSize: 16
                    color: Theme.fgMuted
                }
            }
        }

        BarChip { // the clock (the layout chip went, owner 2026-10-20); a click opens the calendar (2026-10-21)
            id: clockBlock
            hue: clock.ink
            clickable: true
            onClicked: calendarPanel.toggle()
            Clock {
                id: clock
                hue: Theme.hue6
            }
        }

        Row { // phone, Pomodoro, recording, and mic / camera while live
            visible: bar.full
            spacing: 4
            BarChip { // the phone bridge (owner's design): while a phone is paired
                id: phoneBlock
                visible: Phone.paired
                hue: phoneStatus.ink
                clickable: true
                onClicked: phonePanel.toggle()
                PhoneStatus {
                    id: phoneStatus
                    hue: Theme.hue4
                }
            }
            BarChip { // Pomodoro: glyph and time left
                id: pomodoroBlock
                hue: pomodoroStatus.ink
                clickable: true
                onClicked: pomodoroPanel.toggle()
                PomodoroStatus {
                    id: pomodoroStatus
                    hue: Theme.hue1 // a tomato
                }
            }
            BarChip { // screen recording: neutral when idle, red while recording
                id: recordBlock
                neutral: !Recording.active
                hue: Theme.alert
                clickable: true
                onClicked: recordPanel.toggle()
                Text {
                    text: Icons.record
                    font.family: Recording.active ? Icons.fill : Icons.regular
                    font.pixelSize: 16
                    color: Recording.active ? Theme.alert : Theme.fgMuted
                }
            }
            BarChip { // mic and camera: red, only while something captures (spec)
                visible: capture.live
                hue: capture.ink
                CaptureIndicator {
                    id: capture
                }
            }
        }

        BarChip { // tools (owner, 2026-10-18: its own chip, apart from power)
            id: toolsBlock
            hue: Theme.hue2
            clickable: true
            onClicked: toolsPanel.toggle()
            Text { // full colour and filled while Keep awake holds the idle chain, dimmed otherwise
                text: Icons.wrench
                font.family: Tools.keepAwake ? Icons.fill : Icons.regular
                font.pixelSize: 16
                color: Tools.keepAwake ? Theme.hue2 : Qt.rgba(Theme.hue2.r, Theme.hue2.g, Theme.hue2.b, 0.6)
            }
        }

        // Quick settings (owner, 2026-10-20, the "Quick settings panel" design): one neutral chip
        // with the sound, network, Bluetooth (while on), battery (laptop) and power icons, each in
        // its hue; red when the network fails or the battery is critical. Opens QuickPanel, and
        // the settings panel hangs from it too. It took the sound, network, Bluetooth, battery
        // and power chips' places.
        BarChip {
            id: quickBlock
            readonly property bool alert: quickNetwork.failing || quickBattery.critical
            neutral: !alert
            hue: Theme.alert
            padding: 10
            clickable: true
            onClicked: quickPanel.toggle()
            Row {
                spacing: 10
                Volume {
                    anchors.verticalCenter: parent.verticalCenter
                    hue: Theme.hue6
                }
                Network {
                    id: quickNetwork
                    anchors.verticalCenter: parent.verticalCenter
                    hue: Theme.hue4
                }
                BluetoothStatus {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: on
                    hue: Theme.hue5
                }
                Battery {
                    id: quickBattery
                    anchors.verticalCenter: parent.verticalCenter
                    hue: Theme.hue3
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.power
                    font.family: Icons.regular
                    font.pixelSize: 16
                    color: Theme.hue1
                }
            }
        }
    }
}
