import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Quick settings (owner, 2026-10-20, from the "Quick settings panel" design): one panel from the
// chip at the bar's right end, merged into the frame's right side (EdgePanel's atRight), 380 wide.
// The top level: Wi-Fi and Bluetooth tiles (a click switches it, the › opens its view), Do Not
// Disturb and Keep awake; the volume, mic and brightness levels (click, drag or scroll; the
// volume's › opens the sound view); the battery card with the power profiles (laptop only); the
// power row (Lock, Log out, Suspend, Reboot, Shut down: .local/bin/power-action, the ones marked
// asking "Again?" within 3 s) and Settings. Each control in its own hue, idle ones neutral.
// The views (SoundView, then Bluetooth and Wi-Fi in the next steps) go on a StackView: a › pushes
// one, its back button or Escape pops it, closing the panel goes back to the top level. The panel
// keeps the top level's height (owner); a view scrolls inside it. openView(name) opens the panel
// straight on a view (`qs ipc call panel toggle sound`; again on the same view closes it).
PopupWindow {
    id: panel
    required property var bar
    required property var block
    signal settingsRequested

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width + reveal.overhang - implicitWidth // the body's right edge on the chip's
    anchor.rect.y: block.height + 6
    implicitWidth: reveal.implicitWidth
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }
    color: "transparent"
    grabFocus: false // EdgePanel's focus grab
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the chip
            visible = true
    }
    onVisibleChanged: {
        if (!visible) {
            closedAt = Date.now()
            armed = ""
            stack.pop(null, StackView.Immediate)
        } else {
            Sound.readTargets()
        }
    }

    readonly property var views: ({ sound: soundView })
    function openView(name) {
        const shown = stack.currentItem && stack.currentItem.viewName === name
        if (visible && shown) {
            reveal.close()
            return
        }
        stack.pop(null, StackView.Immediate)
        stack.push(views[name], {}, visible ? StackView.PushTransition : StackView.Immediate)
        visible = true
    }
    Component {
        id: soundView
        SoundView { onBack: stack.pop() }
    }

    // What the tiles and levels read.
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [panel.sink, panel.source] } // node properties stay live only while tracked
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter.enabled
    readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length
    readonly property var battery: UPower.displayDevice

    // The power action waiting for its confirming click (as the power panel).
    property string armed: ""
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: panel.armed = ""
    }
    function run(action, confirm) {
        if (confirm && armed !== action) {
            armed = action
            armTimer.restart()
            return
        }
        armed = ""
        reveal.close()
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/power-action", action])
    }

    // Brightness: brightnessctl per change would start a process per drag step, so the newest
    // value waits 60 ms and only that one is written. The level reads back through IslandState.
    property int brightnessWanted: -1
    Timer {
        id: brightnessTimer
        interval: 60
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", panel.brightnessWanted + "%"])
    }
    function setBrightness(v) {
        brightnessWanted = Math.round(Math.max(0.01, Math.min(1, v)) * 100) // never fully dark
        brightnessTimer.restart()
    }

    // A tile: an icon, its name and state; a click switches it. `drill`: a › at the right end
    // that opens its view. On: the frame tinted with its hue (as a chip), the icon filled.
    component Tile: Rectangle {
        id: tile
        property string glyph
        property string label
        property string status
        property color hue
        property bool on
        property bool drill: false
        signal toggled
        signal opened
        height: 64
        radius: 12
        color: Qt.tint(Edge.fill, on ? Qt.rgba(hue.r, hue.g, hue.b, tileHover.containsMouse ? 0.25 : 0.15)
            : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, tileHover.containsMouse ? 0.10 : 0.06))
        Behavior on color { ColorAnimation { duration: 150 } }
        MouseArea {
            id: tileHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.toggled()
        }
        Text {
            id: tileIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: tile.glyph
            font.family: tile.on ? Icons.fill : Icons.regular
            font.pixelSize: 20
            color: tile.on ? tile.hue : Theme.fgMuted
        }
        Column {
            x: 42
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (tile.drill ? 36 : 12)
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: tile.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: tile.status
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: tile.on ? tile.hue : Theme.fgMuted
            }
        }
        Rectangle { // the ›: its own target, so a click on it opens instead of switching
            visible: tile.drill
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 48
            radius: 8
            color: drillHover.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) : "transparent"
            Text {
                anchors.centerIn: parent
                text: Icons.caretRight
                font.family: Icons.regular
                font.pixelSize: 14
                color: Theme.fgMuted
            }
            MouseArea {
                id: drillHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tile.opened()
            }
        }
    }

    // A level: its icon (a click mutes, where `mutable`), a pill track filled in its hue with a
    // round knob, the number; click or drag sets it, the wheel steps 5%. `drill`: a › after it.
    component Level: Item {
        id: level
        property string glyph
        property color hue
        property real value // 0-1
        property bool off: false
        property bool mutable: false
        property bool drill: false
        signal moved(real v)
        signal muteToggled
        signal opened
        width: parent.width
        height: 36
        Text {
            id: levelIcon
            width: 20
            anchors.verticalCenter: parent.verticalCenter
            text: level.glyph
            font.family: Icons.regular
            font.pixelSize: 18
            color: level.off ? Theme.fgMuted : level.hue
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: level.mutable
                onClicked: level.muteToggled()
            }
        }
        Item {
            id: track
            x: 32
            width: parent.width - x - 12 - number.width - 40 // the › column stays on every level, so the bars line up
            height: parent.height
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10))
                Rectangle {
                    width: Math.max(height, parent.width * (level.off ? 0 : Math.min(level.value, 1)))
                    height: parent.height
                    radius: 4
                    visible: !level.off
                    color: level.hue
                }
            }
            Rectangle { // the knob
                x: (parent.width - width) * (level.off ? 0 : Math.min(level.value, 1))
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: Theme.fg
            }
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => level.moved(Math.max(0, Math.min(1, mouse.x / width)))
                onPositionChanged: mouse => { if (pressed) level.moved(Math.max(0, Math.min(1, mouse.x / width))) }
                onWheel: wheel => level.moved(Math.max(0, Math.min(1, level.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        Text {
            id: number
            x: track.x + track.width + 12
            width: 28
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: level.off ? "—" : Math.round(level.value * 100)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: level.off ? Theme.fgMuted : level.hue
        }
        Rectangle {
            visible: level.drill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 8
            color: levelDrillHover.containsMouse ? Edge.controlHover : Edge.control
            Text {
                anchors.centerIn: parent
                text: Icons.caretRight
                font.family: Icons.regular
                font.pixelSize: 14
                color: Theme.fgMuted
            }
            MouseArea {
                id: levelDrillHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: level.opened()
            }
        }
    }

    // A power profile choice in the battery card.
    component Profile: Rectangle {
        id: profile
        property string label
        property int value
        property bool available: true
        readonly property bool active: PowerProfiles.profile === value
        height: 28
        radius: 8
        opacity: available ? 1 : 0.4
        color: active ? Edge.accentTint : profileHover.containsMouse ? Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14))
            : Edge.controlHover
        Text {
            anchors.centerIn: parent
            text: profile.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: profile.active ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            id: profileHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: profile.available
            onClicked: PowerProfiles.profile = profile.value
        }
    }

    // A power button: its icon, or "Again?" on a red tint while it waits for the second click.
    component Power: Rectangle {
        id: power
        property string glyph
        property string action
        property bool confirm: false
        property color ink: Theme.fg
        readonly property bool waiting: panel.armed === action
        height: 48
        radius: 8
        color: waiting ? Edge.alertTint : powerHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            visible: !power.waiting
            anchors.centerIn: parent
            text: power.glyph
            font.family: Icons.regular
            font.pixelSize: 18
            color: power.ink
        }
        Text {
            visible: power.waiting
            anchors.centerIn: parent
            text: "Again?"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: Theme.alert
        }
        MouseArea {
            id: powerHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: power.action === "settings" ? (reveal.close(), panel.settingsRequested())
                : panel.run(power.action, power.confirm)
        }
    }

    EdgePanel {
        id: reveal
        window: panel
        atRight: true // at the bar's right end: merges into the frame's side
        bodyWidth: 380
        bodyHeight: column.implicitHeight + 24 // the top level's; views scroll in it

        focus: true
        Keys.onEscapePressed: stack.depth > 1 ? stack.pop() : reveal.close()

        // A view slides in from the right over the top level, and back out.
        StackView {
            id: stack
            width: parent.width
            height: reveal.bodyHeight
            clip: true
            initialItem: topLevel
            readonly property int pace: Settings.look.animations ? 250 : 0
            pushEnter: Transition { XAnimator { from: stack.width; to: 0; duration: stack.pace; easing.type: Easing.OutCubic } }
            pushExit: Transition { XAnimator { from: 0; to: -stack.width / 3; duration: stack.pace; easing.type: Easing.OutCubic } }
            popEnter: Transition { XAnimator { from: -stack.width / 3; to: 0; duration: stack.pace; easing.type: Easing.OutCubic } }
            popExit: Transition { XAnimator { from: 0; to: stack.width; duration: stack.pace; easing.type: Easing.OutCubic } }
        }

        Item {
            id: topLevel
        Column {
            id: column
            x: 16
            y: 8
            width: parent.width - 32
            spacing: 14

            Grid {
                width: parent.width
                columns: 2
                spacing: 8
                readonly property real cell: (width - spacing) / 2
                Tile {
                    width: parent.cell
                    glyph: panel.wired && panel.wifiNet === null ? Icons.network : Icons.wifiHigh
                    label: panel.wired && panel.wifiNet === null ? "Wired" : "Wi-Fi"
                    status: panel.wifiNet ? panel.wifiNet.name
                        : panel.wired ? "Connected"
                        : !Networking.wifiEnabled ? "Off"
                        : "Not connected"
                    hue: Theme.hue4
                    on: Networking.wifiEnabled && (panel.wifiNet !== null || panel.wired) || panel.wired
                    drill: true
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }
                Tile {
                    visible: panel.adapter !== null
                    width: parent.cell
                    glyph: panel.btConnected > 0 ? Icons.bluetoothConnected : panel.btOn ? Icons.bluetooth : Icons.bluetoothSlash
                    label: "Bluetooth"
                    status: !panel.btOn ? "Off" : panel.btConnected > 0 ? panel.btConnected + " connected" : "On"
                    hue: Theme.hue5
                    on: panel.btOn
                    drill: true
                    onToggled: panel.adapter.enabled = !panel.btOn
                }
                Tile {
                    width: parent.cell
                    glyph: Notifs.dnd ? Icons.bellSlash : Icons.bellSimple
                    label: "Do Not Disturb"
                    status: Notifs.dnd ? "On" : "Off"
                    hue: Theme.hue1
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Tile {
                    width: parent.cell
                    glyph: Icons.coffee
                    label: "Keep awake"
                    status: Tools.keepAwake ? "On" : "Off"
                    hue: Theme.hue2
                    on: Tools.keepAwake
                    onToggled: Tools.setKeepAwake(!Tools.keepAwake)
                }
            }

            Column {
                width: parent.width
                spacing: 2
                Level {
                    readonly property var audio: panel.sink && panel.sink.audio ? panel.sink.audio : null
                    visible: audio !== null
                    glyph: off ? Icons.speakerSlash : value <= 0 ? Icons.speakerNone : value < 0.5 ? Icons.speakerLow : Icons.speakerHigh
                    hue: Theme.hue6
                    value: audio ? audio.volume : 0
                    off: audio ? audio.muted : false
                    mutable: true
                    drill: true
                    onOpened: stack.push(soundView)
                    onMoved: v => audio.volume = v
                    onMuteToggled: audio.muted = !audio.muted
                }
                Level {
                    readonly property var audio: panel.source && panel.source.audio ? panel.source.audio : null
                    visible: audio !== null
                    glyph: off ? Icons.microphoneSlash : Icons.microphone
                    hue: Theme.hue1
                    value: audio ? audio.volume : 0
                    off: audio ? audio.muted : false
                    mutable: true
                    onMoved: v => audio.volume = v
                    onMuteToggled: audio.muted = !audio.muted
                }
                Level {
                    visible: IslandState.hasBrightness
                    glyph: Icons.sun
                    hue: Theme.hue2
                    value: panel.brightnessWanted >= 0 && brightnessTimer.running ? panel.brightnessWanted / 100 : IslandState.brightness
                    onMoved: v => panel.setBrightness(v)
                }
            }

            Rectangle { // laptop only
                id: batteryCard
                visible: panel.battery.ready && panel.battery.isLaptopBattery
                width: parent.width
                height: batteryColumn.implicitHeight + 24
                radius: 12
                color: Edge.control
                readonly property int levelNow: Math.round(panel.battery.percentage * 100)
                readonly property bool critical: UPower.onBattery && levelNow <= 10
                readonly property color ink: critical ? Theme.alert : Theme.hue3
                readonly property string timeText: {
                    const charging = panel.battery.state === UPowerDeviceState.Charging
                    const secs = UPower.onBattery ? panel.battery.timeToEmpty : charging ? panel.battery.timeToFull : 0
                    if (secs <= 0)
                        return UPower.onBattery ? "" : charging ? "Charging" : "Plugged in"
                    const h = Math.floor(secs / 3600)
                    const m = Math.floor(secs % 3600 / 60)
                    return (h > 0 ? h + " h " : "") + m + " min" + (UPower.onBattery ? " left" : " to full")
                }
                Column {
                    id: batteryColumn
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 10
                    Item {
                        width: parent.width
                        height: 22
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.battery(batteryCard.levelNow, UPower.onBattery, batteryCard.critical)
                                font.family: Icons.regular
                                font.pixelSize: 20
                                color: batteryCard.ink
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryCard.levelNow + "%"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                color: batteryCard.ink
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: batteryCard.timeText
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }
                    }
                    Rectangle { // the level, a pill
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.tint(Edge.fill, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10))
                        Rectangle {
                            width: parent.width * Math.min(1, panel.battery.percentage)
                            height: parent.height
                            radius: 3
                            color: batteryCard.ink
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 4
                        readonly property real cell: (width - 2 * spacing) / 3
                        Profile { width: parent.cell; label: "Saver"; value: PowerProfile.PowerSaver }
                        Profile { width: parent.cell; label: "Balanced"; value: PowerProfile.Balanced }
                        Profile { width: parent.cell; label: "Performance"; value: PowerProfile.Performance; available: PowerProfiles.hasPerformanceProfile }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 4
                readonly property real cell: (width - 5 * spacing) / 6
                Power { width: parent.cell; glyph: Icons.lock; action: "lock" }
                Power { width: parent.cell; glyph: Icons.signOut; action: "logout"; confirm: true }
                Power { width: parent.cell; glyph: Icons.moon; action: "suspend" }
                Power { width: parent.cell; glyph: Icons.arrowClockwise; action: "reboot"; confirm: true }
                Power { width: parent.cell; glyph: Icons.power; action: "poweroff"; confirm: true; ink: Theme.hue1 }
                Power { width: parent.cell; glyph: Icons.gear; action: "settings"; ink: Theme.fgMuted }
            }
        }
        }
    }
}
