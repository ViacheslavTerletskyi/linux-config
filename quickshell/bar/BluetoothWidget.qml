import QtQuick
import Quickshell
import qs.services
import qs.theme

// Off / on / connected (+ device name, or count if several).
BarModule {
    id: root
    visible: Bt.available
    readonly property int n: Bt.connected.length
    text: !Bt.enabled ? "\udb80\udcb2"
        : n === 0 ? "\udb80\udcaf"
        : (n === 1 ? Bt.connected[0].name : n + " devices") + " \udb80\udcb1"
    textColor: !Bt.enabled ? Theme.overlay0 : n > 0 ? Theme.blue : Theme.text
    onClicked: popupOpen = !popupOpen

    // Popup is created when opened and destroyed when closed.
    property bool popupOpen: false
    LazyLoader {
        active: root.popupOpen
        BluetoothPopup {
            anchorItem: root
            open: true
            onOpenChanged: if (!open) root.popupOpen = false
        }
    }
}
