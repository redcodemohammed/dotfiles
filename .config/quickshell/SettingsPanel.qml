import QtQuick
import Quickshell

// Settings panel (owner, 2026-10-17): opened from the power panel's Settings button (or
// `qs ipc call settings toggle`), it drops from the same power block, 360 wide. Values live in
// Settings.qml; a change is saved at once and reaches Hyprland and Alacritty 300 ms later.
// Tabs: Look (4a), Input (4b), Bar & island (4c), Power (4d: the idle chain).
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width + reveal.overhang - implicitWidth // the body's right edge on the chip's
    anchor.rect.y: block.height + 6
    implicitWidth: reveal.implicitWidth
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }
    color: "transparent"
    grabFocus: false // an outside click goes through EdgePanel's focus grab, so closing can slide
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: if (!visible) closedAt = Date.now()
    property string tab: "look" // stays on the last one between openings

    component Label: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fg
    }

    // − value +: steps `value` by `step` between `low` and `high`; `picked` gets the new value.
    component Stepper: Item {
        id: stepper
        property string label
        property int value
        property int low
        property int high
        property int step: 1
        property string unit: ""
        property int divisor: 1 // 10: the value is in tenths, shown as 0.3
        property bool available: true
        signal picked(int value)
        width: parent.width
        height: 28
        opacity: available ? 1 : 0.5
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: stepper.label
        }
        Row {
            anchors.right: parent.right
            spacing: 4
            StepButton { text: "−"; enabled: stepper.available && stepper.value > stepper.low; onClicked: stepper.picked(Math.max(stepper.low, stepper.value - stepper.step)) }
            Label {
                width: 56
                height: 28
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: (stepper.divisor === 1 ? stepper.value : (stepper.value / stepper.divisor).toFixed(1)) + stepper.unit
            }
            StepButton { text: "+"; enabled: stepper.available && stepper.value < stepper.high; onClicked: stepper.picked(Math.min(stepper.high, stepper.value + stepper.step)) }
        }
    }
    component StepButton: Rectangle {
        id: stepButton
        property alias text: stepText.text
        signal clicked
        width: 28
        height: 28
        radius: 8
        color: stepHover.containsMouse && enabled ? Edge.controlHover : Edge.control
        Label {
            id: stepText
            anchors.centerIn: parent
            color: stepButton.enabled ? Theme.fg : Theme.fgDim
        }
        MouseArea {
            id: stepHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (stepButton.enabled) stepButton.clicked()
        }
    }
    // A label and an on/off switch.
    component Toggle: Item {
        id: toggle
        property string label
        property bool on
        signal picked(bool on)
        width: parent.width
        height: 28
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: toggle.label
        }
        PanelSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: toggle.on
            onToggled: toggle.picked(!toggle.on)
        }
    }


    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        atRight: true // at the bar's right end: merges into the frame's side
        bodyWidth: 360
        bodyHeight: column.implicitHeight + 24

        focus: true
        Keys.onEscapePressed: reveal.close()

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 4

            Row {
                width: parent.width
                readonly property real cell: width / 4
                SettingsTab { width: parent.cell; tab: panel.tab; label: "Look"; section: "look"; onChosen: panel.tab = section }
                SettingsTab { width: parent.cell; tab: panel.tab; label: "Input"; section: "input"; onChosen: panel.tab = section }
                SettingsTab { width: parent.cell; tab: panel.tab; label: "Bar"; section: "bar"; onChosen: panel.tab = section }
                SettingsTab { width: parent.cell; tab: panel.tab; label: "Power"; section: "power"; onChosen: panel.tab = section }
            }
            Item { width: 1; height: 4 }

            Column {
            visible: panel.tab === "look"
            width: parent.width
            spacing: 4
            Stepper {
                label: "Gap between windows"
                value: Settings.look.gapsBetween
                low: 0; high: 24; step: 2; unit: " px"
                onPicked: (v) => Settings.look.gapsBetween = v
            }
            Stepper {
                label: "Gap at screen edges"
                value: Settings.look.gapsEdge
                low: 0; high: 24; step: 2; unit: " px"
                onPicked: (v) => Settings.look.gapsEdge = v
            }
            Stepper {
                label: "Frame width"
                value: Settings.look.frame
                low: 4; high: 24; step: 2; unit: " px"
                onPicked: (v) => Settings.look.frame = v
            }
            Stepper { // windows round to this minus the edge gap, so the two curves nest
                label: "Frame corners"
                value: Settings.look.frameRadius
                low: 0; high: 32; step: 2; unit: " px"
                onPicked: (v) => Settings.look.frameRadius = v
            }
            Stepper {
                label: "Border"
                value: Settings.look.border
                low: 1; high: 4; unit: " px" // not 0: the border shows which window has focus
                onPicked: (v) => Settings.look.border = v
            }
            Toggle {
                label: "Blur behind see-through apps"
                on: Settings.look.blur
                onPicked: (on) => Settings.look.blur = on
            }
            Stepper {
                label: "Blur strength"
                value: Settings.look.blurSize
                low: 2; high: 12
                available: Settings.look.blur
                onPicked: (v) => Settings.look.blurSize = v
            }
            Stepper {
                label: "Terminal opacity"
                value: Settings.look.terminalOpacity
                low: 70; high: 100; step: 5; unit: " %"
                onPicked: (v) => Settings.look.terminalOpacity = v
            }
            Toggle {
                label: "Animations"
                on: Settings.look.animations
                onPicked: (on) => Settings.look.animations = on
            }
            }

            Column {
            visible: panel.tab === "input"
            width: parent.width
            spacing: 4
            Stepper {
                label: "Key repeat delay"
                value: Settings.input.repeatDelay
                low: 200; high: 600; step: 50; unit: " ms"
                onPicked: (v) => Settings.input.repeatDelay = v
            }
            Stepper {
                label: "Key repeat rate"
                value: Settings.input.repeatRate
                low: 20; high: 50; step: 5; unit: "/s"
                onPicked: (v) => Settings.input.repeatRate = v
            }
            Stepper {
                label: "Pointer speed"
                value: Settings.input.pointerSpeed
                low: -10; high: 10; divisor: 10 // every mouse and touchpad alike
                onPicked: (v) => Settings.input.pointerSpeed = v
            }
            Toggle {
                label: "Natural scrolling (touchpad)"
                on: Settings.input.naturalScroll
                onPicked: (on) => Settings.input.naturalScroll = on
            }
            Toggle {
                label: "Tap to click"
                on: Settings.input.tapToClick
                onPicked: (on) => Settings.input.tapToClick = on
            }
            }

            Column {
            visible: panel.tab === "bar"
            width: parent.width
            spacing: 4
            Toggle {
                label: "24-hour clock"
                on: Settings.bar.clock24
                onPicked: (on) => Settings.bar.clock24 = on
            }
            Toggle {
                label: "Seconds"
                on: Settings.bar.seconds
                onPicked: (on) => Settings.bar.seconds = on
            }
            Toggle {
                label: "Bars on other screens"
                on: Settings.bar.otherScreens
                onPicked: (on) => Settings.bar.otherScreens = on
            }
            Toggle {
                label: "Media in the island"
                on: Settings.bar.islandMedia
                onPicked: (on) => Settings.bar.islandMedia = on
            }
            Stepper { // the same on every screen: hyprsplit has one count (SUPER + 1-9, 0 is the 10th)
                label: "Workspaces per screen"
                value: Settings.bar.workspaces
                low: 1; high: 10
                onPicked: (v) => Settings.bar.workspaces = v
            }
            Text { // where the rest lives
                width: parent.width
                topPadding: 4
                wrapMode: Text.Wrap
                text: "Pomodoro lengths: in its panel. Lyrics: in the expanded media island."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }
            }

            Column {
            visible: panel.tab === "power"
            width: parent.width
            spacing: 4
            Stepper {
                label: "Lock after"
                value: Settings.power.lockAfter
                low: 2; high: 30; unit: " min"
                onPicked: (v) => Settings.power.lockAfter = v
            }
            Stepper {
                label: "Screens off, after lock"
                value: Settings.power.screenOffAfter
                low: 1; high: 10; unit: " min"
                onPicked: (v) => Settings.power.screenOffAfter = v
            }
            Toggle {
                label: "Sleep on battery"
                on: Settings.power.sleep
                onPicked: (on) => Settings.power.sleep = on
            }
            Stepper {
                label: "Sleep after"
                value: Settings.power.sleepAfter
                low: 10; high: 120; step: 10; unit: " min"
                available: Settings.power.sleep
                onPicked: (v) => Settings.power.sleepAfter = v
            }
            Text {
                width: parent.width
                topPadding: 4
                wrapMode: Text.Wrap
                text: Tools.keepAwake ? "Keep awake is on: none of this runs until it is off." : "Idle time: no keyboard or mouse input."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgDim
            }
            }
        }
    }
}
