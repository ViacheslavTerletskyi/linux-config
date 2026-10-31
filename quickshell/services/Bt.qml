pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.name !== "")
    readonly property var connected: devices.filter(d => d.connected)
}
