import QtQuick
import Quickshell
import qs.services
import qs.theme

// Click: power mode popup. Hidden on machines without a laptop battery.
BarModule {
    id: root
    readonly property var icons: ["", "", "", "", ""]
    readonly property string icon: Battery.charging ? ""
        : Battery.plugged ? ""
        : icons[Math.min(4, Math.floor(Battery.percent / 20))]

    visible: Battery.present
    text: Battery.percent + "% " + icon
    textColor: Battery.charging ? Theme.green
        : Battery.percent <= 15 ? Theme.red
        : Battery.percent <= 30 ? Theme.yellow : Theme.text

    active: popupOpen
    onClicked: popupOpen = !popupOpen

    // Popup is created when opened and destroyed when closed.
    property bool popupOpen: false
    LazyLoader {
        active: root.popupOpen
        BatteryPopup {
            anchorItem: root
            open: true
            onOpenChanged: if (!open) root.popupOpen = false
        }
    }
}
