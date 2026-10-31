import QtQuick
import QtQuick.Layouts
import qs.theme

// Title + optional on/off switch.
RowLayout {
    id: h
    property string title: ""
    property bool showToggle: true
    property bool checked: false
    signal toggled(bool checked)

    Layout.fillWidth: true
    Text {
        Layout.fillWidth: true
        text: h.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
        font.bold: true
    }
    Toggle {
        visible: h.showToggle
        checked: h.checked
        onToggled: c => h.toggled(c)
    }
}
