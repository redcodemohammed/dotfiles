pragma Singleton
import QtQuick
import Quickshell

// One panel at a time (owner, 2026-10-17): every panel that opens calls claim() with itself;
// any other open one sees `current` change and closes (bar panels slide away through Reveal,
// the shortcuts overlay just closes). Covers every bar panel and the inbox (all on Reveal.qml)
// and the shortcuts overlay. The island is not a panel.
Singleton {
    property var current: null
    function claim(panel) { current = panel }
}
