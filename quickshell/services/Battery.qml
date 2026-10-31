pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property bool present: dev?.isLaptopBattery ?? false
    // UPower may report 0..1 or 0..100 depending on the backend.
    readonly property int percent: {
        const p = dev?.percentage ?? 0;
        return Math.round(p <= 1 ? p * 100 : p);
    }
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
    readonly property bool plugged: !UPower.onBattery
    readonly property real secondsLeft: charging ? (dev?.timeToFull ?? 0) : (dev?.timeToEmpty ?? 0)
}
