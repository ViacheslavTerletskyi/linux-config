import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Region screenshot with editing before saving.
// Flow: freeze all monitors (grim) → select region / click a window → adjust, draw, add text
//       → Enter copies to clipboard and saves to ~/Pictures/screenshots.
// Also instant captures without editor: hover and click any monitor / window on any monitor.
// IPC: qs ipc call screenshot region|screen|window|cancel
Scope {
    id: root

    property bool active: false
    property string stamp: ""
    readonly property string tmpDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-screenshot"
    readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/screenshots"

    // Hyprland state at capture time (for "click a window").
    property var clients: []
    property var visibleWorkspaces: []

    property string focusScreen: ""   // monitor that gets keyboard focus
    property string selScreen: ""     // monitor the selection is on ("" = none yet)
    property var sel: null            // { x, y, w, h } in that monitor's coordinates
    property var annotations: []      // finished shapes on selScreen

    property string pick: ""          // "" = region editor | screen | window (click to capture instantly)
    property var cursor: ({ x: -99999, y: -99999 })   // global pointer position, polled while picking
    property string mode: "select"    // select | pen | arrow | rect | text
    property color color: "#f38ba8"
    property int size: 4
    readonly property var colors: ["#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#89b4fa", "#cba6f7", "#ffffff", "#11111b"]
    readonly property var sizes: [2, 4, 8]

    signal exportRequested(string screenName, string path)
    signal commitTextRequested

    function shotPath(name) {
        return tmpDir + "/" + name + "-" + stamp + ".ppm";
    }

    function start(kind) {
        if (active || capture.running) return;
        pick = kind ?? "";
        stamp = String(Date.now());
        focusScreen = Hyprland.focusedMonitor?.name ?? "";
        selScreen = "";
        sel = null;
        annotations = [];
        mode = "select";
        capture.command = ["sh", "-c", captureScript, "sh", tmpDir, saveDir, stamp, ...Quickshell.screens.map(s => s.name)];
        capture.running = true;
    }

    // Instant capture of what the user clicked in pick mode: kind = "screen" (arg = monitor) | "window" (arg = "x,y WxH").
    function grab(kind, arg) {
        active = false;
        cleanup();
        Quickshell.execDetached(["sh", "-c", grabScript, "sh", saveDir, kind, arg]);
    }

    readonly property string grabScript: '
        save=$1; kind=$2; arg=$3
        mkdir -p "$save"
        f="$save/$(date +%Y-%m-%d-%H%M%S)_screenshot.png"
        sleep 0.25   # let the overlay unmap before capturing
        if [ "$kind" = window ]; then grim -g "$arg" "$f"; else grim -o "$arg" "$f"; fi
        if [ -s "$f" ]; then
            wl-copy --type image/png < "$f"
            notify-send -a Screenshot -h "string:image-path:$f" -h "string:x-qs-file:$f" "Screenshot copied" "Saved to $f · click to show in folder"
        else
            notify-send -a Screenshot -u critical "Screenshot failed" "Nothing captured"
        fi
    '

    function cancel() {
        active = false;
        cleanup();
    }

    function undo() {
        if (annotations.length > 0) annotations = annotations.slice(0, -1);
    }

    function addAnnotation(a) {
        annotations = [...annotations, a];
    }

    function finish() {
        if (!sel || sel.w < 2 || sel.h < 2) return;
        commitTextRequested();
        const name = Qt.formatDateTime(new Date(), "yyyy-MM-dd-hhmmss") + "_screenshot.png";
        exportRequested(selScreen, saveDir + "/" + name);
    }

    // Called by the overlay. Pixels are cut straight from the original grim frame (no re-render, no scaling);
    // ann = transparent full-screen PNG with the annotations, or "" when there are none.
    // geom = "WxH+X+Y" in physical pixels. The script removes the temp files itself (after reading them).
    function save(src, ann, geom, path) {
        active = false;
        Quickshell.execDetached(["sh", "-c", saveScript, "sh", src, ann, geom, path, tmpDir]);
    }

    function saveFailed(path) {
        active = false;
        cleanup();
        Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-u", "critical", "Screenshot failed", "Could not write " + path]);
    }

    readonly property string saveScript: '
        src=$1; ann=$2; geom=$3; f=$4; dir=$5
        mkdir -p "$(dirname "$f")"
        if [ -n "$ann" ]; then
            magick "$src" "$ann" -composite -crop "$geom" +repage -strip "$f"
        else
            magick "$src" -crop "$geom" +repage -strip "$f"
        fi
        rm -f "$dir"/*.ppm "$dir"/*.png
        if [ -s "$f" ]; then
            wl-copy --type image/png < "$f"
            notify-send -a Screenshot -h "string:image-path:$f" -h "string:x-qs-file:$f" "Screenshot copied" "Saved to $f · click to show in folder"
        else
            notify-send -a Screenshot -u critical "Screenshot failed" "Could not write $f"
        fi
    '

    function cleanup() {
        Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.ppm "$1"/*.png', "sh", tmpDir]);
    }

    readonly property string captureScript: '
        dir=$1; save=$2; stamp=$3; shift 3
        mkdir -p "$dir" "$save"
        rm -f "$dir"/*.ppm
        for o in "$@"; do grim -t ppm -o "$o" "$dir/$o-$stamp.ppm" & done
        wait
        hyprctl clients -j | tr -d "\n"; echo
        hyprctl monitors -j | tr -d "\n"; echo
    '

    Process {
        id: capture
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                try {
                    root.clients = JSON.parse(lines[0]);
                    const mons = JSON.parse(lines[1]);
                    // No Array.flatMap in QML's JS engine
                    const ids = [];
                    for (const m of mons) ids.push(m.activeWorkspace?.id, m.specialWorkspace?.id);
                    root.visibleWorkspaces = ids.filter(id => id);
                } catch (e) {
                    root.clients = [];
                    root.visibleWorkspaces = [];
                }
                root.active = true;
            }
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: root.active && root.pick !== ""
        onTriggered: if (!cursorProc.running) cursorProc.running = true
    }
    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().split(/[ ,]+/).map(Number);
                if (m.length === 2 && !m.some(isNaN) && (m[0] !== root.cursor.x || m[1] !== root.cursor.y))
                    root.cursor = { x: m[0], y: m[1] };
            }
        }
    }

    IpcHandler {
        target: "screenshot"
        function region(): void { root.start(""); }
        function screen(): void { root.start("screen"); }
        function window(): void { root.start("window"); }
        function cancel(): void { root.cancel(); }
    }

    // Overlays exist only while a screenshot is being taken.
    LazyLoader {
        active: root.active
        Scope {
            Variants {
                model: Quickshell.screens
                ScreenshotOverlay {
                    tool: root   // not `tool: tool` — inside the overlay that name means its own property
                }
            }
        }
    }
}
