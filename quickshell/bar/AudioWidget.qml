import QtQuick
import Quickshell
import qs.services
import qs.theme

// Left: popup, right: mute, wheel: volume ±5%.
BarModule {
    id: root
    readonly property int vol: Math.round(Audio.volume * 100)
    readonly property string icon: vol < 34 ? "" : vol < 67 ? "" : ""
    readonly property string mic: Audio.micMuted ? "" : ""

    text: Audio.muted ? " " + mic : vol + "% " + icon + "  " + mic
    textColor: Audio.muted ? Theme.overlay0 : Theme.text
    active: popupOpen

    onClicked: m => {
        if (m.button === Qt.RightButton) Audio.toggleMute();
        else popupOpen = !popupOpen;
    }
    onScrolled: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))

    // Popup is created when opened and destroyed when closed.
    property bool popupOpen: false
    LazyLoader {
        active: root.popupOpen
        AudioPopup {
            anchorItem: root
            open: true
            onOpenChanged: if (!open) root.popupOpen = false
        }
    }
}
