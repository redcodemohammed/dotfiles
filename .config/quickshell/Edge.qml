pragma Singleton
import QtQuick
import Quickshell

// The frame's colours, shared by everything drawn as part of the frame (Frame.qml, Island.qml):
// the bar colour with 8% of the accent mixed in, so it follows the wallpaper (owner, 2026-10-20:
// Theme.bg and Theme.surface were too alike on a dark palette to see; 15% went muddy on the
// island's large card). An alert (recording, a failed build, an urgent notification, a
// critical battery) mixes in the alert colour instead.
Singleton {
    readonly property color fill: Qt.tint(Theme.bg, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08))
    readonly property color alertFill: Qt.tint(Theme.bg, Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.35))
}
