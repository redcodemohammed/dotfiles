pragma Singleton
import QtQuick
import Quickshell

// App glyphs for the bar's workspaces (owner, 2026-10-17): single-colour brand glyphs from
// JetBrains Mono Nerd Font, matched by the window's app ID (lowercase, first rule that the ID
// contains). Codepoints checked in JetBrainsMonoNerdFont-Regular.ttf by glyph name. Unknown apps:
// a plain window. Add an app: one line, ["part of its class", "\uXXXX"] (`hyprctl clients`).
Singleton {
    readonly property var rules: [
        ["alacritty", ""], ["kitty", ""], ["foot", ""], ["terminal", ""], // dev-terminal
        ["zen", ""], ["firefox", ""],                     // fa-firefox (Zen is a Firefox)
        ["chrom", ""], ["brave", ""],                     // dev-chrome
        ["telegram", ""],                                       // fa-telegram
        ["discord", ""], ["vesktop", ""],                 // fa-discord
        ["whatsapp", ""],                                       // fa-whatsapp
        ["slack", ""],                                          // fa-slack
        ["spotify", ""], ["spotifast", ""],               // fa-spotify
        ["code", ""], ["vscodium", ""],                   // dev-vscode (also T3 Code)
        ["datagrip", ""], ["pycharm", ""], ["webstorm", ""],
        ["idea", ""], ["jetbrains", ""],                  // dev-*
        ["nvim", ""], ["neovim", ""],                     // custom-neovim
        ["strata", ""], ["nautilus", ""], ["thunar", ""], // custom-folder
        ["steam", ""], ["pcsx2", ""], ["lutris", ""], // fa-steam, fa-gamepad
        ["obs", ""],                                            // fa-video_camera
        ["clapper", ""], ["mpv", ""], ["vlc", ""],  // fa-film
        ["loupe", ""], ["satty", ""], ["gimp", ""], // fa-picture_o, linux-gimp
        ["chorus", ""],                                         // fa-music
        ["thunderbird", ""],                                    // linux-thunderbird
        ["docker", ""],
        ["claude", ""],                                         // fa-comments
    ]
    readonly property string fallback: "" // fa-window_maximize

    function forApp(id) {
        const s = (id || "").toLowerCase()
        for (const [part, glyph] of rules)
            if (s.includes(part))
                return glyph
        return fallback
    }
}
