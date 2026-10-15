import QtQuick

// A 40px button in the network panel (owner's design "Network manager"): a 2px border on the panel
// colour. `primary`: accent fill (Connect, Join); `danger`: red border; `muted`: grey label
// (Forget). With an `icon` the glyph and label sit left (Join hidden network), else centred.
// Without a width it fits its label with 16px each side. `available: false` dims it.
Rectangle {
    id: button
    property string label
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property bool muted: false
    property bool available: true
    signal pressed()

    implicitWidth: content.width + 32
    height: 40
    color: primary ? Theme.accent : area.containsMouse ? Theme.surface : Theme.bg
    border.width: 2
    border.color: primary ? Theme.accent : danger ? Theme.alert : Theme.border
    opacity: available ? 1 : 0.5

    Row {
        id: content
        x: button.icon !== "" ? 14 : (parent.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
            visible: button.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: button.icon
            font.family: Icons.regular
            font.pixelSize: 16
            color: Theme.fgMuted
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: button.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: button.primary ? Theme.textOnAccent : button.muted ? Theme.fgMuted : Theme.fg
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.available
        onClicked: button.pressed()
    }
}
