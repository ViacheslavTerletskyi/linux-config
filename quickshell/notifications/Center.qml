import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.theme

// Side panel with notification history. Esc or click outside closes it.
PanelWindow {
    id: center

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.centerOpen

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: 8
        right: 8
        bottom: 8
    }
    exclusiveZone: 0
    implicitWidth: 400
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [center]
        active: center.visible
        onCleared: Notifs.centerOpen = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        radius: Theme.radius
        border.color: Theme.surface1
        focus: true
        Keys.onEscapePressed: Notifs.centerOpen = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.bold: true
                }
                HeaderButton {
                    text: Notifs.dnd ? " DND" : " DND"
                    highlighted: Notifs.dnd
                    onClicked: Notifs.dnd = !Notifs.dnd
                }
                HeaderButton {
                    text: " Clear"
                    onClicked: Notifs.clearAll()
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: Notifs.history.slice().reverse()
                delegate: NotificationCard {
                    required property var modelData
                    notif: modelData
                    width: ListView.view.width
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: "No notifications"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }

    component HeaderButton: Rectangle {
        id: btn
        property alias text: label.text
        property bool highlighted: false
        signal clicked
        implicitWidth: label.implicitWidth + 16
        implicitHeight: label.implicitHeight + 8
        radius: Theme.radius
        color: highlighted ? Theme.mauve : (area.containsMouse ? Theme.surface1 : Theme.surface0)
        Text {
            id: label
            anchors.centerIn: parent
            color: btn.highlighted ? Theme.crust : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }
}
