pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var activeWifi: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    readonly property bool wired: wiredDevice !== null
    readonly property bool connected: wired || activeWifi !== null
    readonly property string ssid: activeWifi?.name ?? ""
    readonly property int signal: {
        const s = activeWifi?.signalStrength ?? 0;
        return Math.round(s <= 1 ? s * 100 : s);
    }
    readonly property string address: (wired ? wiredDevice?.address : wifiDevice?.address) ?? ""

    // Nerd Font wifi strength glyphs.
    function signalIcon(pct) {
        const cps = [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928];
        return String.fromCodePoint(cps[Math.min(4, Math.floor(pct / 20))]);
    }
}
