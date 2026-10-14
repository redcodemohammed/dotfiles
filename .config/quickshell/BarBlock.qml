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

    Item {
        id: inner
        x: block.padding
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
