import QtQuick
import QtQuick.Layouts
import qs.theme

// "Label ......... value" with an optional usage bar below.
ColumnLayout {
    id: r
    property string icon: ""
    property string label: ""
    property string value: ""
    property real percent: -1   // 0..100, -1 hides the bar

    readonly property color levelColor: percent >= 85 ? Theme.red : percent >= 60 ? Theme.yellow : Theme.blue

    Layout.fillWidth: true
    spacing: 3

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.preferredWidth: 18
            text: r.icon
            color: r.levelColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: r.label
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
        Text {
            text: r.value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }
    Rectangle {
        visible: r.percent >= 0
        Layout.fillWidth: true
        Layout.leftMargin: 26
        implicitHeight: 4
        radius: 2
        color: Theme.surface0
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, r.percent)) / 100
            height: parent.height
            radius: 2
            color: r.levelColor
            Behavior on width { NumberAnimation { duration: 300 } }
        }
    }
}
