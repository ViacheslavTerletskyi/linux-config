import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.base
    WlrLayershell.namespace: "quickshell-bar"

    // Left: workspaces · system load
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing * 2

        Workspaces { screenName: bar.modelData.name }
        StatsWidget {}
    }

    // Center: date/time · notifications
    Row {
        anchors.centerIn: parent
        spacing: Theme.spacing

        Clock {}
        NotifWidget {}
    }

    // Right: network · bluetooth · sound · battery · language
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        NetworkWidget {}
        BluetoothWidget {}
        AudioWidget {}
        BatteryWidget {}
        KbLayoutWidget {}
    }
}
