import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.widgets

// Firewall window: created by Firewall.qml when opened, destroyed when closed.
PanelWindow {
    id: win

    required property var fw
    property bool shown: false                 // drives the open animation
    property int confirmNum: -1                // rule number waiting for a second click to delete
    property string proto: "tcp"               // "tcp" | "udp" | "any"

    readonly property int rowHeight: 40
    readonly property int maxRows: 8
    readonly property bool portValid: /^\d{1,5}(:\d{1,5})?$/.test(portInput.text.trim())

    function addRule() {
        if (!portValid || fw.busy) return;
        const port = portInput.text.trim();
        fw.allow(proto === "any" ? port : port + "/" + proto);
        portInput.text = "";
    }
    function actionColor(a) {
        if (a.startsWith("ALLOW")) return Theme.green;
        if (a.startsWith("LIMIT")) return Theme.yellow;
        return Theme.red;
    }

    Component.onCompleted: shown = true
    Connections {
        target: win.fw
        function onRulesChanged() { win.confirmNum = -1; }
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: true
    anchors.top: true
    margins.top: Math.round((screen?.height ?? 1080) * 0.2)
    exclusiveZone: 0
    implicitWidth: 580
    implicitHeight: card.implicitHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-firewall"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [win]
        active: true
        // The polkit dialog takes focus while pkexec waits: stay open then.
        onCleared: if (!win.fw.busy) win.fw.hide()
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.fw.hide()

        Rectangle {
            id: card
            width: parent.width
            implicitHeight: content.implicitHeight + 28
            radius: 16
            color: Theme.base
            border.width: 1
            border.color: Theme.surface0

            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12

                // ── Header: state + master switch ──
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: 12
                    color: Theme.mantle
                    border.width: 1
                    border.color: Theme.surface0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 14

                        Text {
                            text: ""  // shield
                            color: win.fw.enabled ? Theme.green : Theme.red
                            font.family: Theme.fontFamily
                            font.pixelSize: 24
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Firewall"
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: win.fw.enabled ? "Active · incoming traffic blocked by default" : "Disabled · all incoming traffic allowed"
                                color: win.fw.enabled ? Theme.subtext : Theme.red
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                        }
                        Toggle {
                            checked: win.fw.enabled
                            opacity: win.fw.busy ? 0.5 : 1
                            onToggled: on => win.fw.setEnabled(on)
                        }
                    }
                }

                // ── Status / error line ──
                Text {
                    Layout.fillWidth: true
                    visible: win.fw.busy || win.fw.message !== ""
                    text: win.fw.busy ? "Waiting for authentication…" : win.fw.message
                    color: win.fw.busy ? Theme.yellow : Theme.subtext
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                // ── Rules header ──
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Rules" + (win.fw.loaded ? "  ·  " + win.fw.rules.length : "")
                        color: Theme.subtext
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 8
                        color: refreshArea.containsMouse ? Theme.surface0 : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: ""  // refresh
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.fw.reload()
                        }
                    }
                }

                // ── Rules list ──
                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.max(1, Math.min(count, win.maxRows)) * (win.rowHeight + spacing) - spacing
                    visible: win.fw.loaded && count > 0
                    clip: true
                    spacing: 2
                    model: win.fw.rules
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool confirming: win.confirmNum === modelData.num
                        width: ListView.view.width
                        height: win.rowHeight
                        radius: 10
                        color: rowArea.containsMouse ? Qt.alpha(Theme.blue, 0.1) : "transparent"

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            Text {
                                Layout.preferredWidth: 190
                                text: row.modelData.to
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                Layout.preferredWidth: 82
                                implicitHeight: 22
                                radius: 6
                                color: Qt.alpha(win.actionColor(row.modelData.action), 0.15)
                                Text {
                                    anchors.centerIn: parent
                                    text: row.modelData.action
                                    color: win.actionColor(row.modelData.action)
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.from
                                color: Theme.subtext
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                implicitWidth: row.confirming ? 64 : 28
                                implicitHeight: 28
                                radius: 8
                                color: row.confirming ? Qt.alpha(Theme.red, 0.2) : (delArea.containsMouse ? Theme.surface0 : "transparent")
                                Text {
                                    anchors.centerIn: parent
                                    text: row.confirming ? "Delete?" : ""  // trash
                                    color: Theme.red
                                    font.family: row.confirming ? Theme.uiFont : Theme.fontFamily
                                    font.pixelSize: row.confirming ? 12 : 13
                                    font.weight: row.confirming ? Font.DemiBold : Font.Normal
                                }
                                MouseArea {
                                    id: delArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (row.confirming) win.fw.remove(row.modelData.num);
                                        else win.confirmNum = row.modelData.num;
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Empty / not loaded state ──
                Column {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    visible: !list.visible
                    spacing: 6
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: ""  // lock
                        color: Theme.surface1
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: !win.fw.loaded ? "Listing rules needs root — press refresh to authenticate"
                            : (win.fw.enabled ? "No rules" : "Firewall is disabled, no rules to show")
                        color: Theme.overlay0
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                    }
                }

                // ── Add rule ──
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 12
                    color: Theme.mantle
                    border.width: 1
                    border.color: portInput.activeFocus ? Qt.alpha(Theme.blue, 0.5) : Theme.surface0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 10

                        Text {
                            text: ""  // plus
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                        TextInput {
                            id: portInput
                            Layout.fillWidth: true
                            color: Theme.text
                            selectionColor: Qt.alpha(Theme.blue, 0.4)
                            font.family: Theme.uiFont
                            font.pixelSize: 14
                            clip: true
                            validator: RegularExpressionValidator { regularExpression: /[0-9:]{0,11}/ }
                            Keys.onReturnPressed: win.addRule()
                            Keys.onEnterPressed: win.addRule()

                            Text {
                                visible: portInput.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Allow port (e.g. 8080 or 3000:3010)…"
                                color: Theme.overlay0
                                font: portInput.font
                            }
                        }

                        // Protocol switch
                        Rectangle {
                            implicitWidth: protoRow.implicitWidth + 6
                            implicitHeight: 32
                            radius: 9
                            color: Theme.surface0
                            Row {
                                id: protoRow
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: ["tcp", "udp", "any"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        readonly property bool current: win.proto === modelData
                                        implicitWidth: protoLabel.implicitWidth + 16
                                        implicitHeight: 26
                                        radius: 7
                                        color: current ? Theme.base : "transparent"
                                        Text {
                                            id: protoLabel
                                            anchors.centerIn: parent
                                            text: parent.modelData
                                            color: parent.current ? Theme.text : Theme.overlay0
                                            font.family: Theme.uiFont
                                            font.pixelSize: 12
                                            font.weight: parent.current ? Font.DemiBold : Font.Normal
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.proto = parent.modelData
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: allowLabel.implicitWidth + 24
                            implicitHeight: 32
                            radius: 9
                            color: win.portValid && !win.fw.busy ? Theme.blue : Theme.surface0
                            Text {
                                id: allowLabel
                                anchors.centerIn: parent
                                text: "Allow"
                                color: win.portValid && !win.fw.busy ? Theme.crust : Theme.overlay0
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: win.portValid ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: win.addRule()
                            }
                        }
                    }
                }

                // ── Key hints ──
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16
                    Repeater {
                        model: [["Enter", "add port"], ["Esc", "close"]]
                        delegate: Row {
                            required property var modelData
                            spacing: 6
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: keyText.implicitWidth + 12
                                implicitHeight: 20
                                radius: 5
                                color: Theme.surface0
                                border.width: 1
                                border.color: Theme.surface1
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: parent.parent.modelData[0]
                                    color: Theme.subtext
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[1]
                                color: Theme.overlay0
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
