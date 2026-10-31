pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System load, read directly from /proc and /sys (no helper processes in the 2s loop).
// Bar values (CPU, RAM, GPU, VRAM) are always polled; popup-only values
// (frequency, temperatures, load average, uptime, top processes) only while `detailed` is true.
Singleton {
    id: root

    property bool detailed: false   // set while the stats popup is visible

    property int cpu: 0
    property int cpuFreq: 0          // MHz
    property real cpuTemp: -1        // °C, -1 = unknown
    property real memTotal: 0        // KiB
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property int gpu: -1             // -1 = no GPU stats
    property real gpuTemp: -1
    property real vramTotal: 0       // bytes
    property real vramUsed: 0
    property real nvmeTemp: -1
    property string load: ""
    property real uptime: 0
    property var processes: []       // [{ name, cpu, mem }]

    readonly property int mem: memTotal > 0 ? Math.round(100 * memUsed / memTotal) : 0
    readonly property int vram: vramTotal > 0 ? Math.round(100 * vramUsed / vramTotal) : -1

    // Sensor paths, found once at startup (hwmon/card numbers differ between machines and boots).
    property string gpuDir: ""
    property string cpuTempPath: ""
    property string gpuTempPath: ""
    property string nvmeTempPath: ""
    property bool nvidia: false

    property var _prevCpu: null

    function parseStat(text) {
        const f = text.slice(0, text.indexOf("\n")).trim().split(/\s+/).slice(1, 9).map(Number);
        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);
        if (_prevCpu && total > _prevCpu.total)
            cpu = Math.round(100 * (1 - (idle - _prevCpu.idle) / (total - _prevCpu.total)));
        _prevCpu = { idle: idle, total: total };
    }
    function parseMeminfo(text) {
        const v = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m) v[m[1]] = Number(m[2]);
        }
        memTotal = v.MemTotal ?? 0;
        memUsed = memTotal - (v.MemAvailable ?? 0);
        swapTotal = v.SwapTotal ?? 0;
        swapUsed = swapTotal - (v.SwapFree ?? 0);
    }
    function milli(text) {
        const n = parseInt(text);
        return isNaN(n) ? -1 : n / 1000;
    }

    // ── one-time discovery ──
    Process {
        running: true
        command: ["sh", "-c", `
            for d in /sys/class/drm/card*/device; do
                [ -r "$d/gpu_busy_percent" ] && { echo "gpu=$d"; break; }
            done
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name" 2>/dev/null)" in
                    k10temp|coretemp) echo "cputemp=$h/temp1_input" ;;
                    amdgpu) echo "gputemp=$h/temp1_input" ;;
                    nvme) echo "nvmetemp=$h/temp1_input" ;;
                esac
            done
            command -v nvidia-smi >/dev/null 2>&1 && echo "nvidia=1"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0) continue;
                    const k = line.slice(0, i), v = line.slice(i + 1);
                    if (k === "gpu") root.gpuDir = v;
                    else if (k === "cputemp" && !root.cpuTempPath) root.cpuTempPath = v;
                    else if (k === "gputemp") root.gpuTempPath = v;
                    else if (k === "nvmetemp" && !root.nvmeTempPath) root.nvmeTempPath = v;
                    else if (k === "nvidia") root.nvidia = true;
                }
            }
        }
    }

    // ── always polled ──
    FileView { id: statFile; path: "/proc/stat"; onLoaded: root.parseStat(text()) }
    FileView { id: memFile; path: "/proc/meminfo"; onLoaded: root.parseMeminfo(text()) }
    FileView { id: gpuBusy; path: root.gpuDir ? root.gpuDir + "/gpu_busy_percent" : ""; onLoaded: root.gpu = parseInt(text()) }
    FileView { id: vramUsedFile; path: root.gpuDir ? root.gpuDir + "/mem_info_vram_used" : ""; onLoaded: root.vramUsed = Number(text()) }
    FileView { path: root.gpuDir ? root.gpuDir + "/mem_info_vram_total" : ""; onLoaded: root.vramTotal = Number(text()) }

    // ── popup only ──
    FileView { id: cpuinfo; path: root.detailed ? "/proc/cpuinfo" : ""
        onLoaded: {
            const re = /^cpu MHz\s*:\s*([\d.]+)/gm, mhz = [], t = text();
            let m;
            while ((m = re.exec(t)) !== null) mhz.push(Number(m[1]));
            root.cpuFreq = mhz.length ? Math.round(mhz.reduce((a, b) => a + b, 0) / mhz.length) : 0;
        }
    }
    FileView { id: cpuTempFile; path: root.detailed ? root.cpuTempPath : ""; onLoaded: root.cpuTemp = root.milli(text()) }
    FileView { id: gpuTempFile; path: root.detailed ? root.gpuTempPath : ""; onLoaded: root.gpuTemp = root.milli(text()) }
    FileView { id: nvmeTempFile; path: root.detailed ? root.nvmeTempPath : ""; onLoaded: root.nvmeTemp = root.milli(text()) }
    FileView { id: loadFile; path: root.detailed ? "/proc/loadavg" : ""; onLoaded: root.load = text().split(" ").slice(0, 3).join(" ") }
    FileView { id: uptimeFile; path: root.detailed ? "/proc/uptime" : ""; onLoaded: root.uptime = parseFloat(text()) }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (root.gpuDir) { gpuBusy.reload(); vramUsedFile.reload(); }
            if (root.detailed) {
                cpuinfo.reload(); loadFile.reload(); uptimeFile.reload();
                if (root.cpuTempPath) cpuTempFile.reload();
                if (root.gpuTempPath) gpuTempFile.reload();
                if (root.nvmeTempPath) nvmeTempFile.reload();
                psProc.running = true;
            }
        }
    }

    // NVIDIA has no sysfs counters: one long-running nvidia-smi that prints every 2s.
    Process {
        running: root.nvidia && !root.gpuDir
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
            "--format=csv,noheader,nounits", "-l", "2"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(",").map(s => Number(s.trim()));
                if (v.length < 4) return;
                root.gpu = v[0];
                root.vramUsed = v[1] * 1048576;
                root.vramTotal = v[2] * 1048576;
                root.gpuTemp = v[3];
            }
        }
    }

    // Top processes (popup only). Second `top` sample = usage over the last 0.5s.
    Process {
        id: psProc
        command: ["top", "-b", "-n", "2", "-d", "0.5", "-o", "%CPU", "-w", "512"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                let start = -1;
                lines.forEach((l, i) => { if (/^\s*PID\s+USER/.test(l)) start = i; });
                if (start < 0) return;
                root.processes = lines.slice(start + 1)
                    .map(l => l.trim().split(/\s+/))
                    .filter(p => p.length >= 12 && p[11] !== "top")
                    .slice(0, 6)
                    .map(p => ({ name: p.slice(11).join(" "), cpu: Number(p[8].replace(",", ".")), mem: Number(p[9].replace(",", ".")) }));
            }
        }
    }
    onDetailedChanged: if (detailed) psProc.running = true
}
