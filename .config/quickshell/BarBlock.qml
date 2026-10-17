import QtQuick

// One bar widget on its own background. The bar itself is transparent, so each widget floats
// (owner, 2026-10-15): the bar's 32px height, the bar colour, a subtle 2px border like the
// notch, square, 8px side padding.
Rectangle {
    id: block
    default property alias content: inner.data
    property int padding: 8
    implicitWidth: inner.width + 2 * padding
    implicitHeight: 32
    color: Theme.bg
    border.width: 2 // the notch's subtle border, drawn inside the 32px (owner)
    border.color: Theme.border
    property bool clickable: false
    signal clicked()

    // The entrance (Entrance.qml): drops in from above the screen on the window spring, a little
    // later the further right it sits, so the bar fills in left to right. Twice the windows'
    // pace (owner: slower): 600 ms, spread over 480 ms.
    transform: Translate { id: shift; y: Entrance.covered ? -48 : 0 } // hidden above while the sheet waits
    Connections {
        target: Entrance
        function onRunChanged() {
            const screenWidth = block.Window.window ? block.Window.window.width : 1920
            drop.delay = Math.round(block.mapToItem(null, 0, 0).x / screenWidth * 480)
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
        anchors.fill: parent
        enabled: block.clickable
        onClicked: block.clicked()
    }

    Item {
        id: inner
        x: block.padding
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
