import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.services
import qs.theme
import qs.widgets

DropdownPopup {
    id: pop

    property string askPsk: ""   // SSID waiting for a password
    property string error: ""

    readonly property var networks: (Net.wifiDevice?.networks.values ?? [])
        .filter(n => n.name !== "")
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    function pct(n) {
        const s = n.signalStrength;
        return Math.round(s <= 1 ? s * 100 : s);
    }
    function onRowClicked(n) {
        error = "";
        if (n.connected) n.disconnect();
        else if (n.known || n.security === WifiSecurityType.Open) n.connect();
        else askPsk = askPsk === n.name ? "" : n.name;
    }

    Component.onCompleted: if (Net.wifiDevice) Net.wifiDevice.scannerEnabled = true
    Component.onDestruction: if (Net.wifiDevice) Net.wifiDevice.scannerEnabled = false
    onOpenChanged: {
        if (Net.wifiDevice) Net.wifiDevice.scannerEnabled = open;
        if (!open) { askPsk = ""; error = ""; }
    }

    SectionHeader {
        title: "Wi-Fi"
        checked: Networking.wifiEnabled
        onToggled: c => Networking.wifiEnabled = c
    }

    Text {
        Layout.fillWidth: true
        visible: pop.error !== ""
        text: pop.error
        color: Theme.red
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: Networking.wifiEnabled ? pop.networks.slice(0, 12) : []

        delegate: ColumnLayout {
            id: item
            required property var modelData
            Layout.fillWidth: true
            spacing: 4

            Connections {
                target: item.modelData
                function onConnectionFailed(reason) {
                    pop.error = "Failed to connect to " + item.modelData.name + ": " + ConnectionFailReason.toString(reason);
                    if (reason === ConnectionFailReason.NoSecrets) pop.askPsk = item.modelData.name;
                }
            }

            PopupRow {
                icon: Net.signalIcon(pop.pct(item.modelData))
                text: item.modelData.name
                highlighted: item.modelData.connected
                trailing: item.modelData.stateChanging ? "…"
                    : item.modelData.connected ? ""
                    : item.modelData.security !== WifiSecurityType.Open ? "" : ""
                onClicked: pop.onRowClicked(item.modelData)
            }

            Rectangle {
                visible: pop.askPsk === item.modelData.name
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Theme.radius
                color: Theme.surface0

                TextInput {
                    id: psk
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    focus: parent.visible
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onAccepted: {
                        item.modelData.connectWithPsk(text);
                        pop.askPsk = "";
                    }
                    Keys.onEscapePressed: pop.askPsk = ""

                    Text {
                        visible: psk.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password, Enter to connect"
                        color: Theme.overlay0
                        font: psk.font
                    }
                }
            }
        }
    }

    PopupRow {
        icon: ""
        text: "Network settings"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            pop.open = false;
        }
    }
}
