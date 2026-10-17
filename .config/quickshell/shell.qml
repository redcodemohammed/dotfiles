//@ pragma IconTheme Papirus-Dark
//@ pragma UseQApplication
// UseQApplication: tray right-click menus are Qt platform menus and need it (restart qs after changing pragmas).
import Quickshell

ShellRoot {
    // One bar per connected screen, created and destroyed as screens change.
    Variants {
        model: Quickshell.screens
        Bar {}
    }


    Variants {
        model: Quickshell.screens
        Island {}
    }

    // The entrance at login and after unlocking: the wallpaper fades up (Entrance.qml).
    Variants {
        model: Quickshell.screens
        EntranceCover {}
    }

    // A video wallpaper pauses on battery and while locked (VideoWallpaper.qml); touching the
    // singleton here starts it with the shell.
    property bool videoWallpaperHold: VideoWallpaper.hold

    // SUPER + F1: every Hyprland shortcut, on the focused screen (one window that follows focus).
    Shortcuts {}
}
