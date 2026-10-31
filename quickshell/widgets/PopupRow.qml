import QtQuick
import QtQuick.Layouts
import qs.theme

// List row: icon · text · trailing hint.
Rectangle {
    id: r
    property string icon: ""
    property string text: ""
    property string trailing: ""
    property bool highlighted: false
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 34
    radius: Theme.radius
    color: area.containsMouse ? Theme.surface0 : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10
        Text {
            Layout.preferredWidth: 18
            text: r.icon
            color: r.highlighted ? Theme.blue : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: r.text
            color: r.highlighted ? Theme.blue : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: r.highlighted
            elide: Text.ElideRight
        }
        Text {
            visible: text !== ""
            text: r.trailing
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: r.clicked()
    }
}
