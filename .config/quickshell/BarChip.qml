import QtQuick

// One bar item on its own chip (owner, 2026-10-20: more colour; BarBlock and BarCell before):
// 32px tall, rounded 8, no border, 8px side padding. The chip is the frame's colour with 15% of
// its hue mixed in, and its widget draws in the hue (palette hue1-hue6, lifted to 4.5:1 on such
// a chip by from-wallpaper.py). Only the hue's colour counts here, not its alpha, so a widget's
// dimmed ink (an idle state) still gives a full chip. `neutral`: no hue, a faint lift of the
// frame (the title, the tray, the workspaces, recording while idle). Clickable chips deepen on
// hover and emit clicked(); a panel anchored to a chip drops under it.
Rectangle {
    id: chip
    default property alias content: inner.data
    property color hue: Theme.fg
    property bool neutral: false
    property int padding: 8
    property bool clickable: false
    signal clicked()

    readonly property bool hovered: clickable && hover.containsMouse
    readonly property real strength: neutral ? (hovered ? 0.10 : 0.06) : (hovered ? 0.25 : 0.15)
    readonly property color base: neutral ? Theme.fg : hue
    implicitWidth: inner.width + 2 * padding
    implicitHeight: 32
    radius: 8
    color: Qt.tint(Edge.fill, Qt.rgba(base.r, base.g, base.b, strength))
    Behavior on color { ColorAnimation { duration: 150 } }

    // The entrance (Entrance.qml): drops in from above the screen on the window spring, a little
    // later the further right it sits, so the bar fills in left to right. Twice the windows'
    // pace (owner: slower): 600 ms, spread over 480 ms.
    transform: Translate { id: shift; y: Entrance.covered ? -48 : 0 } // hidden above while the sheet waits
    Connections {
        target: Entrance
        function onRunChanged() {
            const screenWidth = chip.Window.window ? chip.Window.window.width : 1920
            drop.delay = Math.round(chip.mapToItem(null, 0, 0).x / screenWidth * 480)
            shift.y = -48
            drop.restart()
        }
    }
    SequentialAnimation {
        id: drop
        property int delay: 0
        PauseAnimation { duration: drop.delay }
        NumberAnimation {
            target: shift
            property: "y"
            to: 0
            duration: 600
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.3, 0.64, 1, 1, 1] // hyprland.lua "spring"
        }
    }

    MouseArea { // under the content, so a widget's own mouse areas still win
        id: hover
        anchors.fill: parent
        hoverEnabled: chip.clickable
        enabled: chip.clickable
        onClicked: chip.clicked()
    }

    Item {
        id: inner
        x: chip.padding
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
