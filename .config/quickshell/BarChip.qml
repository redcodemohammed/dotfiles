import QtQuick

// One bar item on its own chip (owner, 2026-10-20; BarBlock and BarCell before): 32px tall,
// rounded 8, no border, 8px side padding. `neutral` (every chip since 2026-10-25, owner: less
// colour): a faint lift of the frame. Otherwise the frame with 15% of `hue` mixed in: only a
// chip that alerts (red) does that now. Only the hue's colour counts, not its alpha. Clickable chips deepen on
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
