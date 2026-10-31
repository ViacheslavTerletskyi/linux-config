import QtQuick
import qs.theme

// Horizontal 0..1 slider: click / drag / wheel.
Item {
    id: s
    property real value: 0
    property bool dimmed: false
    signal moved(real value)

    implicitHeight: 20
    implicitWidth: 160

    function setFromX(x) { s.moved(Math.max(0, Math.min(1, x / width))); }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface0
        Rectangle {
            width: parent.width * Math.min(1, s.value)
            height: parent.height
            radius: 3
            color: s.dimmed ? Theme.overlay0 : Theme.blue
        }
    }
    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width - width) * Math.min(1, s.value)
        color: s.dimmed ? Theme.overlay0 : Theme.text
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => s.setFromX(m.x)
        onPositionChanged: m => { if (pressed) s.setFromX(m.x); }
        onWheel: w => s.moved(Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
