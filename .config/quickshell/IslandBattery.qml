import QtQuick
import Quickshell.Services.UPower

// Island battery state (design: Desktop prototype, isBattery / isBatteryOpen).
// Compact 260x24: plug state, muted percent, glyph. Expanded 340x148: big percent with plug state
// and time, percent bar, power profile picker (power-profiles-daemon).
// Critical: the island draws a red border; the warning glyph is red too.
Item {
    id: root
    required property bool open
    readonly property var device: UPower.displayDevice
    readonly property int level: IslandState.batteryLevel
    readonly property bool critical: IslandState.batteryCritical
    // The design knows Charging and Unplugged; "Plugged in" is AC without charging (e.g. a charge limit).
    readonly property string plugText: UPower.onBattery ? "Unplugged"
        : device.state === UPowerDeviceState.Charging ? "Charging"
        : device.state === UPowerDeviceState.FullyCharged ? "Full"
        : "Plugged in"
    // Pushed by a power profile switch (Fn+Q, the picker below, powerprofilesctl).
    readonly property bool profileSwitch: !!(IslandState.active && IslandState.active.data.profile)
    readonly property var profiles: [
        { label: "Saver", value: PowerProfile.PowerSaver, glyph: Icons.leaf },
        { label: "Balanced", value: PowerProfile.Balanced, glyph: Icons.scales },
        { label: "Performance", value: PowerProfile.Performance, glyph: Icons.lightning },
    ]
    readonly property var current: profiles.find(p => p.value === PowerProfiles.profile) ?? profiles[1]
    readonly property string timeText: {
        const charging = device.state === UPowerDeviceState.Charging
        const secs = UPower.onBattery ? device.timeToEmpty : charging ? device.timeToFull : 0
        if (secs <= 0)
            return ""
        const h = Math.floor(secs / 3600)
        const m = Math.floor(secs % 3600 / 60)
        return h + "h " + String(m).padStart(2, "0") + "m" + (UPower.onBattery ? " left" : " to full")
    }

    // Compact
    Item {
        visible: !root.open
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.profileSwitch ? "Power profile" : root.plugText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.profileSwitch ? root.current.label : root.level
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.profileSwitch ? root.current.glyph
                    : Icons.battery(root.level, UPower.onBattery, root.critical)
                font.family: root.critical && !root.profileSwitch ? Icons.fill : Icons.regular
                font.pixelSize: 16
                color: root.critical && !root.profileSwitch ? Theme.alert : Theme.fg
            }
        }
    }

    // Expanded (the island draws the chevron in the header row's right corner)
    Column {
        visible: root.open
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Row {
            height: 24
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.level
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                color: Theme.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.plugText + (root.timeText ? " · " + root.timeText : "")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fgMuted
            }
        }

        Rectangle { // percent bar: foreground fill on a muted track
            width: parent.width
            height: 4
            radius: height / 2 // a pill (owner, 2026-10-20: rounded)
            color: Theme.border
            Rectangle {
                width: parent.width * Math.max(0, Math.min(root.level / 100, 1))
                height: 4
                radius: height / 2 // a pill (owner, 2026-10-20: rounded)
                color: Theme.fg
            }
        }

        Text {
            text: "Power profile"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.fgMuted
        }

        Row {
            width: parent.width
            spacing: 4
            Repeater {
                model: root.profiles
                Rectangle {
                    id: button
                    required property var modelData
                    readonly property bool active: PowerProfiles.profile === modelData.value
                    readonly property bool available: modelData.value !== PowerProfile.Performance
                        || PowerProfiles.hasPerformanceProfile
                    width: (parent.width - 8) / 3
                    height: 40
                    radius: 8
                    color: active ? Edge.accentTint : hover.containsMouse ? Edge.controlHover : Edge.control
                    Text {
                        anchors.centerIn: parent
                        text: button.modelData.label
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: button.active ? Theme.fg : button.available ? Theme.fgMuted : Theme.fgDim
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        enabled: button.available
                        hoverEnabled: true
                        onClicked: PowerProfiles.profile = button.modelData.value
                    }
                }
            }
        }
    }
}
