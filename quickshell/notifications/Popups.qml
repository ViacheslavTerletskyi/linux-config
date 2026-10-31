import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.theme

// Toasts in the top-right corner of the focused monitor.
PanelWindow {
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.popups.length > 0 && !Notifs.centerOpen

    anchors {
        top: true
        right: true
    }
    margins {
        top: 8
        right: 8
    }
    exclusiveZone: 0
    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifs.popups.slice(0, 5)
            delegate: NotificationCard {
                required property var modelData
                notif: modelData
                popup: true
                width: column.width
                onExpired: Notifs.removePopup(modelData)
            }
        }
    }
}
