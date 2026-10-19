import QtQuick
import Quickshell.Wayland

// Title of the focused window, shown only on the bar of the screen it is on.
// Text only, no app icon. Capped near 40 characters, elided.
// Uses the Wayland toplevel list: Hyprland.activeToplevel stays null until
// the first focus change after the shell starts.
Text {
    id: root
    required property var screen
    readonly property var window: ToplevelManager.activeToplevel
    property real maxWidth: Infinity // the room the bar leaves it (left of the centred workspaces)

    text: window && window.screens.includes(screen) ? window.title : ""
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 13
    color: Theme.fg
    elide: Text.ElideRight
    width: Math.min(implicitWidth, metrics.averageCharacterWidth * 40, maxWidth)

    FontMetrics {
        id: metrics
        font: root.font
    }
}
