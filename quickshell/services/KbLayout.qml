pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property string layout: ""
    readonly property string short: {
        const l = layout.toLowerCase();
        if (l.startsWith("ukrain")) return "UA";
        if (l.startsWith("english")) return "US";
        return layout.slice(0, 2).toUpperCase();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // data: "<keyboard>,<layout name>"
            if (event.name === "activelayout")
                root.layout = event.data.split(",").slice(1).join(",");
        }
    }

    // Initial value: active keymap of the main keyboard.
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards;
                    const kb = kbs.find(k => k.main) ?? kbs[0];
                    if (kb && !root.layout) root.layout = kb.active_keymap;
                } catch (e) {}
            }
        }
    }
}
