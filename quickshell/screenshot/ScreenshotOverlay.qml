import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme

// Fullscreen frozen frame of one monitor with selection + annotation editing.
PanelWindow {
    id: win

    required property var modelData
    required property var tool

    readonly property string name: modelData.name
    readonly property bool hasSel: tool.selScreen === name && tool.sel !== null
    readonly property var sel: hasSel ? tool.sel : ({ x: 0, y: 0, w: 0, h: 0 })
    readonly property int handle: 10

    // Pointer interaction state
    property string drag: ""      // create | move | resize | draw
    property string grip: ""      // which handle when resizing: tl t tr r br b bl l
    property var origin: null     // press point
    property var origSel: null
    property var current: null    // shape being drawn

    // Hovered target in pick mode (screen / window), local coordinates
    // Computed from the polled global cursor position: hover events never reach this surface in Hyprland
    readonly property var hover: {
        if (tool.pick === "") return null;
        const lx = tool.cursor.x - modelData.x, ly = tool.cursor.y - modelData.y;
        if (lx < 0 || ly < 0 || lx >= width || ly >= height) return null;
        return tool.pick === "screen" ? { x: 0, y: 0, w: width, h: height } : windowAt(lx, ly);
    }

    // Text being typed
    property var textPos: null

    screen: modelData
    // Fail safe: any error here must hide the overlay, never leave it covering the screen.
    visible: tool?.active === true
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot"
    // Not Exclusive: Hyprland routes ALL pointer input to an exclusive layer, so the other monitor would be dead.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Component.onCompleted: keys.forceActiveFocus()
    onVisibleChanged: {
        drag = ""; current = null; textPos = null;
        if (visible) keys.forceActiveFocus();
    }

    // ── geometry helpers ──
    function rectFrom(x1, y1, x2, y2) {
        const cx = v => Math.max(0, Math.min(width, v));
        const cy = v => Math.max(0, Math.min(height, v));
        x1 = cx(x1); x2 = cx(x2); y1 = cy(y1); y2 = cy(y2);
        return { x: Math.min(x1, x2), y: Math.min(y1, y2), w: Math.abs(x2 - x1), h: Math.abs(y2 - y1) };
    }
    function hitTest(px, py) {
        if (!hasSel) return "outside";
        const s = sel, t = handle;
        const nearL = Math.abs(px - s.x) <= t, nearR = Math.abs(px - (s.x + s.w)) <= t;
        const nearT = Math.abs(py - s.y) <= t, nearB = Math.abs(py - (s.y + s.h)) <= t;
        const inX = px >= s.x - t && px <= s.x + s.w + t, inY = py >= s.y - t && py <= s.y + s.h + t;
        if (nearT && nearL) return "tl";
        if (nearT && nearR) return "tr";
        if (nearB && nearL) return "bl";
        if (nearB && nearR) return "br";
        if (nearT && inX) return "t";
        if (nearB && inX) return "b";
        if (nearL && inY) return "l";
        if (nearR && inY) return "r";
        if (px > s.x && px < s.x + s.w && py > s.y && py < s.y + s.h) return "inside";
        return "outside";
    }
    function cursorFor(hit) {
        if (tool.mode === "text" && hasSel) return Qt.IBeamCursor;
        if (tool.mode !== "select" && hasSel) return Qt.CrossCursor;
        switch (hit) {
            case "tl": case "br": return Qt.SizeFDiagCursor;
            case "tr": case "bl": return Qt.SizeBDiagCursor;
            case "t": case "b": return Qt.SizeVerCursor;
            case "l": case "r": return Qt.SizeHorCursor;
            case "inside": return Qt.SizeAllCursor;
        }
        return Qt.CrossCursor;
    }
    // Topmost window under a point (floating first, then most recently focused).
    function windowAt(px, py) {
        const gx = px + modelData.x, gy = py + modelData.y;
        const hits = tool.clients
            .filter(c => c.mapped && !c.hidden && tool.visibleWorkspaces.includes(c.workspace.id)
                && gx >= c.at[0] && gx < c.at[0] + c.size[0] && gy >= c.at[1] && gy < c.at[1] + c.size[1])
            .sort((a, b) => (b.floating - a.floating) || (a.focusHistoryID - b.focusHistoryID));
        if (hits.length === 0) return null;
        const c = hits[0];
        return rectFrom(c.at[0] - modelData.x, c.at[1] - modelData.y,
            c.at[0] + c.size[0] - modelData.x, c.at[1] + c.size[1] - modelData.y);
    }

    function keys_focus() { keys.forceActiveFocus(); }

    function claimSelection() {
        if (tool.selScreen !== name) {
            tool.annotations = [];
            tool.selScreen = name;
        }
        tool.focusScreen = name;
        keys.forceActiveFocus();
    }

    function commitText() {
        if (textPos && editor.text.trim() !== "")
            tool.addAnnotation({ type: "text", x: textPos.x, y: textPos.y, text: editor.text, color: String(tool.color), size: tool.size });
        textPos = null;
        editor.text = "";
        keys.forceActiveFocus();
    }

    // ── export ──
    Connections {
        target: win.tool
        function onExportRequested(screenName, path) {
            if (screenName !== win.name) return;
            const t = win.tool;
            // Physical pixels of the frozen frame, which grim captured at native resolution
            const kx = frame.sourceSize.width / win.width || 1, ky = frame.sourceSize.height / win.height || 1;
            const x = Math.round(win.sel.x * kx), y = Math.round(win.sel.y * ky);
            const geom = (Math.round((win.sel.x + win.sel.w) * kx) - x) + "x" + (Math.round((win.sel.y + win.sel.h) * ky) - y) + "+" + x + "+" + y;
            const src = t.shotPath(win.name);
            if (t.annotations.length === 0) {
                t.save(src, "", geom, path);
                return;
            }
            const ann = t.tmpDir + "/annotations-" + t.stamp + ".png";
            canvas.grabToImage(result => {
                if (result.saveToFile(ann)) t.save(src, ann, geom, path);
                else t.saveFailed(path);
            }, frame.sourceSize);
        }
        function onCommitTextRequested() { win.commitText(); }
        function onAnnotationsChanged() { canvas.requestPaint(); }
    }

    // ── frozen frame, dimmed ──
    Image {
        id: frame
        anchors.fill: parent
        source: win.tool.active ? "file://" + win.tool.shotPath(win.name) : ""
        fillMode: Image.Stretch
        smooth: true
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.hasSel ? 0.5 : 0.3
    }

    // ── selection: undimmed frame + annotations (preview only; saving crops the original frame) ──
    Item {
        id: crop
        visible: win.hasSel
        x: win.sel.x
        y: win.sel.y
        width: Math.max(1, win.sel.w)
        height: Math.max(1, win.sel.h)
        clip: true

        Image {
            x: -crop.x
            y: -crop.y
            width: win.width
            height: win.height
            source: frame.source
            smooth: true
        }
        Canvas {
            id: canvas
            x: -crop.x
            y: -crop.y
            width: win.width
            height: win.height

            function drawShape(ctx, a) {
                ctx.strokeStyle = a.color;
                ctx.fillStyle = a.color;
                ctx.lineWidth = a.size;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                if (a.type === "pen") {
                    ctx.beginPath();
                    ctx.moveTo(a.points[0].x, a.points[0].y);
                    for (const p of a.points) ctx.lineTo(p.x, p.y);
                    ctx.stroke();
                } else if (a.type === "rect") {
                    ctx.strokeRect(Math.min(a.x1, a.x2), Math.min(a.y1, a.y2), Math.abs(a.x2 - a.x1), Math.abs(a.y2 - a.y1));
                } else if (a.type === "arrow") {
                    const ang = Math.atan2(a.y2 - a.y1, a.x2 - a.x1);
                    const head = 10 + a.size * 3;
                    ctx.beginPath();
                    ctx.moveTo(a.x1, a.y1);
                    ctx.lineTo(a.x2, a.y2);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(a.x2, a.y2);
                    ctx.lineTo(a.x2 - head * Math.cos(ang - Math.PI / 7), a.y2 - head * Math.sin(ang - Math.PI / 7));
                    ctx.lineTo(a.x2 - head * Math.cos(ang + Math.PI / 7), a.y2 - head * Math.sin(ang + Math.PI / 7));
                    ctx.closePath();
                    ctx.fill();
                } else if (a.type === "text") {
                    ctx.font = "bold " + win.textPx(a.size) + "px '" + Theme.uiFont + "'";
                    ctx.textBaseline = "top";
                    ctx.fillText(a.text, a.x, a.y);
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (win.tool.selScreen !== win.name) return;
                for (const a of win.tool.annotations) drawShape(ctx, a);
                if (win.current) drawShape(ctx, win.current);
            }
        }
    }
    function textPx(size) { return 12 + size * 3; }

    // ── selection outline, handles, size label ──
    Rectangle {
        visible: win.hasSel
        x: win.sel.x - 1
        y: win.sel.y - 1
        width: win.sel.w + 2
        height: win.sel.h + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.blue
    }
    Repeater {
        model: win.hasSel && win.tool.mode === "select" && win.drag === ""
            ? [[0, 0], [0.5, 0], [1, 0], [1, 0.5], [1, 1], [0.5, 1], [0, 1], [0, 0.5]] : []
        delegate: Rectangle {
            required property var modelData
            width: 10
            height: 10
            radius: 5
            x: win.sel.x + win.sel.w * modelData[0] - width / 2
            y: win.sel.y + win.sel.h * modelData[1] - height / 2
            color: Theme.text
            border.width: 2
            border.color: Theme.blue
        }
    }
    Rectangle {
        visible: win.hasSel
        x: win.sel.x
        y: win.sel.y >= 28 ? win.sel.y - 26 : win.sel.y + 4
        width: sizeLabel.implicitWidth + 12
        height: 22
        radius: 6
        color: Qt.alpha(Theme.crust, 0.85)
        Text {
            id: sizeLabel
            anchors.centerIn: parent
            text: Math.round(win.sel.w) + " × " + Math.round(win.sel.h)
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }

    // ── hint before anything is selected ──
    Rectangle {
        visible: win.tool.pick !== "" ? win.tool.focusScreen === win.name
            : !win.tool.selScreen && win.tool.focusScreen === win.name
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 60
        width: hint.implicitWidth + 28
        height: 38
        radius: 19
        color: Qt.alpha(Theme.crust, 0.9)
        Text {
            id: hint
            anchors.centerIn: parent
            text: win.tool.pick === "screen" ? "Click a screen to capture it  ·  Esc to cancel"
                : win.tool.pick === "window" ? "Click a window to capture it  ·  Esc to cancel"
                : "Drag to select an area on any screen  ·  Click a window  ·  Esc to cancel"
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 14
        }
    }

    // ── pick mode: highlight of the screen / window under the cursor ──
    Rectangle {
        visible: win.tool.pick !== "" && win.hover !== null
        x: win.hover?.x ?? 0
        y: win.hover?.y ?? 0
        width: win.hover?.w ?? 0
        height: win.hover?.h ?? 0
        color: Qt.alpha(Theme.blue, 0.25)
        border.width: 3
        border.color: Theme.blue
    }

    // ── pointer ──
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: win.tool.pick !== "" ? Qt.PointingHandCursor : win.cursorFor(win.drag === "resize" ? win.grip : win.drag === "move" ? "inside" : win.hitTest(mouseX, mouseY))

        onPressed: m => {
            if (win.tool.pick !== "") {
                const h = win.hover;
                if (win.tool.pick === "screen") win.tool.grab("screen", win.name);
                else if (h) win.tool.grab("window", Math.round(h.x + win.modelData.x) + "," + Math.round(h.y + win.modelData.y) + " " + Math.round(h.w) + "x" + Math.round(h.h));
                return;
            }
            if (win.textPos) win.commitText();
            const p = { x: m.x, y: m.y };
            win.origin = p;

            // Drawing tools work inside an existing selection
            if (win.hasSel && win.tool.mode !== "select") {
                if (win.tool.mode === "text") {
                    win.textPos = p;
                    editor.text = "";
                    editor.forceActiveFocus();
                    return;
                }
                win.drag = "draw";
                const base = { type: win.tool.mode, color: String(win.tool.color), size: win.tool.size };
                win.current = win.tool.mode === "pen"
                    ? Object.assign(base, { points: [p] })
                    : Object.assign(base, { x1: p.x, y1: p.y, x2: p.x, y2: p.y });
                return;
            }

            const hit = win.hitTest(m.x, m.y);
            if (hit === "inside") {
                win.drag = "move";
                win.origSel = win.sel;
            } else if (hit !== "outside") {
                win.drag = "resize";
                win.grip = hit;
                win.origSel = win.sel;
            } else {
                win.claimSelection();
                win.drag = "create";
                win.tool.sel = { x: p.x, y: p.y, w: 0, h: 0 };
            }
        }

        onPositionChanged: m => {
            if (win.tool.pick !== "") return;
            if (win.drag === "") return;
            const o = win.origin;
            if (win.drag === "create") {
                win.tool.sel = win.rectFrom(o.x, o.y, m.x, m.y);
            } else if (win.drag === "move") {
                const s = win.origSel;
                const nx = Math.max(0, Math.min(win.width - s.w, s.x + m.x - o.x));
                const ny = Math.max(0, Math.min(win.height - s.h, s.y + m.y - o.y));
                win.tool.sel = { x: nx, y: ny, w: s.w, h: s.h };
            } else if (win.drag === "resize") {
                const s = win.origSel, g = win.grip;
                let x1 = s.x, y1 = s.y, x2 = s.x + s.w, y2 = s.y + s.h;
                if (g.includes("l")) x1 = m.x;
                if (g.includes("r")) x2 = m.x;
                if (g.includes("t")) y1 = m.y;
                if (g.includes("b")) y2 = m.y;
                win.tool.sel = win.rectFrom(x1, y1, x2, y2);
            } else if (win.drag === "draw" && win.current) {
                const c = win.current;
                if (c.type === "pen") c.points.push({ x: m.x, y: m.y });
                else { c.x2 = m.x; c.y2 = m.y; }
                canvas.requestPaint();
            }
        }

        onReleased: m => {
            const o = win.origin;
            const tiny = o && Math.abs(m.x - o.x) < 4 && Math.abs(m.y - o.y) < 4;
            if (win.drag === "create" && tiny) {
                // Click without dragging: take the window under the cursor
                const r = win.windowAt(m.x, m.y);
                if (r) win.tool.sel = r;
                else { win.tool.sel = null; win.tool.selScreen = ""; }
            } else if (win.drag === "draw" && win.current) {
                if (!tiny || win.current.type === "pen") win.tool.addAnnotation(win.current);
                win.current = null;
                canvas.requestPaint();
            }
            win.drag = "";
        }

        onDoubleClicked: if (win.hasSel && win.tool.mode === "select") win.tool.finish()
    }

    // ── text input placed on the image ──
    TextInput {
        id: editor
        visible: win.textPos !== null
        x: win.textPos?.x ?? 0
        y: win.textPos?.y ?? 0
        color: win.tool.color
        font.family: Theme.uiFont
        font.bold: true
        font.pixelSize: win.textPx(win.tool.size)
        cursorVisible: true
        onAccepted: win.commitText()
        Keys.onEscapePressed: { win.textPos = null; text = ""; keys.forceActiveFocus(); }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            z: -1
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.6)
            radius: 3
        }
    }

    // ── keyboard ──
    Item {
        id: keys
        focus: true
        Keys.onPressed: ev => {
            const t = win.tool;
            const ctrl = ev.modifiers & Qt.ControlModifier;
            if (ev.key === Qt.Key_Escape) t.cancel();
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || (ctrl && ev.key === Qt.Key_C) || (ctrl && ev.key === Qt.Key_S)) t.finish();
            else if (ctrl && ev.key === Qt.Key_Z) t.undo();
            else if (ev.key === Qt.Key_V || ev.key === Qt.Key_S) t.mode = "select";
            else if (ev.key === Qt.Key_P || ev.key === Qt.Key_D) t.mode = "pen";
            else if (ev.key === Qt.Key_A) t.mode = "arrow";
            else if (ev.key === Qt.Key_R) t.mode = "rect";
            else if (ev.key === Qt.Key_T) t.mode = "text";
            else return;
            ev.accepted = true;
        }
    }

    // ── toolbar ──
    Rectangle {
        id: toolbar
        visible: win.hasSel && win.drag !== "create" && win.drag !== "resize" && win.drag !== "move"
        readonly property int gap: 10
        width: bar.implicitWidth + 16
        height: 44
        radius: 12
        color: Theme.base
        border.width: 1
        border.color: Theme.surface1
        x: Math.max(8, Math.min(win.width - width - 8, win.sel.x + win.sel.w / 2 - width / 2))
        y: win.sel.y + win.sel.h + gap + height < win.height ? win.sel.y + win.sel.h + gap
            : win.sel.y - gap - height > 0 ? win.sel.y - gap - height
            : win.sel.y + win.sel.h - height - gap

        // Swallow clicks so they don't start a new selection
        MouseArea { anchors.fill: parent }

        RowLayout {
            id: bar
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: [
                    { id: "select", icon: "", tip: "Select / adjust (V)" },
                    { id: "pen", icon: "", tip: "Draw (P)" },
                    { id: "arrow", icon: "", tip: "Arrow (A)" },
                    { id: "rect", icon: "", tip: "Rectangle (R)" },
                    { id: "text", icon: "", tip: "Text (T)" }
                ]
                delegate: ToolButton {
                    required property var modelData
                    icon: modelData.icon
                    checked: win.tool.mode === modelData.id
                    onClicked: win.tool.mode = modelData.id
                }
            }

            Separator {}

            Repeater {
                model: win.tool.colors
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool current: Qt.colorEqual(win.tool.color, modelData)
                    width: 22
                    height: 22
                    radius: 11
                    color: "transparent"
                    border.width: current ? 2 : 0
                    border.color: Theme.text
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: parent.modelData
                        border.width: 1
                        border.color: Theme.surface1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.tool.color = parent.modelData
                    }
                }
            }

            Separator {}

            Repeater {
                model: win.tool.sizes
                delegate: ToolButton {
                    required property int modelData
                    checked: win.tool.size === modelData
                    onClicked: win.tool.size = modelData
                    Rectangle {
                        anchors.centerIn: parent
                        width: 4 + parent.modelData * 1.5
                        height: width
                        radius: width / 2
                        color: parent.checked ? Theme.crust : Theme.text
                    }
                }
            }

            Separator {}

            ToolButton {
                icon: ""
                enabled: win.tool.annotations.length > 0
                onClicked: win.tool.undo()
            }
            ToolButton {
                icon: ""
                onClicked: win.tool.cancel()
            }
            ToolButton {
                icon: ""
                accent: true
                onClicked: win.tool.finish()
            }
        }
    }

    component ToolButton: Rectangle {
        id: btn
        property string icon: ""
        property bool checked: false
        property bool accent: false
        signal clicked
        implicitWidth: 32
        implicitHeight: 32
        radius: 8
        opacity: enabled ? 1 : 0.35
        color: checked ? Theme.blue
            : accent ? (area.containsMouse ? Qt.lighter(Theme.green, 1.1) : Theme.green)
            : area.containsMouse ? Theme.surface0 : "transparent"
        Text {
            anchors.centerIn: parent
            visible: btn.icon !== ""
            text: btn.icon
            color: btn.checked || btn.accent ? Theme.crust : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component Separator: Rectangle {
        implicitWidth: 1
        implicitHeight: 22
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        color: Theme.surface1
    }
}
