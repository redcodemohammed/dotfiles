import QtQuick
import Quickshell
import Quickshell.Wayland

// The phone's incoming-call card (owner's design "Phone bridge", 2026-10-15): while the phone rings,
// a 420 wide card under the bar's phone block, its right edge on the block's, panel or not (an open
// panel drops below it). "Incoming call" and Ringing (Muted after a mute), the caller (name and
// number), and Mute ring (`kcd call mute`; Reject left out: the Android app can't). A layer-shell
// window, not a popup, so it never takes the keyboard.
PanelWindow {
    id: card
    required property var bar
    required property var block // the bar's phone block
    // The block's right edge in the bar (its Row sits at the bar's right).
    readonly property real blockRight: block.parent.x + block.x + block.width

    screen: bar.screen
    visible: Phone.call !== null && Phone.connected && block.visible
    anchors {
        top: true
        right: true
    }
    margins {
        top: 6 + bar.height + 4 // under the bar, which floats 6px down
        right: 6 + bar.width - blockRight
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitWidth: 420
    implicitHeight: body.height
    color: "transparent"

    Rectangle {
        id: body
        width: 420
        height: col.implicitHeight + 28
        color: Theme.bg
        border.width: 2
        border.color: Theme.border

        Column {
            id: col
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            Item {
                width: parent.width
                height: 20
                Text {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.phoneIncoming
                    font.family: Icons.regular
                    font.pixelSize: 16
                    color: Theme.fg
                }
                Text {
                    x: glyph.width + 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Incoming call"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Phone.call && Phone.call.muted ? "Muted" : "Ringing"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fgMuted
                }
            }
            Text {
                width: parent.width
                text: !Phone.call ? "" : Phone.call.number && Phone.call.number !== Phone.call.name
                    ? Phone.call.name + " · " + Phone.call.number : Phone.call.name
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
            PanelButton {
                width: parent.width
                label: Phone.call && Phone.call.muted ? "Muted" : "Mute ring"
                available: !(Phone.call && Phone.call.muted)
                onPressed: Phone.muteCall()
            }
        }
    }
}
