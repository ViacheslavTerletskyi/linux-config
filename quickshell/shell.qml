//@ pragma UseQApplication
//@ pragma IconTheme breeze-dark
import QtQuick
import Quickshell
import qs.bar
import qs.firewall
import qs.notifications
import qs.packages
import qs.launcher
import qs.polkit
import qs.screenshot
import qs.services

ShellRoot {
    // One bar per monitor; appears/disappears with hotplug.
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // Windows below are created on demand and destroyed when hidden (saves memory).
    LazyLoader {
        active: Notifs.popups.length > 0 && !Notifs.centerOpen
        Popups {}
    }
    LazyLoader {
        active: Notifs.centerOpen
        Center {}
    }
    Launcher {}
    Firewall {}
    Packages {}
    PolkitDialog {}
    ScreenshotTool {}
}
