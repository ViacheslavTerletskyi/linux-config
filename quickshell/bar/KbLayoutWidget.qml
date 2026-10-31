import QtQuick
import Quickshell
import qs.services

BarModule {
    text: KbLayout.short
    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
}
