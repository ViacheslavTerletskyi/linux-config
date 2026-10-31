import QtQuick
import qs.services
import qs.theme

// Display only. Hidden on machines without a laptop battery.
BarModule {
    readonly property var icons: ["", "", "", "", ""]
    readonly property string icon: Battery.charging ? ""
        : Battery.plugged ? ""
        : icons[Math.min(4, Math.floor(Battery.percent / 20))]

    visible: Battery.present
    interactive: false
    text: Battery.percent + "% " + icon
    textColor: Battery.charging ? Theme.green
        : Battery.percent <= 15 ? Theme.red
        : Battery.percent <= 30 ? Theme.yellow : Theme.text
}
