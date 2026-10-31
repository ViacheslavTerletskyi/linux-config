import QtQuick
import Quickshell.Hyprland
import qs.theme

// Workspaces that live on this bar's monitor.
Row {
    required property string screenName
    spacing: 2

    Repeater {
        model: Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.monitor?.name === screenName)
            .sort((a, b) => a.id - b.id)

        delegate: BarModule {
            required property var modelData
            text: modelData.name
            active: modelData.focused || modelData.urgent
            activeColor: modelData.urgent ? Theme.red : Theme.blue
            textColor: modelData.active ? Theme.text : Theme.overlay0
            onClicked: modelData.activate()
        }
    }
}
