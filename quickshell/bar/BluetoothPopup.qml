import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.services
import qs.theme
import qs.widgets

DropdownPopup {
    id: pop

    readonly property var devices: Bt.devices.slice()
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    function deviceIcon(d) {
        const i = d.icon;
        if (i.includes("headset") || i.includes("headphone") || i.includes("audio")) return "󰋋";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("phone")) return "󰞲";
        if (i.includes("gaming")) return "󰊖";
        return "";
    }
    function batteryText(d) {
        if (!d.batteryAvailable) return "";
        const b = d.battery;
        return Math.round(b <= 1 ? b * 100 : b) + "% ";
    }

    onOpenChanged: if (!open && Bt.adapter?.discovering) Bt.adapter.discovering = false
    Component.onDestruction: if (Bt.adapter?.discovering) Bt.adapter.discovering = false

    SectionHeader {
        title: "Bluetooth"
        checked: Bt.enabled
        onToggled: c => { if (Bt.adapter) Bt.adapter.enabled = c; }
    }

    PopupRow {
        visible: Bt.enabled
        icon: ""
        text: Bt.adapter?.discovering ? "Scanning…" : "Scan for devices"
        highlighted: Bt.adapter?.discovering ?? false
        onClicked: Bt.adapter.discovering = !Bt.adapter.discovering
    }

    Repeater {
        model: Bt.enabled ? pop.devices.filter(d => d.paired || Bt.adapter.discovering).slice(0, 12) : []

        delegate: PopupRow {
            id: row
            required property var modelData

            icon: pop.deviceIcon(modelData)
            text: modelData.name
            highlighted: modelData.connected
            trailing: modelData.pairing ? "pairing…"
                : modelData.state === BluetoothDeviceState.Connecting ? "…"
                : modelData.connected ? pop.batteryText(modelData) + ""
                : modelData.paired ? "" : "new"

            onClicked: {
                const d = modelData;
                if (d.connected) d.disconnect();
                else if (d.paired) d.connect();
                else d.pair();
            }

            // Freshly paired → trust and connect.
            Connections {
                target: row.modelData
                function onPairedChanged() {
                    if (row.modelData.paired && !row.modelData.connected) {
                        row.modelData.trusted = true;
                        row.modelData.connect();
                    }
                }
            }
        }
    }

    Text {
        visible: !Bt.enabled
        text: "Bluetooth is off"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }
}
