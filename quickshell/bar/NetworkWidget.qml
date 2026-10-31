import QtQuick
import Quickshell
import qs.services
import qs.theme

BarModule {
    id: root
    text: {
        if (Net.wired) return "Ethernet 󰈀";
        if (Net.connected) return Net.ssid + " (" + Net.signal + "%) " + Net.signalIcon(Net.signal);
        return "Disconnected ⚠";
    }
    textColor: Net.connected ? Theme.text : Theme.red
    onClicked: popupOpen = !popupOpen

    // Popup is created when opened and destroyed when closed.
    property bool popupOpen: false
    LazyLoader {
        active: root.popupOpen
        NetworkPopup {
            anchorItem: root
            open: true
            onOpenChanged: if (!open) root.popupOpen = false
        }
    }
}
