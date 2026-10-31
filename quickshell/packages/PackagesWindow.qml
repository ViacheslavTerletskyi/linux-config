import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme

// Full-screen package browser: created by Packages.qml when opened, destroyed when closed.
PanelWindow {
    id: win

    required property var pk
    property bool shown: false           // drives the open animation
    property string srcFilter: "all"     // "all" or a source id
    property string reasonFilter: "all"  // "all" | "explicit" | "dep"
    property bool staleOnly: false       // only packages not run in the last 30 days
    property string sortKey: "name"      // "name" | "source" | "size" | "reason" | "last"
    property bool sortAsc: true
    property string notice: ""           // short footer message (e.g. "Copied …")

    readonly property string query: input.text.trim()
    readonly property var terms: query.toLowerCase().split(/\s+/).filter(t => t !== "")

    readonly property int rowHeight: 42
    readonly property int wVersion: 160
    readonly property int wSource: 150
    readonly property int wSize: 100
    readonly property int wReason: 110
    readonly property int wLast: 190
    readonly property int wName: 290

    readonly property real nowMs: Date.now()
    readonly property real staleMs: 30 * 86400000

    readonly property var sourceOrder: ["pacman", "aur", "flatpak", "npm", "bun", "cargo", "pipx", "go", "dotnet", "sdkman", "nvm"]
    readonly property var meta: ({
        pacman: { label: "pacman", color: Theme.blue },
        aur: { label: "AUR", color: Theme.mauve },
        flatpak: { label: "Flatpak", color: Theme.green },
        npm: { label: "npm", color: Theme.red },
        bun: { label: "Bun", color: Theme.peach },
        cargo: { label: "Cargo", color: Theme.yellow },
        pipx: { label: "pipx", color: Theme.teal },
        go: { label: "Go", color: Theme.blue },
        dotnet: { label: ".NET", color: Theme.mauve },
        sdkman: { label: "SDKMAN", color: Theme.peach },
        nvm: { label: "nvm", color: Theme.green }
    })

    // Sources that actually have packages (empty ones get no chip).
    readonly property var presentSources: {
        const have = new Set(pk.items.map(p => p.source));
        return sourceOrder.filter(s => have.has(s));
    }

    function matches(p) {
        for (const t of terms) if (!p.hay.includes(t)) return false;
        return true;
    }

    // Per-source counters respect the search and the reason filter, so chips show what a click would give.
    readonly property var counts: {
        const c = { all: 0 };
        for (const p of pk.items) {
            if (reasonFilter !== "all" && p.reason !== reasonFilter) continue;
            if (!matches(p)) continue;
            c.all++;
            c[p.source] = (c[p.source] ?? 0) + 1;
        }
        return c;
    }

    // "Not used recently": never run since the last (re)install, or last run over 30 days ago.
    // An update replaces the files and resets their access time, so "idle" means "not since the update".
    function isStale(p) {
        return p.kind === "idle" || (p.kind === "used" && nowMs - p.when > staleMs);
    }
    function lastRank(p) { return p.kind === "idle" ? 0 : (p.kind === "used" ? 1 : 2); }

    // Everything the filters let through, before the "not used recently" switch and sorting.
    readonly property var base: pk.items.filter(p => (srcFilter === "all" || p.source === srcFilter)
        && (reasonFilter === "all" || p.reason === reasonFilter) && matches(p))
    readonly property int staleCount: base.filter(p => isStale(p)).length

    readonly property var results: {
        const dir = sortAsc ? 1 : -1;
        const key = sortKey;
        const list = staleOnly ? base.filter(p => isStale(p)) : base.slice();
        list.sort((a, b) => {
            let c = 0;
            if (key === "name") return a.name.localeCompare(b.name) * dir;
            if (key === "size") c = a.size - b.size;
            else if (key === "source") c = sourceOrder.indexOf(a.source) - sourceOrder.indexOf(b.source);
            else if (key === "reason") c = a.reason.localeCompare(b.reason);
            else if (key === "last") {
                // Never-run first, then oldest use; packages with nothing to judge by always go last.
                const ra = lastRank(a), rb = lastRank(b);
                if (ra === 2 || rb === 2) return ra !== rb ? (ra === 2 ? 1 : -1) : a.name.localeCompare(b.name);
                c = ra !== rb ? ra - rb : a.when - b.when;
            }
            return c !== 0 ? c * dir : a.name.localeCompare(b.name);
        });
        return list;
    }
    readonly property real totalSize: results.reduce((s, p) => s + p.size, 0)

    function fmtSize(b) {
        if (!b) return "—";
        const u = ["B", "KiB", "MiB", "GiB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (i === 0 || b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    function fmtDate(ms) {
        const d = new Date(ms);
        return Qt.formatDate(d, d.getFullYear() === new Date(nowMs).getFullYear() ? "d MMM" : "d MMM yyyy");
    }
    function ago(ms) {
        const days = Math.floor((nowMs - ms) / 86400000);
        if (days <= 0) return "today";
        if (days === 1) return "yesterday";
        if (days < 31) return days + " days ago";
        if (days < 365) return Math.floor(days / 30) + " mo ago";
        return Math.floor(days / 365) + " y ago";
    }
    function lastText(p) {
        if (p.kind === "used") return fmtDate(p.when) + " · " + ago(p.when);
        if (p.kind === "idle") return "Not since " + fmtDate(p.when);
        return "—";
    }
    function lastColor(p) {
        if (p.kind === "idle") return Theme.peach;
        if (p.kind === "used") return nowMs - p.when > staleMs ? Theme.yellow : Theme.green;
        return Theme.surface1;
    }
    function setSort(key) {
        if (sortKey === key) sortAsc = !sortAsc;
        else { sortKey = key; sortAsc = key !== "size"; }
    }
    function cycleSource(step) {
        const ids = ["all", ...presentSources];
        const i = ids.indexOf(srcFilter);
        srcFilter = ids[(i + step + ids.length) % ids.length];
    }
    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    // Name with the first matching search term highlighted.
    function markup(name) {
        const low = name.toLowerCase();
        for (const t of terms) {
            const i = low.indexOf(t);
            if (i < 0) continue;
            return escapeHtml(name.slice(0, i))
                + "<font color='" + Theme.blue + "'><b>" + escapeHtml(name.slice(i, i + t.length)) + "</b></font>"
                + escapeHtml(name.slice(i + t.length));
        }
        return escapeHtml(name);
    }
    function copyName(p) {
        if (!p) return;
        Quickshell.execDetached(["wl-copy", p.name]);
        notice = "Copied " + p.name;
        noticeTimer.restart();
    }
    function move(delta) {
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    Component.onCompleted: { shown = true; input.forceActiveFocus(); }
    onResultsChanged: list.currentIndex = 0

    Timer {
        id: noticeTimer
        interval: 2200
        onTriggered: win.notice = ""
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: true
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusiveZone: 0    // stay out of the bar's reserved area
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-packages"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 48
            anchors.rightMargin: 48
            anchors.topMargin: 32
            anchors.bottomMargin: 24
            spacing: 18

            // ── Top bar: title, search, actions ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    text: ""  // archive
                    color: Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: 26
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Installed packages"
                        color: Theme.text
                        font.family: Theme.uiFont
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: win.pk.items.length + " in total · " + win.presentSources.length + " sources"
                        color: Theme.overlay0
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 560
                    implicitHeight: 48
                    radius: 12
                    color: Theme.mantle
                    border.width: 1
                    border.color: input.activeFocus ? Qt.alpha(Theme.blue, 0.5) : Theme.surface0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            text: ""  // search
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                        }
                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            color: Theme.text
                            selectionColor: Qt.alpha(Theme.blue, 0.4)
                            font.family: Theme.uiFont
                            font.pixelSize: 16
                            clip: true

                            Text {
                                visible: input.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search by name or description…"
                                color: Theme.overlay0
                                font: input.font
                            }

                            Keys.onPressed: ev => {
                                const ctrl = ev.modifiers & Qt.ControlModifier;
                                if (ev.key === Qt.Key_Escape) {
                                    if (input.text !== "") input.text = ""; else win.pk.hide();
                                    ev.accepted = true;
                                }
                                else if (ev.key === Qt.Key_Down || (ev.key === Qt.Key_J && ctrl)) { win.move(1); ev.accepted = true; }
                                else if (ev.key === Qt.Key_Up || (ev.key === Qt.Key_K && ctrl)) { win.move(-1); ev.accepted = true; }
                                else if (ev.key === Qt.Key_PageDown) { win.move(12); ev.accepted = true; }
                                else if (ev.key === Qt.Key_PageUp) { win.move(-12); ev.accepted = true; }
                                else if (ev.key === Qt.Key_Tab) { win.cycleSource(1); ev.accepted = true; }
                                else if (ev.key === Qt.Key_Backtab) { win.cycleSource(-1); ev.accepted = true; }
                                else if (ev.key === Qt.Key_R && ctrl) { win.pk.reload(); ev.accepted = true; }
                                else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { win.copyName(win.results[list.currentIndex]); ev.accepted = true; }
                            }
                        }
                        Text {
                            visible: input.text !== ""
                            text: ""  // clear
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { input.text = ""; input.forceActiveFocus(); }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Reload
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 10
                    color: reloadArea.containsMouse ? Theme.surface0 : Theme.mantle
                    border.width: 1
                    border.color: Theme.surface0
                    Text {
                        id: reloadGlyph
                        anchors.centerIn: parent
                        text: ""  // refresh
                        color: win.pk.loading > 0 ? Theme.yellow : Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        RotationAnimator on rotation {
                            running: win.pk.loading > 0
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                        onRotationChanged: if (win.pk.loading === 0 && rotation !== 0) rotation = 0
                    }
                    MouseArea {
                        id: reloadArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.pk.reload()
                    }
                }
                // Close
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 10
                    color: closeArea.containsMouse ? Qt.alpha(Theme.red, 0.2) : Theme.mantle
                    border.width: 1
                    border.color: closeArea.containsMouse ? Qt.alpha(Theme.red, 0.5) : Theme.surface0
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.pk.hide()
                    }
                }
            }

            // ── Filters: source chips + reason switch ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Row {
                    spacing: 8
                    FilterChip {
                        label: "All"
                        dot: false
                        count: win.counts.all ?? 0
                        active: win.srcFilter === "all"
                        onClicked: win.srcFilter = "all"
                    }
                    Repeater {
                        model: win.presentSources
                        delegate: FilterChip {
                            required property string modelData
                            label: win.meta[modelData].label
                            accent: win.meta[modelData].color
                            count: win.counts[modelData] ?? 0
                            active: win.srcFilter === modelData
                            opacity: count === 0 && !active ? 0.45 : 1
                            onClicked: win.srcFilter = modelData
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Only packages that look unused (see isStale)
                FilterChip {
                    label: "Not used in 30+ days"
                    accent: Theme.peach
                    count: win.staleCount
                    active: win.staleOnly
                    onClicked: win.staleOnly = !win.staleOnly
                }

                Rectangle {
                    implicitWidth: reasonRow.implicitWidth + 6
                    implicitHeight: 36
                    radius: 10
                    color: Theme.surface0
                    Row {
                        id: reasonRow
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            model: [{ id: "all", label: "All" }, { id: "explicit", label: "Explicit" }, { id: "dep", label: "Dependencies" }]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool current: win.reasonFilter === modelData.id
                                implicitWidth: reasonLabel.implicitWidth + 22
                                implicitHeight: 30
                                radius: 8
                                color: current ? Theme.base : "transparent"
                                Text {
                                    id: reasonLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    color: parent.current ? Theme.text : Theme.overlay0
                                    font.family: Theme.uiFont
                                    font.pixelSize: 13
                                    font.weight: parent.current ? Font.DemiBold : Font.Normal
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.reasonFilter = parent.modelData.id
                                }
                            }
                        }
                    }
                }
            }

            // ── Table ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Theme.mantle
                border.width: 1
                border.color: Theme.surface0
                clip: true

                // Header (click a column to sort)
                Item {
                    id: header
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 40

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 24
                        spacing: 14

                        Repeater {
                            model: [
                                { key: "name", label: "Name", w: win.wName, right: false },
                                { key: "", label: "Version", w: win.wVersion, right: false },
                                { key: "source", label: "Source", w: win.wSource, right: false },
                                { key: "size", label: "Size", w: win.wSize, right: true },
                                { key: "reason", label: "Installed as", w: win.wReason, right: false },
                                { key: "last", label: "Last used", w: win.wLast, right: false },
                                { key: "", label: "Description", w: -1, right: false }
                            ]
                            delegate: Item {
                                required property var modelData
                                Layout.preferredWidth: modelData.w
                                Layout.fillWidth: modelData.w < 0
                                implicitHeight: 40
                                readonly property bool sortable: modelData.key !== ""
                                readonly property bool sorted: sortable && win.sortKey === modelData.key

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: modelData.right ? parent.right : undefined
                                    spacing: 6
                                    Text {
                                        text: modelData.label.toUpperCase()
                                        color: parent.parent.sorted ? Theme.blue : Theme.overlay0
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.6
                                    }
                                    Text {
                                        visible: parent.parent.sorted
                                        text: win.sortAsc ? "" : ""  // caret up / down
                                        color: Theme.blue
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: parent.sortable
                                    cursorShape: parent.sortable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: win.setSort(parent.modelData.key)
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.surface0
                    }
                }

                ListView {
                    id: list
                    anchors.top: header.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    anchors.rightMargin: 12
                    clip: true
                    spacing: 1
                    model: win.results
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    highlightResizeDuration: 0
                    cacheBuffer: 600

                    highlight: Rectangle {
                        radius: 9
                        color: Qt.alpha(Theme.blue, 0.13)
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height - 22
                            radius: 2
                            color: Theme.blue
                        }
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property var m: win.meta[modelData.source]
                        readonly property bool current: ListView.isCurrentItem
                        width: ListView.view.width
                        height: win.rowHeight

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 14

                            Text {
                                Layout.preferredWidth: win.wName
                                text: win.markup(row.modelData.name)
                                textFormat: Text.StyledText
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Text {
                                Layout.preferredWidth: win.wVersion
                                text: row.modelData.version
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Row {
                                Layout.preferredWidth: win.wSource
                                spacing: 8
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: badge.implicitWidth + 16
                                    implicitHeight: 22
                                    radius: 6
                                    color: Qt.alpha(row.m.color, 0.15)
                                    Text {
                                        id: badge
                                        anchors.centerIn: parent
                                        text: row.m.label
                                        color: row.m.color
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: row.modelData.repo !== ""
                                    text: row.modelData.repo
                                    color: Theme.overlay0
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                Layout.preferredWidth: win.wSize
                                horizontalAlignment: Text.AlignRight
                                text: win.fmtSize(row.modelData.size)
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                            Text {
                                Layout.preferredWidth: win.wReason
                                text: row.modelData.reason === "dep" ? "Dependency" : "Explicit"
                                color: row.modelData.reason === "dep" ? Theme.overlay0 : Theme.green
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                            Text {
                                Layout.preferredWidth: win.wLast
                                text: win.lastText(row.modelData)
                                color: win.lastColor(row.modelData)
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.desc
                                color: row.current ? Theme.subtext : Theme.overlay0
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: list.currentIndex = row.index
                            onClicked: win.copyName(row.modelData)
                        }
                    }

                    // Thin scroll indicator
                    Rectangle {
                        visible: list.contentHeight > list.height
                        x: list.width + 4
                        y: list.visibleArea.yPosition * list.height
                        width: 4
                        height: Math.max(24, list.visibleArea.heightRatio * list.height)
                        radius: 2
                        color: Theme.surface1
                    }
                }

                // Empty / loading state
                Column {
                    anchors.centerIn: parent
                    visible: win.results.length === 0
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.pk.loading > 0 ? "" : ""
                        color: Theme.surface1
                        font.family: Theme.fontFamily
                        font.pixelSize: 34
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.pk.loading > 0 ? "Loading packages…" : "No packages found"
                        color: Theme.overlay0
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                    }
                }
            }

            // ── Footer: totals, notice, key hints ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    text: win.results.length + " of " + win.pk.items.length + " packages · " + win.fmtSize(win.totalSize)
                    color: Theme.subtext
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
                Text {
                    visible: win.pk.loading > 0
                    text: "Loading " + win.pk.loading + " source" + (win.pk.loading === 1 ? "" : "s") + "…"
                    color: Theme.yellow
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
                Text {
                    text: win.notice
                    color: Theme.green
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 16
                    Repeater {
                        model: [["↑↓", "select"], ["Enter", "copy name"], ["Tab", "source"], ["Ctrl+R", "reload"], ["Esc", "clear / close"]]
                        delegate: Row {
                            required property var modelData
                            spacing: 6
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: keyText.implicitWidth + 12
                                implicitHeight: 20
                                radius: 5
                                color: Theme.surface0
                                border.width: 1
                                border.color: Theme.surface1
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: parent.parent.modelData[0]
                                    color: Theme.subtext
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[1]
                                color: Theme.overlay0
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
