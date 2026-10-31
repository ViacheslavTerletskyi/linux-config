import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import qs.theme

// Polkit authentication agent (pkexec, systemctl, mounting, etc).
Scope {
    PolkitAgent {
        id: agent
    }

    // Dialog window exists only while an authentication request is active.
    LazyLoader {
        active: agent.isActive && agent.flow !== null

        PanelWindow {
            id: win
            Component.onCompleted: password.forceActiveFocus()

            readonly property AuthFlow flow: agent.flow

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            visible: agent.isActive && flow !== null
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "#99000000"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-polkit"
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: if (visible) { password.text = ""; password.forceActiveFocus(); }

            function submit() {
                if (flow && flow.isResponseRequired) {
                    flow.submit(password.text);
                    password.text = "";
                }
            }
            function cancel() {
                if (flow) flow.cancelAuthenticationRequest();
            }

            Rectangle {
                anchors.centerIn: parent
                width: 440
                height: content.implicitHeight + 40
                radius: Theme.radius
                color: Theme.base
                border.color: Theme.surface1

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    RowLayout {
                        spacing: 12
                        Text {
                            text: ""
                            color: Theme.mauve
                            font.family: Theme.fontFamily
                            font.pixelSize: 28
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Authentication required"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 4
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: win.flow?.message ?? ""
                        color: Theme.text
                        wrapMode: Text.Wrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        Layout.fillWidth: true
                        text: win.flow?.actionId ?? ""
                        color: Theme.overlay0
                        elide: Text.ElideMiddle
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Theme.radius
                        color: Theme.surface0
                        border.color: password.activeFocus ? Theme.blue : "transparent"

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: win.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                            enabled: win.flow?.isResponseRequired ?? false
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            onAccepted: win.submit()
                            Keys.onEscapePressed: win.cancel()

                            Text {
                                visible: password.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: (win.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                                color: Theme.overlay0
                                font: password.font
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: win.flow?.supplementaryMessage ?? ""
                        color: win.flow?.supplementaryIsError ? Theme.red : Theme.subtext
                        wrapMode: Text.Wrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8
                        DialogButton {
                            text: "Cancel"
                            onClicked: win.cancel()
                        }
                        DialogButton {
                            text: "Authenticate"
                            primary: true
                            onClicked: win.submit()
                        }
                    }
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: btn
        property alias text: label.text
        property bool primary: false
        signal clicked
        implicitWidth: label.implicitWidth + 24
        implicitHeight: 32
        radius: Theme.radius
        color: primary ? (area.containsMouse ? Qt.lighter(Theme.blue, 1.1) : Theme.blue)
            : (area.containsMouse ? Theme.surface1 : Theme.surface0)
        Text {
            id: label
            anchors.centerIn: parent
            color: btn.primary ? Theme.crust : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }
}
