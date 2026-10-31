import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.theme

// Popup under a bar item. Closes on click outside (clicks on the bar itself are allowed
// so the bar button can toggle it).
PopupWindow {
    id: pop

    required property Item anchorItem
    property bool open: false
    property int contentWidth: 320
    default property alias content: inner.data

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 4
    visible: open
    implicitWidth: contentWidth
    implicitHeight: inner.implicitHeight + 24
    color: "transparent"

    // The grab is armed a moment after the popup is shown: armed together with it,
    // the popup surface doesn't exist yet and clicks inside it would close it.
    HyprlandFocusGrab {
        id: grab
        windows: [pop, pop.anchorItem.QsWindow.window]
        onCleared: pop.open = false
    }
    Timer {
        id: armGrab
        interval: 50
        onTriggered: grab.active = pop.visible
    }
    Component.onCompleted: if (visible) armGrab.restart()   // created already open (LazyLoader)
    onVisibleChanged: {
        if (visible) armGrab.restart();
        else grab.active = false;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.mantle
        radius: Theme.radius
        border.color: Theme.surface1

        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6
        }
    }
}
