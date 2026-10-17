import QtQuick

// One item inside a grouped bar block (owner, 2026-10-17: the right side went from 13 blocks to
// 5). 28 tall inside the block's 2px border, 6px side padding, so neighbouring cells' hover areas
// meet. Clickable cells lighten on hover and emit clicked(); a panel anchored to a cell drops
// under it. Content goes inside, as with BarBlock.
Item {
    id: cell
    default property alias content: inner.data
    property bool clickable: false
    signal clicked()
    implicitWidth: inner.width + 12
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        color: cell.clickable && hover.containsMouse ? Theme.surfaceSelected : "transparent"
    }
    MouseArea { // under the content, so a widget's own mouse areas still win
        id: hover
        anchors.fill: parent
        hoverEnabled: cell.clickable
        enabled: cell.clickable
        onClicked: cell.clicked()
    }
    Item {
        id: inner
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
