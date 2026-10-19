import QtQuick

// A 40px text field in the network panel (owner's design): rounded 8 on the control fill (owner,
// 2026-10-20); the 2px outline only as the focus ring, accent while focused, red with `error`. Optional leading `icon` (search), a clear button (`clearable`), and for a
// `password` an eye button that shows or hides it. edited() on typing, accepted() on Enter,
// upPressed() / downPressed() for the arrow keys (the network list's keyboard moves). `action`: a
// small accent button inside the field with that label (the phone panel's Send); it emits accepted().
Rectangle {
    id: field
    property string placeholder
    property string icon: ""
    property bool password: false
    property bool clearable: false
    property bool error: false
    property bool reveal: false
    property string action: ""
    property alias text: input.text
    readonly property bool focused: input.activeFocus
    signal edited()
    signal accepted()
    signal upPressed()
    signal downPressed()
    function focusInput() { input.forceActiveFocus() }

    height: 40
    radius: 8
    color: Edge.control
    border.width: error || input.activeFocus ? 2 : 0
    border.color: error ? Theme.alert : Theme.accent

    Text {
        id: lead
        visible: field.icon !== ""
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: field.icon
        font.family: Icons.regular
        font.pixelSize: 16
        color: Theme.fgMuted
    }

    TextInput {
        id: input
        x: lead.visible ? 38 : 14
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - (trail.visible ? 42 : actionButton.visible ? actionButton.width + 18 : 14)
        clip: true
        echoMode: field.password && !field.reveal ? TextInput.Password : TextInput.Normal
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.textOnAccent
        selectByMouse: true
        onTextEdited: field.edited()
        onAccepted: field.accepted()
        Keys.onUpPressed: field.upPressed()
        Keys.onDownPressed: field.downPressed()

        Text {
            visible: input.text === ""
            text: field.placeholder
            font: input.font
            color: Theme.fgMuted
        }
    }

    Rectangle {
        id: actionButton
        visible: field.action !== ""
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: actionText.implicitWidth + 16
        height: 24
        radius: 6
        color: Theme.accent
        Text {
            id: actionText
            anchors.centerIn: parent
            text: field.action
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.textOnAccent
        }
        MouseArea {
            anchors.fill: parent
            onClicked: field.accepted()
        }
    }

    Item {
        id: trail
        visible: field.password || (field.clearable && input.text !== "")
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        Text {
            anchors.centerIn: parent
            text: field.password ? (field.reveal ? Icons.eyeSlash : Icons.eye) : Icons.cross
            font.family: Icons.regular
            font.pixelSize: field.password ? 16 : 12
            color: Theme.fgMuted
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (field.password) {
                    field.reveal = !field.reveal
                } else {
                    input.clear()
                    field.edited()
                }
            }
        }
    }
}
