import QtQuick

// A notification's actions as a row of buttons, wrapping to more lines when they don't fit
// (owner, 2026-10-17: screenshot and recording notifications carry Copy, Send to phone, ...).
// The default action comes first, primary, labelled with its own text. Used by the island and
// the inbox for notifications with more than one action; one action stays the island's Reply.
// dismissLabel: adds a last, plain button that only emits dismissed().
// oneLineWidth: what every button needs side by side; the island and the inbox grow to it, so the
// actions sit on one line (owner, 2026-10-17). Narrower than that, they wrap.
Flow {
    id: root
    required property var entry
    property int buttonHeight: 40
    property string dismissLabel: ""
    property string family: "JetBrainsMono Nerd Font"
    signal invoked
    signal dismissed

    readonly property var actions: {
        const all = entry && entry.notification ? entry.notification.actions : []
        return all.filter(a => a.identifier === "default").concat(all.filter(a => a.identifier !== "default"))
    }

    spacing: 4

    readonly property real oneLineWidth: {
        let total = 0, count = 0
        for (const child of children)
            if (child.counted) { // not `visible`: that is false while the island or inbox is hidden
                total += child.width
                count++
            }
        return count > 0 ? total + spacing * (count - 1) : 0
    }

    component Button: Rectangle {
        id: button
        property string label
        property bool primary
        property bool counted: true
        signal clicked
        width: text.implicitWidth + 24
        height: root.buttonHeight
        color: primary ? Theme.surfaceSelected : Theme.surface
        border.width: 2
        border.color: Theme.border
        Text {
            id: text
            anchors.centerIn: parent
            text: button.label
            font.family: root.family
            font.pixelSize: 13
            color: button.primary ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            anchors.fill: parent
            onClicked: button.clicked()
        }
    }

    Repeater {
        model: root.actions
        Button {
            required property var modelData
            label: modelData.text.trim() !== "" ? modelData.text : modelData.identifier
            primary: modelData.identifier === "default"
            onClicked: {
                modelData.invoke()
                root.invoked()
            }
        }
    }

    Button {
        visible: counted
        counted: root.dismissLabel !== ""
        label: root.dismissLabel
        onClicked: root.dismissed()
    }
}
