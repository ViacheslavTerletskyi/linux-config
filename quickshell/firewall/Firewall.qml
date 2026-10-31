import QtQuick
import Quickshell
import Quickshell.Io

// Firewall (ufw) control panel.
// IPC: qs ipc call firewall toggle
// State and processes live here (not in the window) so a pending pkexec survives the window closing.
Scope {
    id: root

    property bool open: false
    property bool enabled: false
    property bool busy: false
    property bool loaded: false   // rules fetched at least once (listing them needs root)
    property var rules: []
    property string message: ""

    function show() { open = true; readState(); }
    function hide() { open = false; }
    function readState() { stateProc.running = true; }

    // One pkexec call = one password prompt: run the ufw action (if any), then print the fresh rule list.
    // The action's own output goes to stderr (shown as message), the rule list to stdout (parsed).
    function run(args) {
        if (busy) return;
        busy = true;
        message = "";
        proc.command = ["pkexec", "sh", "-c",
            '[ $# -gt 0 ] && { ufw "$@" 1>&2 || rc=$?; }; ufw status numbered; exit ${rc:-0}',
            "sh", ...args];
        proc.running = true;
    }
    function reload() { run([]); }
    function setEnabled(on) { run(on ? ["--force", "enable"] : ["disable"]); }
    function allow(spec) { run(["allow", spec]); }
    function remove(num) { run(["--force", "delete", String(num)]); }

    // "[ 3] 22/tcp   LIMIT IN   192.168.0.0/16" → { num, to, action, from }
    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const m = line.match(/^\[\s*(\d+)\]\s+(.*?)\s+(ALLOW|DENY|REJECT|LIMIT)((?: IN| OUT| FWD)?)\s+(.*?)\s*$/);
            if (m) out.push({ num: parseInt(m[1]), to: m[2], action: m[3] + m[4], from: m[5] });
        }
        return out;
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "grep -qi '^ENABLED=yes' /etc/ufw/ufw.conf && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: root.enabled = text.trim() === "on"
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                // Empty output = pkexec was cancelled: keep the old list.
                if (!text.includes("Status:")) return;
                root.rules = root.parse(text);
                root.loaded = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.message = text.trim().split("\n")[0]
        }
        onExited: code => {
            root.busy = false;
            if (code === 126 || code === 127) root.message = "Cancelled";
            root.readState();
        }
    }

    IpcHandler {
        target: "firewall"
        function toggle(): void { root.open ? root.hide() : root.show(); }
    }

    LazyLoader {
        active: root.open
        FirewallWindow {
            fw: root
        }
    }
}
