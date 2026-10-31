import QtQuick
import qs.theme

// Clickable text block in the bar with a hover highlight.
Item {
    id: root

    property alias text: label.text
    property alias textFormat: label.textFormat
    property color textColor: Theme.text
    property color activeColor: Theme.blue
    property bool active: false
    property bool interactive: true   // false: no hover highlight, no clicks
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: label.implicitWidth + Theme.padding * 2
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: Theme.radius
        color: root.active ? root.activeColor : (mouse.containsMouse && root.interactive ? Theme.surface0 : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    BarLabel {
        id: label
        anchors.centerIn: parent
        color: root.active ? Theme.crust : root.textColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w)
    }
}
