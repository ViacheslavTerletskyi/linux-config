import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme

// Popup under a bar item that shows while the item or the popup itself is hovered.
PopupWindow {
    id: pop

    required property Item anchorItem
    property bool anchorHovered: false
    property int contentWidth: 320
    default property alias content: inner.data
    readonly property bool wanted: anchorHovered || cardHover.hovered

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 4
    visible: false
    implicitWidth: contentWidth
    implicitHeight: inner.implicitHeight + 24
    color: "transparent"

    // Short delay so the mouse can travel from the bar into the popup.
    Component.onCompleted: if (wanted) visible = true   // created while hovered (LazyLoader)
    onWantedChanged: {
        if (wanted) { closeTimer.stop(); visible = true; }
        else closeTimer.restart();
    }
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: pop.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.mantle
        radius: Theme.radius
        border.color: Theme.surface1

        HoverHandler { id: cardHover }

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
