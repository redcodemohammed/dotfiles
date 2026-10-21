import QtQuick
import QtQuick.Controls
import Quickshell

// Settings panel (owner, 2026-10-17; the "Remaining panels" design since 2026-10-20): opened from
// quick settings' Settings button (or `qs ipc call settings toggle`), it comes out of the frame
// under the same chip, 380 wide. Values live in Settings.qml; a change is saved at once and
// reaches Hyprland and Alacritty 300 ms later.
// The top level: back (to quick settings), then the four sections as rows, each in its hue with
// a live summary: Look (4a), Input (4b), Bar & island (4c), Power (4d: the idle chain). A row
// pushes its view on a StackView, as quick settings' views: it slides in, back or Escape pops it,
// closing returns to the top level. In a view the settings sit on cards by group, steppers (−
// value +) and switches. The panel takes the shown view's height.
PopupWindow {
    id: panel
    required property var bar
    required property var block
    signal backRequested // the top level's back button: quick settings

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
    onVisibleChanged: {
        if (!visible) {
            stack.pop(null, StackView.Immediate)
        }
    }

    function tint(c, a) { return Qt.tint(Edge.fill, Qt.rgba(c.r, c.g, c.b, a)) }
    readonly property color lift: tint(Theme.fg, 0.12) // a control on a card
    readonly property color liftHover: tint(Theme.fg, 0.18)

    component Label: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
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
        height: 40
        opacity: available ? 1 : 0.5
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: stepper.label
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            StepButton { text: "−"; enabled: stepper.available && stepper.value > stepper.low; onClicked: stepper.picked(Math.max(stepper.low, stepper.value - stepper.step)) }
            Label {
                width: 60
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
        color: stepHover.containsMouse && enabled ? panel.liftHover : panel.lift
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
        height: 40
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
    // A group: its caption, then its rows on one card.
    component Group: Column {
        id: group
        property string title
        default property alias rows: card.data
        width: parent.width
        spacing: 6
        Text {
            leftPadding: 4
            text: group.title
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
        Rectangle {
            width: parent.width
            height: card.implicitHeight + 8
            radius: 12
            color: Edge.control
            Column {
                id: card
                x: 12
                y: 4
                width: parent.width - 24
            }
        }
    }
    component Note: Text {
        width: parent.width
        leftPadding: 4
        wrapMode: Text.Wrap
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgDim
    }
    // A section's view: the header, then its groups (`content`), scrolling past the screen.
    component SectionView: Item {
        id: sectionView
        property string title
        default property alias content: viewColumn.data
        implicitHeight: Math.min(header.height + 8 + viewColumn.implicitHeight + 16,
            panel.bar.screen.height - panel.bar.height - Settings.look.frame - 32)
        ViewHeader {
            id: header
            title: sectionView.title
            onBack: stack.pop()
        }
        Flickable {
            y: header.height + 8
            width: parent.width
            height: parent.height - y
            contentHeight: viewColumn.implicitHeight + 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: viewColumn
                x: 16
                width: parent.width - 32
                spacing: 14
            }
        }
    }
    // A section on the top level: its hue, name and summary, a › to its view.
    component SectionRow: Rectangle {
        id: sectionRow
        property string label
        property string summary
        property string glyph
        property color hue
        property Component view
        width: parent.width
        height: 56
        radius: 12
        color: rowHover.containsMouse ? Edge.controlHover : Edge.control
        Rectangle {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 8
            color: panel.tint(sectionRow.hue, 0.15)
            Text {
                anchors.centerIn: parent
                text: sectionRow.glyph
                font.family: Icons.regular
                font.pixelSize: 16
                color: sectionRow.hue
            }
        }
        Column {
            x: 56
            width: parent.width - x - 36
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label { text: sectionRow.label }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: sectionRow.summary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.caretRight
            font.family: Icons.regular
            font.pixelSize: 14
            color: Theme.fgMuted
        }
        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: stack.push(sectionRow.view)
        }
    }

    EdgePanel { // comes out of the frame under its chip (owner, 2026-10-20)
        id: reveal
        window: panel
        atRight: true // at the bar's right end: merges into the frame's side
        bodyWidth: 380
        bodyHeight: stack.currentItem ? stack.currentItem.implicitHeight : topLevel.implicitHeight

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

        Item { // the top level
            id: topLevel
            implicitHeight: topHeader.height + 8 + sections.implicitHeight + 16
            ViewHeader {
                id: topHeader
                title: "Settings"
                onBack: { reveal.close(); panel.backRequested() }
            }
            Column {
                id: sections
                x: 16
                y: topHeader.height + 8
                width: stack.width - 32
                spacing: 8
                SectionRow {
                    label: "Look"
                    glyph: Icons.eye
                    hue: Theme.hue1
                    summary: "Gaps " + Settings.look.gapsBetween + " · frame " + Settings.look.frame
                        + " · blur " + (Settings.look.blur ? "on" : "off") + " · animations " + (Settings.look.animations ? "on" : "off")
                    view: lookView
                }
                SectionRow {
                    label: "Input"
                    glyph: Icons.lightning
                    hue: Theme.hue3
                    summary: "Repeat " + Settings.input.repeatDelay + " ms, " + Settings.input.repeatRate + "/s · pointer "
                        + (Settings.input.pointerSpeed / 10).toFixed(1)
                    view: inputView
                }
                SectionRow {
                    label: "Bar & island"
                    glyph: Icons.monitor
                    hue: Theme.hue2
                    summary: (Settings.bar.clock24 ? "24-hour" : "12-hour") + " clock · " + Settings.bar.workspaces + " workspaces"
                        + (Settings.bar.islandMedia ? " · media" : "")
                    view: barView
                }
                SectionRow {
                    label: "Power"
                    glyph: Icons.power
                    hue: Theme.hue4
                    summary: "Lock " + Settings.power.lockAfter + " min · screens off " + Settings.power.screenOffAfter + " min"
                        + (Settings.power.sleep ? " · sleep " + Settings.power.sleepAfter + " min" : "")
                    view: powerView
                }
                Note {
                    topPadding: 4
                    text: "Saved at once. Pomodoro lengths: in its panel. Lyrics: in the expanded media island."
                }
            }
        }

        Component {
            id: lookView
            SectionView {
                title: "Look"
                Group {
                    title: "Windows"
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
                }
                Group {
                    title: "Frame"
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
                    Item { // ‹ screen ›: cycles Off and each screen by model; "" (the main screen) shows as its model
                        id: corner
                        readonly property string mainModel: Quickshell.env("DESKTOP_MAIN_MODEL") ?? ""
                        readonly property string value: Settings.look.cornerScreen !== "" ? Settings.look.cornerScreen
                            : mainModel !== "" ? mainModel : (Quickshell.screens.length > 0 ? Quickshell.screens[0].model : "off")
                        readonly property var options: [{ value: "off", label: "Off" }].concat(
                            Quickshell.screens.map(s => ({ value: s.model, label: s.model || s.name })))
                        readonly property int at: Math.max(0, options.findIndex(o => o.value === value))
                        function move(by) {
                            Settings.look.cornerScreen = options[(at + by + options.length) % options.length].value
                        }
                        width: parent.width
                        height: 40
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Corner widget"
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            StepButton { text: "‹"; onClicked: corner.move(-1) }
                            Label {
                                width: 120
                                height: 28
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: corner.options[corner.at].label
                            }
                            StepButton { text: "›"; onClicked: corner.move(1) }
                        }
                    }
                }
                Group {
                    title: "See-through"
                    Stepper {
                        label: "Terminal opacity"
                        value: Settings.look.terminalOpacity
                        low: 70; high: 100; step: 5; unit: " %"
                        onPicked: (v) => Settings.look.terminalOpacity = v
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
                }
                Group {
                    title: "Motion"
                    Toggle {
                        label: "Animations"
                        on: Settings.look.animations
                        onPicked: (on) => Settings.look.animations = on
                    }
                }
            }
        }

        Component {
            id: inputView
            SectionView {
                title: "Input"
                Group {
                    title: "Keyboard"
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
                }
                Group {
                    title: "Mouse and touchpad"
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
            }
        }

        Component {
            id: barView
            SectionView {
                title: "Bar & island"
                Group {
                    title: "Clock"
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
                }
                Group {
                    title: "Screens"
                    Toggle {
                        label: "Bars on other screens"
                        on: Settings.bar.otherScreens
                        onPicked: (on) => Settings.bar.otherScreens = on
                    }
                    Stepper { // the same on every screen: hyprsplit has one count (SUPER + 1-9, 0 is the 10th)
                        label: "Workspaces per screen"
                        value: Settings.bar.workspaces
                        low: 1; high: 10
                        onPicked: (v) => Settings.bar.workspaces = v
                    }
                }
                Group {
                    title: "Island"
                    Toggle {
                        label: "Media in the island"
                        on: Settings.bar.islandMedia
                        onPicked: (on) => Settings.bar.islandMedia = on
                    }
                }
                Note { text: "Pomodoro lengths: in its panel. Lyrics: in the expanded media island." }
            }
        }

        Component {
            id: powerView
            SectionView {
                title: "Power"
                Group {
                    title: "When idle"
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
                }
                Note {
                    text: Tools.keepAwake ? "Keep awake is on: none of this runs until it is off." : "Idle time: no keyboard or mouse input."
                }
            }
        }
    }
}
