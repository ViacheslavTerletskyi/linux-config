import QtQuick
import qs.theme

Rectangle {
    id: t
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 36
    implicitHeight: 20
    radius: height / 2
    color: checked ? Theme.blue : Theme.surface1
    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        y: 3
        x: t.checked ? t.width - width - 3 : 3
        color: Theme.crust
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: t.toggled(!t.checked)
    }
}
