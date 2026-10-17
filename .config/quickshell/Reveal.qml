import QtQuick
import Quickshell.Hyprland

// Opens and closes a bar panel the way Hyprland opens a window (owner, 2026-10-17; a 12px drop
// first, not liked). Open: `target` (the panel's body) slides in from the edge it hangs from, its
// full height, from behind the bar (the popup clips it), on Hyprland's "spring" bezier
// (0.34, 1.3, 0.64, 1: past the end, then back) over 300 ms, fading in over the first 150 ms.
// Close: the exact reverse (the curve turned around: 0.36, 0, 0.66, -0.3; the fade over the last
// 150 ms), then the window hides. Off with Settings > Look > Animations.
// Closing has to go through close(), not `visible = false`: an outside click is a
// HyprlandFocusGrab (the panel sets grabFocus: false), which only reports the click, so the
// window can stay up for the slide back; an xdg-popup grab would hide it at once.
// Hyprland animates layer surfaces (the inbox, the shortcuts overlay) itself, not these popups.
// Inside the panel: `Reveal { id: reveal; window: panel; target: body }`, then reveal.close().
Item {
    id: reveal
    required property Item target
    required property var window // the PopupWindow
    readonly property bool closing: hide.running

    function close() {
        if (!window.visible || hide.running)
            return
        show.stop()
        if (Settings.look.animations)
            hide.restart()
        else
            window.visible = false
    }

    Connections {
        target: Panels
        function onCurrentChanged() {
            if (Panels.current !== reveal && reveal.window.visible)
                reveal.close()
        }
    }

    HyprlandFocusGrab {
        windows: [reveal.window]
        active: reveal.window.visible
        onCleared: reveal.close()
    }

    Connections {
        target: reveal.window
        function onVisibleChanged() {
            if (!reveal.window.visible) {
                hide.stop()
                return
            }
            Panels.claim(reveal) // any other open panel closes
            if (Settings.look.animations) {
                show.restart()
            } else {
                reveal.target.opacity = 1
                reveal.target.y = 0
            }
        }
    }

    ParallelAnimation {
        id: show
        NumberAnimation {
            target: reveal.target
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: reveal.target
            property: "y"
            from: -reveal.target.height
            to: 0
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.3, 0.64, 1, 1, 1] // hyprland.lua "spring"
        }
    }

    SequentialAnimation {
        id: hide
        ParallelAnimation {
            NumberAnimation {
                target: reveal.target
                property: "y"
                to: -reveal.target.height
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.36, 0, 0.66, -0.3, 1, 1] // "spring" played backwards
            }
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation {
                    target: reveal.target
                    property: "opacity"
                    to: 0
                    duration: 150
                    easing.type: Easing.InCubic
                }
            }
        }
        ScriptAction { script: reveal.window.visible = false }
    }
}
