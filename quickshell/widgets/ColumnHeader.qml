import QtQuick
import QtQuick.Layouts
import qs.theme

// Clickable column header; the active one is highlighted with an arrow.
Text {
    id: h
    property string label: ""
    property bool current: false
    signal picked

    Layout.preferredWidth: 50
    text: (current ? "▾ " : "") + label
    color: current ? Theme.blue : (area.containsMouse ? Theme.text : Theme.overlay0)
    font.bold: current
    horizontalAlignment: Text.AlignRight
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize - 2

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: h.picked()
    }
}
