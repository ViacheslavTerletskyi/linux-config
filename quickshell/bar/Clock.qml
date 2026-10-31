import QtQuick
import Quickshell
import qs.theme

// "Sun, 18 - 20:21". Click opens the calendar.
BarModule {
    id: root

    text: Theme.capitalize(clock.date.toLocaleDateString(Theme.locale, "ddd")) + ", "
        + clock.date.getDate() + " - " + Qt.formatTime(clock.date, "HH:mm")
    active: popupOpen
    onClicked: popupOpen = !popupOpen

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Popup is created when opened and destroyed when closed.
    property bool popupOpen: false
    LazyLoader {
        active: root.popupOpen
        CalendarPopup {
            anchorItem: root
            open: true
            onOpenChanged: if (!open) root.popupOpen = false
        }
    }
}
