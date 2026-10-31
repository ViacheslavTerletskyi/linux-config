import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.services
import qs.theme
import qs.widgets

// CPU · RAM · GPU · VRAM in one block; click shows details.
BarModule {
    id: root

    function part(icon, pct) {
        const s = pct + "% " + icon;
        return pct >= 85 ? "<font color='" + Theme.red + "'>" + s + "</font>" : s;
    }
    function gib(kib) { return (kib / 1048576).toFixed(1); }
    function mib(bytes) { return Math.round(bytes / 1048576); }
    function temp(t) { return t >= 0 ? Math.round(t) + "°C" : ""; }
    function join(parts) { return parts.filter(p => p !== "").join(" · "); }
    function duration(sec) {
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m";
    }

    // Always rich text: &nbsp; spacers and <font> highlights must never show up literally.
    textFormat: Text.StyledText
    text: [
        part("", SysStats.cpu),
        part("", SysStats.mem),
        SysStats.gpu >= 0 ? part("󰢮", SysStats.gpu) : "",
        SysStats.vram >= 0 ? part("󰈚", SysStats.vram) : ""
    ].filter(s => s !== "").join("&nbsp;&nbsp;&nbsp;")  // rich text: plain spaces collapse

    active: popupOpen
    onClicked: popupOpen = !popupOpen

    // Popup is created when opened and destroyed when closed.
    property bool popupOpen: false
    LazyLoader {
        active: root.popupOpen
        DropdownPopup {
            anchorItem: root
            open: true
            onOpenChanged: if (!open) root.popupOpen = false
            contentWidth: 330
            onVisibleChanged: SysStats.detailed = visible
            Component.onCompleted: SysStats.detailed = visible
            Component.onDestruction: SysStats.detailed = false

            Text {
                text: "System load"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }

            StatRow {
                icon: ""
                label: "CPU"
                value: root.join([SysStats.cpu + "%", (SysStats.cpuFreq / 1000).toFixed(1) + " GHz", root.temp(SysStats.cpuTemp)])
                percent: SysStats.cpu
            }
            StatRow {
                icon: ""
                label: "RAM"
                value: root.gib(SysStats.memUsed) + " / " + root.gib(SysStats.memTotal) + " GiB (" + SysStats.mem + "%)"
                percent: SysStats.mem
            }
            StatRow {
                visible: SysStats.swapTotal > 0
                icon: ""
                label: "Swap"
                value: root.gib(SysStats.swapUsed) + " / " + root.gib(SysStats.swapTotal) + " GiB"
                percent: SysStats.swapTotal > 0 ? 100 * SysStats.swapUsed / SysStats.swapTotal : 0
            }
            StatRow {
                visible: SysStats.gpu >= 0
                icon: "󰢮"
                label: "GPU"
                value: root.join([SysStats.gpu + "%", root.temp(SysStats.gpuTemp)])
                percent: SysStats.gpu
            }
            StatRow {
                visible: SysStats.vram >= 0
                icon: "󰈚"
                label: "VRAM"
                value: root.mib(SysStats.vramUsed) + " / " + root.mib(SysStats.vramTotal) + " MiB (" + SysStats.vram + "%)"
                percent: SysStats.vram
            }
            StatRow {
                visible: SysStats.nvmeTemp >= 0
                icon: "󰋊"
                label: "NVMe"
                value: root.temp(SysStats.nvmeTemp)
            }
            StatRow {
                icon: ""
                label: "Load average"
                value: SysStats.load
            }
            StatRow {
                icon: ""
                label: "Uptime"
                value: root.duration(SysStats.uptime)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 1
                color: Theme.surface1
            }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Process"; color: Theme.overlay0; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                Text { Layout.preferredWidth: 50; text: "CPU"; color: Theme.overlay0; horizontalAlignment: Text.AlignRight; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                Text { Layout.preferredWidth: 50; text: "RAM"; color: Theme.overlay0; horizontalAlignment: Text.AlignRight; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
            }
            Repeater {
                model: SysStats.processes
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                    Text { Layout.preferredWidth: 50; text: modelData.cpu.toFixed(1) + "%"; color: Theme.subtext; horizontalAlignment: Text.AlignRight; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                    Text { Layout.preferredWidth: 50; text: modelData.mem.toFixed(1) + "%"; color: Theme.subtext; horizontalAlignment: Text.AlignRight; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                }
            }
        }
    }

}
