import QtQuick

// A 40px text field in the network panel (owner's design): 2px border, accent while focused, red
// with `error`. Optional leading `icon` (search), a clear button (`clearable`), and for a
// `password` an eye button that shows or hides it. edited() on typing, accepted() on Enter.
Rectangle {
    id: field
    property string placeholder
    property string icon: ""
    property bool password: false
    property bool clearable: false
    property bool error: false
    property bool reveal: false
    property alias text: input.text
    signal edited()
    signal accepted()
    function focusInput() { input.forceActiveFocus() }

    height: 40
    color: "transparent"
    border.width: 2
    border.color: error ? Theme.alert : input.activeFocus ? Theme.accent : Theme.border

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
        width: parent.width - x - (trail.visible ? 42 : 14)
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

        Text {
            visible: input.text === ""
            text: field.placeholder
            font: input.font
            color: Theme.fgMuted
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
