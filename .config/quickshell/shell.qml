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
        Inbox {}
    }

    Variants {
        model: Quickshell.screens
        Island {}
    }

    // SUPER + F1: every Hyprland shortcut, on the focused screen (one window that follows focus).
    Shortcuts {}
}
