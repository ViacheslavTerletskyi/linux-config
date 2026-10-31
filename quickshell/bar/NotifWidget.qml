import QtQuick
import qs.services
import qs.theme

// Left: notification center, right: do-not-disturb.
BarModule {
    text: (Notifs.dnd ? "\uf1f6" : "\uf0f3")
    textColor: Notifs.dnd ? Theme.mauve : Theme.text
    onClicked: m => {
        if (m.button === Qt.RightButton) Notifs.dnd = !Notifs.dnd;
        else Notifs.centerOpen = !Notifs.centerOpen;
    }
}
