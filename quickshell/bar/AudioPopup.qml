import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.services
import qs.theme
import qs.widgets

// Output and input: current device (click → device list), volume, per-app mixer.
DropdownPopup {
    id: pop
    contentWidth: 340

    property bool outputsOpen: false
    property bool inputsOpen: false

    onOpenChanged: if (!open) { outputsOpen = false; inputsOpen = false; }

    PwObjectTracker {
        objects: [...Audio.sinks, ...Audio.sources, ...Audio.streams]
    }

    component Caption: Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        font.bold: true
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 1
        color: Theme.surface1
    }

    // Glyph or app icon (clickable = mute) · slider · percent.
    component VolumeRow: RowLayout {
        id: row
        property string icon: ""
        property string appIcon: ""
        property string label: ""
        property real value: 0
        property bool muted: false
        signal toggleMute
        signal moved(real v)

        Layout.fillWidth: true
        spacing: 10

        Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            opacity: row.muted ? 0.4 : 1
            Text {
                anchors.centerIn: parent
                visible: !appImg.visible
                text: row.muted && row.icon === "" ? "" : (row.icon || "")
                color: row.muted ? Theme.overlay0 : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
            }
            IconImage {
                id: appImg
                anchors.centerIn: parent
                implicitSize: 20
                visible: row.appIcon !== "" && status === Image.Ready
                source: row.appIcon !== "" ? Quickshell.iconPath(row.appIcon, true) : ""
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggleMute()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                visible: row.label !== ""
                text: row.label
                elide: Text.ElideRight
                color: row.muted ? Theme.overlay0 : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
            VolumeSlider {
                Layout.fillWidth: true
                value: row.value
                dimmed: row.muted
                onMoved: v => row.moved(v)
            }
        }
        Text {
            Layout.preferredWidth: 40
            Layout.alignment: Qt.AlignBottom
            text: Math.round(row.value * 100) + "%"
            color: row.muted ? Theme.overlay0 : Theme.text
            horizontalAlignment: Text.AlignRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    // Current device; click expands the list of all devices.
    component DevicePicker: ColumnLayout {
        id: picker
        property var nodes: []
        property var current: null
        property string icon: ""
        property bool expanded: false
        signal toggled
        signal picked(var node)

        Layout.fillWidth: true
        spacing: 0

        PopupRow {
            icon: picker.icon
            text: Audio.nodeName(picker.current) || "No device"
            trailing: picker.nodes.length > 1 ? (picker.expanded ? "" : "") : ""
            onClicked: if (picker.nodes.length > 1) picker.toggled()
        }
        Rectangle {
            visible: picker.expanded
            Layout.fillWidth: true
            Layout.leftMargin: 8
            implicitHeight: devCol.implicitHeight + 8
            radius: Theme.radius
            color: Theme.crust

            ColumnLayout {
                id: devCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0
                Repeater {
                    model: picker.expanded ? picker.nodes : []
                    delegate: PopupRow {
                        required property var modelData
                        text: Audio.nodeName(modelData)
                        highlighted: modelData === picker.current
                        trailing: modelData === picker.current ? "" : ""
                        onClicked: picker.picked(modelData)
                    }
                }
            }
        }
    }

    // ── Output ──
    Caption { text: "Output" }
    DevicePicker {
        nodes: Audio.sinks
        current: Audio.sink
        icon: ""
        expanded: pop.outputsOpen
        onToggled: pop.outputsOpen = !pop.outputsOpen
        onPicked: n => { Pipewire.preferredDefaultAudioSink = n; pop.outputsOpen = false; }
    }
    VolumeRow {
        icon: Audio.muted ? "" : ""
        value: Audio.volume
        muted: Audio.muted
        onToggleMute: Audio.toggleMute()
        onMoved: v => Audio.setVolume(v)
    }
    Repeater {
        model: Audio.playback
        delegate: VolumeRow {
            required property var modelData
            Layout.leftMargin: 12
            appIcon: Audio.appIcon(modelData)
            label: Audio.appName(modelData)
            value: modelData.audio?.volume ?? 0
            muted: modelData.audio?.muted ?? false
            onToggleMute: modelData.audio.muted = !modelData.audio.muted
            onMoved: v => modelData.audio.volume = v
        }
    }

    Divider {}

    // ── Input ──
    Caption { text: "Input" }
    DevicePicker {
        nodes: Audio.sources
        current: Audio.source
        icon: ""
        expanded: pop.inputsOpen
        onToggled: pop.inputsOpen = !pop.inputsOpen
        onPicked: n => { Pipewire.preferredDefaultAudioSource = n; pop.inputsOpen = false; }
    }
    VolumeRow {
        icon: Audio.micMuted ? "" : ""
        value: Audio.micVolume
        muted: Audio.micMuted
        onToggleMute: Audio.toggleMicMute()
        onMoved: v => Audio.setMicVolume(v)
    }
    Repeater {
        model: Audio.recording
        delegate: VolumeRow {
            required property var modelData
            Layout.leftMargin: 12
            appIcon: Audio.appIcon(modelData)
            label: Audio.appName(modelData)
            value: modelData.audio?.volume ?? 0
            muted: modelData.audio?.muted ?? false
            onToggleMute: modelData.audio.muted = !modelData.audio.muted
            onMoved: v => modelData.audio.volume = v
        }
    }

    Divider {}
    PopupRow {
        icon: ""
        text: "More settings (pavucontrol)"
        onClicked: {
            Quickshell.execDetached(["pavucontrol"]);
            pop.open = false;
        }
    }
}
