//@ pragma IconTheme Papirus-Dark
import Quickshell

ShellRoot {
    // One bar per connected screen, created and destroyed as screens change.
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        Popups {}
    }

    Variants {
        model: Quickshell.screens
        Inbox {}
    }

    Variants {
        model: Quickshell.screens
        Osd {}
    }
}
