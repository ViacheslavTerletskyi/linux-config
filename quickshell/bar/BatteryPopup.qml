import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.services
import qs.theme
import qs.widgets

// Battery state and power mode (performance / balanced / power saver).
DropdownPopup {
    id: pop
    contentWidth: 280

    function duration(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60);
        return (h > 0 ? h + "h " : "") + m + "m";
    }
    readonly property string status: {
        const left = Battery.secondsLeft > 0 ? " · " + duration(Battery.secondsLeft) : "";
        if (Battery.charging) return "Charging" + (left ? left + " to full" : "");
        if (Battery.plugged) return "Plugged in";
        return "On battery" + (left ? left + " left" : "");
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Battery"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
        }
        Text {
            text: Battery.percent + "%"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
    Text {
        Layout.fillWidth: true
        text: pop.status
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 1
        color: Theme.surface1
    }
    Text {
        Layout.fillWidth: true
        text: "Power mode"
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        font.bold: true
    }

    Repeater {
        model: [
            { p: PowerProfile.Performance, icon: "󰓅", name: "Performance" },
            { p: PowerProfile.Balanced, icon: "󰾅", name: "Balanced" },
            { p: PowerProfile.PowerSaver, icon: "󰾆", name: "Power saver" }
        ].filter(m => m.p !== PowerProfile.Performance || Battery.hasPerformance)
        delegate: PopupRow {
            required property var modelData
            readonly property bool current: Battery.profile === modelData.p
            icon: modelData.icon
            text: modelData.name
            highlighted: current
            trailing: current ? "" : ""
            onClicked: Battery.setProfile(modelData.p)
        }
    }

    Text {
        visible: Battery.profile === PowerProfile.Performance
            && Battery.degradation !== PerformanceDegradationReason.None
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Performance is limited: " + PerformanceDegradationReason.toString(Battery.degradation)
        color: Theme.yellow
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }
}
