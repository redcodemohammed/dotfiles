import QtQuick
import Quickshell

// The internet fails (NetState.internet): "No internet" on a red tint with Retry, or "Sign-in
// required" with Open login page, which opens NetworkManager's check page (a sign-in portal
// intercepts it and shows its login) and emits loginOpened so the panel can close. Hidden
// otherwise. On quick settings' top level and the Wi-Fi view (owner, 2026-10-20; the network
// panel's box before).
Rectangle {
    id: card
    signal loginOpened
    readonly property bool bad: NetState.internet === "none"
    visible: bad || NetState.internet === "portal"
    width: parent.width
    height: visible ? 56 : 0
    radius: 12
    color: bad ? Edge.alertTint : Edge.control

    Text {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.warningCircle
        font.family: Icons.regular
        font.pixelSize: 18
        color: card.bad ? Theme.alert : Theme.fg
    }
    Column {
        x: 42
        anchors.verticalCenter: parent.verticalCenter
        width: button.x - x - 8
        spacing: 2
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: NetState.checking ? "Checking connection" : card.bad ? "No internet" : "Sign-in required"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.bad ? "Connected, nothing gets through" : "This network wants a login"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }
    }
    PanelButton {
        id: button
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        label: card.bad ? "Retry" : "Log in"
        onPressed: {
            if (!card.bad) {
                Quickshell.execDetached(["xdg-open", "http://ping.archlinux.org/nm-check.txt"])
                card.loginOpened()
            }
            NetState.check()
        }
    }
}
