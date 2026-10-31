pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon: history (tracked), on-screen popups, do-not-disturb.
Singleton {
    id: root

    property alias dnd: saved.dnd
    property bool centerOpen: false
    // True while something is screencasting: popups are suppressed (replaces swaync-dnd-auto.sh)
    property bool casting: false
    property list<QtObject> popups: []
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

    function removePopup(n) {
        popups = popups.filter(p => p !== n);
    }
    function clearAll() {
        for (const n of history.slice())
            n.dismiss();
    }
    // Timeout in ms. Critical ones stay until closed.
    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        const t = n.expireTimeout;
        if (t > 0) return t < 1000 ? t * 1000 : t;
        return 5000;
    }

    // DND survives restarts: ~/.local/state/quickshell/by-shell/<id>/notifications.json
    FileView {
        path: Quickshell.statePath("notifications.json")
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: saved
            property bool dnd: false
        }
    }

    // Image file a notification refers to, if any:
    // our screenshot tool sets x-qs-file; hyprshot passes the file as its icon.
    function fileOf(n) {
        const isImage = p => /^\/.+\.(png|jpe?g|webp|gif|bmp)$/i.test(p);
        const strip = p => String(p ?? "").replace(/^file:\/\//, "");
        const candidates = [n.hints["x-qs-file"], n.appIcon, n.image].map(strip);
        return candidates.find(isImage) ?? "";
    }

    // Open the file manager with the file selected (freedesktop FileManager1, Dolphin implements it).
    function showInFolder(path) {
        const uri = "file://" + encodeURI(path).replace(/'/g, "%27");
        Quickshell.execDetached(["gdbus", "call", "--session",
            "--dest", "org.freedesktop.FileManager1",
            "--object-path", "/org/freedesktop/FileManager1",
            "--method", "org.freedesktop.FileManager1.ShowItems", "['" + uri + "']", ""]);
        centerOpen = false;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        extraHints: ["x-qs-file"]   // our own hint: file the notification is about

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => root.removePopup(n));
            if (!(root.dnd || root.casting) || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups];
        }
    }

    // Poll PipeWire every 5s for an active screen-cast stream
    Process {
        id: castCheck
        command: ["sh", "-c", "pw-dump | grep -q api.screen-cast.raw"]
        onExited: code => root.casting = (code === 0)
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: castCheck.running = true
    }

    IpcHandler {
        target: "notifications"
        function toggleDnd(): void { root.dnd = !root.dnd; }
        function setDnd(on: bool): void { root.dnd = on; }
        function toggleCenter(): void { root.centerOpen = !root.centerOpen; }
        function clear(): void { root.clearAll(); }
    }
}
