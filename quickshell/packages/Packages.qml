import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

// Installed packages from every source (pacman, AUR, Flatpak, npm, ...), shown full screen.
// IPC: qs ipc call packages toggle
// One process per source (list.sh <job>) runs in parallel, so a slow source never blocks the rest.
Scope {
    id: root

    property bool open: false
    property var bySource: ({})   // job -> parsed items
    property var items: []        // every job's items, flattened
    property int loading: 0       // jobs still running

    readonly property string script: Quickshell.shellPath("packages/list.sh")
    readonly property var jobs: ["pacman", "flatpak", "npm", "bun", "cargo", "pipx", "go", "dotnet", "sdkman", "nvm"]

    function show() { open = true; reload(); }
    function hide() { open = false; }

    function reload() {
        if (loading > 0) return;
        loading = jobs.length;
        safety.restart();
        for (let i = 0; i < runners.count; i++)
            runners.objectAt(i).running = true;
    }

    // Lines: source \t name \t version \t size \t reason \t repo \t kind \t epoch \t description
    // kind: "used" (epoch = last run), "idle" (not run since the install/update at epoch), "" (no executables)
    function finish(job, text) {
        const out = [];
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f.length < 8) continue;
            const desc = f.slice(8).join(" ");
            out.push({ source: f[0], name: f[1], version: f[2], size: parseInt(f[3]) || 0,
                reason: f[4], repo: f[5], kind: f[6], when: (parseInt(f[7]) || 0) * 1000,
                desc: desc, hay: (f[1] + " " + desc).toLowerCase() });
        }
        const m = Object.assign({}, bySource);
        m[job] = out;
        bySource = m;
        items = Object.values(m).reduce((acc, a) => acc.concat(a), []);
        loading = Math.max(0, loading - 1);
        if (loading === 0) safety.stop();
    }

    // A job that never reports back must not leave the spinner running forever.
    Timer {
        id: safety
        interval: 30000
        onTriggered: root.loading = 0
    }

    Instantiator {
        id: runners
        model: root.jobs
        delegate: Process {
            id: p
            required property string modelData
            command: ["bash", root.script, modelData]
            stdout: StdioCollector {
                onStreamFinished: root.finish(p.modelData, text)
            }
        }
    }

    IpcHandler {
        target: "packages"
        function toggle(): void { root.open ? root.hide() : root.show(); }
    }

    LazyLoader {
        active: root.open
        PackagesWindow {
            pk: root
        }
    }
}
