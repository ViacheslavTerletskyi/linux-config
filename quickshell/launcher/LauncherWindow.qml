import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme

// Launcher window: created by Launcher.qml when opened, destroyed when closed.
PanelWindow {
    id: win

    required property var launcher
    readonly property string mode: launcher.mode   // "apps" | "clipboard"
    property bool shown: false                     // drives the open animation
    property var clipLines: []

    readonly property int rowHeight: 56
    // Decoded clipboard images for previews (decoded once per entry).
    readonly property string thumbDir: Quickshell.cachePath("clipboard-thumbs")
    property int thumbsRev: 0
    readonly property int maxRows: 7
    readonly property string query: input.text.trim().toLowerCase()

    readonly property var results: {
        const q = query;
        if (mode === "clipboard")
            return clipLines.filter(l => q === "" || l.toLowerCase().includes(q)).slice(0, 50)
                .map(l => {
                    const text = l.split("\t").slice(1).join("\t");
                    const isImage = text.startsWith("[[ binary data");
                    const id = l.split("\t")[0];
                    return { kind: "clip", line: l, image: isImage, thumb: isImage ? thumbDir + "/" + id + ".png" : "",
                        title: isImage ? "Image" : text, subtitle: isImage ? imageInfo(text) : "", icon: "" };
                });

        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const scored = [];
        for (const e of apps) {
            const s = score(q, e);
            if (s > 0) scored.push({ s: s, e: e });
        }
        scored.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));
        return scored.slice(0, 50).map(x => ({ kind: "app", entry: x.e, title: x.e.name, subtitle: x.e.comment || x.e.genericName, icon: x.e.icon }));
    }

    // "[[ binary data 1 MiB png 1920x1080 ]]" → "1920 × 1080 · PNG · 1 MiB"
    function imageInfo(text) {
        const m = text.match(/binary data (.+?) (\w+) (\d+)x(\d+)/);
        return m ? m[3] + " × " + m[4] + " · " + m[2].toUpperCase() + " · " + m[1] : text;
    }

    function score(q, e) {
        if (q === "") return 1;
        const name = e.name.toLowerCase();
        if (name.startsWith(q)) return 100;
        if (name.split(/\s+/).some(w => w.startsWith(q))) return 80;
        if (name.includes(q)) return 60;
        const extra = (e.genericName + " " + e.keywords + " " + e.id).toLowerCase();
        if (extra.includes(q)) return 40;
        // subsequence match: "ffx" -> "firefox"
        let i = 0;
        for (const c of name) if (c === q[i]) i++;
        return i === q.length ? 20 : 0;
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    // Title with the matched part highlighted.
    function markup(title) {
        const q = query;
        const i = q === "" ? -1 : title.toLowerCase().indexOf(q);
        if (i < 0) return escapeHtml(title);
        return escapeHtml(title.slice(0, i))
            + "<font color='" + Theme.blue + "'><b>" + escapeHtml(title.slice(i, i + q.length)) + "</b></font>"
            + escapeHtml(title.slice(i + q.length));
    }

    function reset() {
        input.text = "";
        list.currentIndex = 0;
        if (mode === "clipboard") clipProc.running = true;
        input.forceActiveFocus();
    }
    Component.onCompleted: { reset(); shown = true; }
    onModeChanged: reset()

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: true
    // Top edge stays put while the result count changes.
    anchors.top: true
    margins.top: Math.round((screen?.height ?? 1080) * 0.2)
    exclusiveZone: 0
    implicitWidth: 620
    implicitHeight: card.implicitHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        windows: [win]
        active: true
        onCleared: win.launcher.hide()
    }

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.clipLines = text.split("\n").filter(l => l !== "");
                const ids = win.clipLines.filter(l => l.split("\t")[1]?.startsWith("[[ binary data")).map(l => l.split("\t")[0]);
                if (ids.length > 0) {
                    thumbProc.command = ["sh", "-c",
                        'dir=$1; shift; mkdir -p "$dir"; for id; do [ -s "$dir/$id.png" ] || cliphist decode "$id" > "$dir/$id.png"; done',
                        "sh", win.thumbDir, ...ids];
                    thumbProc.running = true;
                }
            }
        }
    }
    Process {
        id: thumbProc
        onExited: win.thumbsRev++
    }
    // Wipes cliphist history, the current selection and cached previews.
    Process {
        id: wipeProc
        command: ["sh", "-c", 'cliphist wipe; wl-copy --clear; rm -rf "$1"', "sh", win.thumbDir]
        onExited: { win.clipLines = []; list.currentIndex = 0; }
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 28
        radius: 16
        color: Theme.base
        border.width: 1
        border.color: Theme.surface0

        // Open animation
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 12

            // ── Search field ──
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 12
                color: Theme.mantle
                border.width: 1
                border.color: input.activeFocus ? Qt.alpha(Theme.blue, 0.5) : Theme.surface0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 12

                    Text {
                        text: win.mode === "apps" ? "" : ""
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                    }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        color: Theme.text
                        selectionColor: Qt.alpha(Theme.blue, 0.4)
                        font.family: Theme.uiFont
                        font.pixelSize: 17
                        clip: true
                        onTextChanged: list.currentIndex = 0

                        Text {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.mode === "apps" ? "Search apps…" : "Search clipboard…"
                            color: Theme.overlay0
                            font: input.font
                        }

                        Keys.onPressed: ev => {
                            if (ev.key === Qt.Key_Escape) { win.launcher.hide(); ev.accepted = true; }
                            else if (ev.key === Qt.Key_Down || (ev.key === Qt.Key_J && ev.modifiers & Qt.ControlModifier)) { list.incrementCurrentIndex(); ev.accepted = true; }
                            else if (ev.key === Qt.Key_Up || (ev.key === Qt.Key_K && ev.modifiers & Qt.ControlModifier)) { list.decrementCurrentIndex(); ev.accepted = true; }
                            else if (ev.key === Qt.Key_Tab) { win.launcher.show(win.mode === "apps" ? "clipboard" : "apps"); ev.accepted = true; }
                            // Del clears history; it still deletes text while there is any after the cursor.
                            else if (ev.key === Qt.Key_Delete && clearBtn.visible && input.cursorPosition === input.text.length) { wipeProc.running = true; ev.accepted = true; }
                            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { win.launcher.pick(win.results[list.currentIndex]); ev.accepted = true; }
                        }
                    }

                    // Clear clipboard history.
                    Rectangle {
                        id: clearBtn
                        visible: win.mode === "clipboard" && win.clipLines.length > 0
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 9
                        color: clearMouse.containsMouse ? Theme.surface1 : Theme.surface0
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf1f8"  // trash
                            color: clearMouse.containsMouse ? Theme.red : Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { wipeProc.running = true; input.forceActiveFocus(); }
                        }
                    }

                    // Mode switch
                    Rectangle {
                        implicitWidth: tabs.implicitWidth + 6
                        implicitHeight: 34
                        radius: 9
                        color: Theme.surface0

                        Row {
                            id: tabs
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: [{ id: "apps", label: "Apps" }, { id: "clipboard", label: "Clipboard" }]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool current: win.mode === modelData.id
                                    implicitWidth: tabLabel.implicitWidth + 20
                                    implicitHeight: 28
                                    radius: 7
                                    color: current ? Theme.base : "transparent"
                                    Text {
                                        id: tabLabel
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
                                        onClicked: if (!parent.current) win.launcher.show(parent.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Results ──
            ListView {
                id: list
                Layout.fillWidth: true
                implicitHeight: Math.max(1, Math.min(count, win.maxRows)) * (win.rowHeight + spacing) - spacing
                visible: count > 0
                clip: true
                spacing: 2
                model: win.results
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 90
                highlightResizeDuration: 0

                highlight: Rectangle {
                    radius: 10
                    color: Qt.alpha(Theme.blue, 0.13)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 24
                        radius: 2
                        color: Theme.blue
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: ListView.view.width
                    height: win.rowHeight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 14

                        // App icon, image preview, or a glyph tile for text entries
                        Item {
                            Layout.preferredWidth: row.modelData.image ? 64 : 34
                            Layout.preferredHeight: row.modelData.image ? 42 : 34
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 34
                                visible: row.modelData.kind === "app"
                                source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                            }
                            ClippingRectangle {
                                anchors.fill: parent
                                visible: row.modelData.kind === "clip"
                                radius: 7
                                color: Theme.surface0
                                border.width: preview.status === Image.Ready ? 1 : 0
                                border.color: Theme.surface1
                                Image {
                                    id: preview
                                    anchors.fill: parent
                                    visible: status === Image.Ready
                                    // ?rev re-reads the file once the decoder has written it
                                    source: row.modelData.thumb && win.thumbsRev > 0 ? "file://" + row.modelData.thumb + "?" + win.thumbsRev : ""
                                    sourceSize.width: 128
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: preview.status !== Image.Ready
                                    text: row.modelData.image ? "\uf03e" : "\uf15c"
                                    color: Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: win.markup(row.modelData.title)
                                textFormat: Text.StyledText
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 15
                                font.weight: row.current ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.subtitle ?? ""
                                color: row.current ? Theme.subtext : Theme.overlay0
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        Text {
                            visible: row.current
                            text: "\udb80\udf11"  // keyboard-return
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // hover moves the selection, so there is only ever one highlighted row
                        onPositionChanged: list.currentIndex = row.index
                        onClicked: win.launcher.pick(row.modelData)
                    }
                }
            }

            // ── Empty state ──
            Column {
                Layout.fillWidth: true
                Layout.topMargin: 18
                Layout.bottomMargin: 18
                visible: list.count === 0
                spacing: 6
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: win.mode === "apps" ? "\uf002" : "\uf0ea"
                    color: Theme.surface1
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: win.mode === "apps" ? "No apps found" : (win.clipLines.length === 0 ? "Clipboard history is empty" : "Nothing matches")
                    color: Theme.overlay0
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                }
            }

            // ── Key hints ──
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                Repeater {
                    model: win.mode === "clipboard" && win.clipLines.length > 0
                        ? [["↑↓", "select"], ["Enter", "paste"], ["Del", "clear"], ["Tab", "switch"], ["Esc", "close"]]
                        : [["↑↓", "select"], ["Enter", "open"], ["Tab", "switch"], ["Esc", "close"]]
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
