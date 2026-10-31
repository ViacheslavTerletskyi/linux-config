import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// App launcher + clipboard history (cliphist).
// IPC: qs ipc call launcher toggle | clipboard
// This part is always loaded and tiny; the window (LauncherWindow.qml) exists only while open.
Scope {
    id: root

    property bool open: false
    property string mode: "apps" // "apps" | "clipboard"

    // Window that was focused before the launcher opened: clipboard picks are pasted into it.
    property string pasteAddress: ""
    property string pasteClass: ""
    readonly property var terminals: ["kitty", "foot", "footclient", "alacritty", "org.wezfurlong.wezterm",
        "com.mitchellh.ghostty", "org.kde.konsole", "org.gnome.terminal", "org.gnome.ptyxis", "xterm", "tilix"]

    function show(m) {
        if (!open) {
            const t = Hyprland.activeToplevel;
            const addr = t?.address ?? "";
            pasteAddress = addr === "" ? "" : (addr.startsWith("0x") ? addr : "0x" + addr);
            pasteClass = (t?.wayland?.appId || t?.lastIpcObject?.class || "").toLowerCase();
        }
        mode = m;
        open = true;
    }
    function hide() { open = false; }
    function pick(item) {
        if (!item) return;
        if (item.kind === "app")
            item.entry.execute();
        else {
            copyProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", item.line];
            copyProc.running = true;
        }
        hide();
    }

    // Send the paste shortcut to the window the launcher was opened from.
    // key "code:55" = the V key, so it works with any keyboard layout (e.g. Ukrainian).
    function pasteIntoPrevious() {
        if (pasteAddress === "") return;
        const mods = terminals.includes(pasteClass) ? "CTRL SHIFT" : "CTRL";
        Quickshell.execDetached(["hyprctl", "dispatch",
            'hl.dsp.send_shortcut({ mods = "' + mods + '", key = "code:55", window = "address:' + pasteAddress + '" })']);
    }

    Process {
        id: copyProc
        onExited: pasteTimer.restart()
    }
    // Small delay: let the launcher close and focus return to the window.
    Timer {
        id: pasteTimer
        interval: 120
        onTriggered: root.pasteIntoPrevious()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.open && root.mode === "apps" ? root.hide() : root.show("apps"); }
        function clipboard(): void { root.open && root.mode === "clipboard" ? root.hide() : root.show("clipboard"); }
    }

    LazyLoader {
        active: root.open
        LauncherWindow {
            launcher: root
        }
    }
}
