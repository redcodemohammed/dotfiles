import QtQuick
import Quickshell

// Calendar and clock (owner, 2026-10-21; the "Calendar and clock panel" design, option A): comes
// out of the frame under the bar's clock chip, centred on it, 380 wide. The time as a poster (the
// colon in the clock's hue, the seconds smaller and muted), the date in words, the ISO week and
// the day of the year; then the month: its name, Today (while another month shows), < and >, the
// weekday initials and six weeks of days, today filled in the hue. Weeks start on the locale's
// first day. The arrows, the wheel over the month and PgUp / PgDn move a month, Home goes back to
// today, Escape closes. It opens on today's month every time.
PopupWindow {
    id: panel
    required property var bar
    required property var block

    anchor.window: bar
    anchor.item: block
    anchor.rect.x: (block.width - implicitWidth) / 2 // the body centred under the chip
    anchor.rect.y: block.height + 6
    implicitWidth: reveal.implicitWidth
    implicitHeight: reveal.implicitHeight
    mask: Region { item: reveal.area }
    color: "transparent"
    grabFocus: false // an outside click goes through EdgePanel's focus grab, so closing can slide
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            reveal.close()
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the chip
            visible = true
    }
    // The guard counts from when the closing starts, not from when the shrink ends: counted from the
    // end, a click right after the shrink was swallowed and opening took a second click.
    Connections {
        target: reveal
        function onClosingChanged() { if (reveal.closing) panel.closedAt = Date.now() }
    }
    onVisibleChanged: {
        if (!visible) {
            if (!Settings.look.animations) // no shrink: it closed just now
                closedAt = Date.now()
        } else {
            offset = 0
        }
    }

    readonly property color hue: Theme.hue6 // the clock chip's
    property int offset: 0 // the month shown, in months from today's

    SystemClock {
        id: clock
        precision: panel.visible ? SystemClock.Seconds : SystemClock.Minutes
    }
    readonly property date now: clock.date
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + offset, 1)

    function isoWeek(d) { // the Thursday of d's week decides the year; its week counts from 1
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7)
    }
    readonly property int dayOfYear: Math.round((Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
        - Date.UTC(now.getFullYear(), 0, 1)) / 86400000) + 1
    readonly property int yearDays: new Date(now.getFullYear(), 1, 29).getDate() === 29 ? 366 : 365

    readonly property int firstDay: Qt.locale().firstDayOfWeek // 0 Sunday … 6 Saturday, as Date.getDay()
    readonly property var names: {
        const out = []
        for (let i = 0; i < 7; i++)
            out.push(Qt.locale().dayName((firstDay + i) % 7, Locale.ShortFormat).slice(0, 2))
        return out
    }
    // Six weeks from the one holding the 1st, so the grid's height never changes.
    readonly property var days: {
        const y = shown.getFullYear(), m = shown.getMonth()
        const lead = (shown.getDay() - firstDay + 7) % 7
        const today = now.toDateString()
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(y, m, 1 - lead + i)
            out.push({ n: d.getDate(), inMonth: d.getMonth() === m, today: d.toDateString() === today })
        }
        return out
    }

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        property string label
        signal clicked
        width: 28
        height: 28
        radius: 8
        color: arrowArea.containsMouse ? Edge.controlHover : Edge.control
        Accessible.role: Accessible.Button
        Accessible.name: label
        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: Icons.regular
            font.pixelSize: 14
            color: Theme.fgMuted
        }
        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: arrow.clicked()
        }
    }

    EdgePanel { // comes out of the frame under its chip, curving into the band on both sides
        id: reveal
        window: panel
        bodyWidth: 380
        bodyHeight: column.implicitHeight + 28

        focus: true
        Keys.onEscapePressed: reveal.close()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_PageUp) panel.offset--
            else if (event.key === Qt.Key_PageDown) panel.offset++
            else if (event.key === Qt.Key_Home) panel.offset = 0
            else return
            event.accepted = true
        }

        Column {
            id: column
            x: 16
            y: 12
            width: parent.width - 32
            spacing: 16

            Column { // the clock as a poster
                width: parent.width
                spacing: 4
                Row {
                    height: 48
                    Repeater { // hours, the colon in the hue, minutes; then the seconds, small
                        model: [
                            { t: Qt.formatTime(panel.now, Settings.bar.clock24 ? "HH" : "h"), big: true, ink: Theme.fg },
                            { t: ":", big: true, ink: panel.hue },
                            { t: Qt.formatTime(panel.now, "mm"), big: true, ink: Theme.fg },
                            { t: Qt.formatTime(panel.now, ":ss") + (Settings.bar.clock24 ? "" : Qt.formatTime(panel.now, " AP")),
                              big: false, ink: Theme.fgMuted }
                        ]
                        Text {
                            required property var modelData
                            anchors.baseline: parent.top
                            anchors.baselineOffset: 40
                            leftPadding: modelData.big ? 0 : 2
                            text: modelData.t
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: modelData.big ? 44 : 18
                            font.weight: modelData.big ? Font.Medium : Font.Normal
                            color: modelData.ink
                        }
                    }
                }
                Text {
                    text: Qt.formatDate(panel.now, "dddd d MMMM yyyy")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fg
                }
                Text {
                    text: "Week " + panel.isoWeek(panel.now) + " · day " + panel.dayOfYear + " of " + panel.yearDays
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }

            Column { // the month
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    height: 28
                    spacing: 4
                    Text {
                        width: parent.width - (today.visible ? today.width + 4 : 0) - 2 * (28 + 4)
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.locale().standaloneMonthName(panel.shown.getMonth()) + " " + panel.shown.getFullYear()
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.fg
                    }
                    Rectangle { // back to today's month
                        id: today
                        visible: panel.offset !== 0
                        width: todayLabel.implicitWidth + 20
                        height: 28
                        radius: 8
                        color: Qt.tint(Edge.fill, Qt.rgba(panel.hue.r, panel.hue.g, panel.hue.b, todayArea.containsMouse ? 0.22 : 0.15))
                        Text {
                            id: todayLabel
                            anchors.centerIn: parent
                            text: "Today"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: panel.hue
                        }
                        MouseArea {
                            id: todayArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: panel.offset = 0
                        }
                    }
                    Arrow { glyph: Icons.caretLeft; label: "Previous month"; onClicked: panel.offset-- }
                    Arrow { glyph: Icons.caretRight; label: "Next month"; onClicked: panel.offset++ }
                }

                Column {
                    id: month
                    width: parent.width
                    spacing: 4
                    readonly property real cell: (width - 6 * 2) / 7

                    Row { // the weekday initials
                        spacing: 2
                        Repeater {
                            model: panel.names
                            Text {
                                required property string modelData
                                width: month.cell
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: Theme.fgMuted
                            }
                        }
                    }
                    Item {
                        width: parent.width
                        height: grid.height
                        Grid {
                            id: grid
                            columns: 7
                            spacing: 2
                            Repeater {
                                model: panel.days
                                Rectangle {
                                    required property var modelData
                                    width: month.cell
                                    height: 40
                                    radius: 8
                                    color: modelData.today ? panel.hue : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData.n
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        font.weight: parent.modelData.today ? Font.DemiBold : Font.Normal
                                        color: parent.modelData.today ? Theme.textOnAccent : Theme.fg
                                        opacity: parent.modelData.inMonth || parent.modelData.today ? 1 : 0.4
                                    }
                                }
                            }
                        }
                        MouseArea { // the wheel over the month moves a month, a notch (or a touchpad's 120) at a time
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            property real pending: 0
                            onWheel: wheel => {
                                pending += wheel.angleDelta.y
                                while (Math.abs(pending) >= 120) {
                                    panel.offset += pending > 0 ? -1 : 1
                                    pending -= pending > 0 ? 120 : -120
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
