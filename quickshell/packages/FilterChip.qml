import QtQuick
import qs.theme

// Pill-shaped filter button with an optional colour dot and counter.
Rectangle {
    id: chip

    property string label
    property int count: -1          // -1 hides the counter
    property color accent: Theme.blue
    property bool dot: true
    property bool active: false
    signal clicked()

    implicitWidth: content.implicitWidth + 26
    implicitHeight: 32
    radius: height / 2
    color: active ? Qt.alpha(accent, 0.18) : (area.containsMouse ? Theme.surface0 : Theme.mantle)
    border.width: 1
    border.color: active ? Qt.alpha(accent, 0.6) : Theme.surface0
    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            visible: chip.dot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: chip.accent
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: chip.active ? Theme.text : Theme.subtext
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.weight: chip.active ? Font.DemiBold : Font.Medium
        }
        Text {
            visible: chip.count >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.count
            color: chip.active ? chip.accent : Theme.overlay0
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
