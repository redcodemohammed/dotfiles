import QtQuick
import Quickshell

// Settings panel (owner, 2026-10-17): opened from the tools panel's Settings button (or
// `qs ipc call settings toggle`), it drops from the same power block, 360 wide. Values live in
// Settings.qml; a change is saved at once and reaches Hyprland and Alacritty 300 ms later.
// Step 4a: Look. Next: Input, Bar & island, Displays & power.
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: block.width - implicitWidth
    anchor.rect.y: block.height + 4
    implicitWidth: 360
    implicitHeight: body.implicitHeight
    color: "transparent"
    grabFocus: true
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            visible = false
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: if (!visible) closedAt = Date.now()

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
                text: stepper.value + stepper.unit
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
        color: stepHover.containsMouse && enabled ? Theme.surfaceSelected : Theme.bg
        border.width: 2
        border.color: Theme.border
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

    Rectangle {
        id: body
        width: parent.width
        implicitHeight: column.implicitHeight + 24
        color: Theme.surface
        border.width: 2
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: panel.visible = false

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 4

            Text {
                text: "Look"
                bottomPadding: 4
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }

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
                label: "Window fade"
                on: Settings.look.animations
                onPicked: (on) => Settings.look.animations = on
            }
        }
    }
}
