// KeybindsWindow: a small macOS-style sheet that lets the user view and search every
// Hyprland keybind (hyprctl binds -j). Opened from the Menu Bar → Help tab → "Hyprland
// Keybinds". There is intentionally no keybind for it — it's a click-opened panel.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // input only where the sheet's backdrop is, so the window being mapped (for the
    // fade-out animation) never eats clicks across the screen while closed
    mask: Region { item: root.showing ? backdrop : null }

    WlrLayershell.namespace: "mackeybinds"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // look & feel, wired to MacBar's settings
    property bool darkMode: true
    property string fam: "Inter"
    property color accentColor: "#0A84FF"

    property bool showing: false

    function open() {
        query = "";
        showing = true;
        kbBindProbe.running = true;          // fresh every open: binds may have changed
        kbLuaProbe.running = true;           // keybinds.lua supplies the human labels
        searchInput.forceActiveFocus();
    }
    function close() { showing = false; }

    // ───────────────────────── data ─────────────────────────

    // Hyprland's lua config (hyprland.lua) registers binds with the internal
    // dispatcher "__lua" and a callback id as arg — hyprctl tells us nothing
    // human for them (has_description false). keybinds.lua is the actual source:
    // every line is `hl.bind(MODS .. " + KEY", hl.dsp.…(...))` usually ending
    // with a `-- what it does` comment. Parse it and join on (mods, key).
    property var luaMap: ({})
    property var raw: []                     // final display list (hyprctl binds joined with keybinds.lua)

    Process {
        id: kbLuaProbe
        // hyprland.lua first: it defines the globals (mainMod, terminal…) used
        // by keybinds.lua's combos
        command: ["sh", "-c", "cat \"$HOME/.config/hypr/hyprland.lua\" \"$HOME/.config/hypr/keybinds.lua\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: { root.luaMap = root.parseLuaMap(text); root.commit(); }
        }
    }

    property var parsedEntries: []

    Process {
        id: kbBindProbe
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parsedEntries = root.parseBindsJson(text);
                root.commit();
            }
        }
    }

    // whatever finished second wins, so both orders work and it's idempotent
    function commit() {
        var out = [];
        var ent = parsedEntries || [];
        for (var i = 0; i < ent.length; i++) {
            var b = ent[i];
            var hit = luaMap[canonMask(b.mask) + "\u0000" + b.key.toUpperCase()];
            if (hit !== undefined) {
                if (hit.desc !== "") b.desc = hit.desc;
                b.disp = hit.handler;          // replaces the "__lua" dispatcher for search
            }
            out.push(b);
        }
        out.sort(function (x, y) {
            if (x.submap !== y.submap) return x.submap < y.submap ? -1 : 1;
            if (x.mask !== y.mask) return x.mask - y.mask;
            return x.key.localeCompare(y.key);
        });
        raw = out;
    }

    function parseBindsJson(text) {
        var out = [];
        try {
            var list = JSON.parse(text);
            for (var i = 0; i < list.length; i++) {
                var b = list[i];
                if (!b || !b.key) continue;
                var disp = String(b.dispatcher || "").trim();
                out.push({
                    submap: String(b.submap || "").trim(),
                    key: String(b.key || "").trim(),
                    mask: b.modmask || 0,
                    mods: modText(b.modmask || 0),
                    desc: String(b.description || "").trim(),
                    disp: disp,
                    arg: String(b.arg || "").trim()
                });
            }
        } catch (e) { }
        return out;
    }

    // map key: canonical mods joined with "+" then \u0000 then the KEY in caps
    function parseLuaMap(text) {
        var map = {};
        var vars = {};
        var lines = String(text).split("\n");
        for (var i = 0; i < lines.length; i++) {
            var L = lines[i];
            // collect `name = "value"` (local or global — mainMod lives in hyprland.lua)
            var vm = /^(?:local\s+)?([A-Za-z_]\w*)\s*=\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/.exec(L);
            if (vm) { vars[vm[1]] = vm[2].slice(1, -1); continue; }
            var bs = L.indexOf("hl.bind(");
            if (bs < 0) continue;
            bs += 8;
            // combo end: first top-level comma (skipping quotes, (), {}, [])
            var depth = 1, inSq = false, inDq = false, esc = false, j;
            for (j = bs; j < L.length; j++) {
                var ch = L.charAt(j);
                if (esc) { esc = false; continue; }
                if (ch === "\\") { esc = true; continue; }
                if (inDq) { if (ch === '"') inDq = false; continue; }
                if (inSq) { if (ch === "'") inSq = false; continue; }
                if (ch === '"') inDq = true;
                else if (ch === "'") inSq = true;
                else if (ch === "(" || ch === "{" || ch === "[") depth++;
                else if (ch === ")" || ch === "}" || ch === "]") { depth--; if (depth === 0) break; }
                else if (ch === "," && depth === 1) break;
            }
            var combo = resolveExpr(L.slice(bs, j), vars);
            // handler end: the token that closes hl.bind itself
            var depth2 = 1, inSq2 = false, inDq2 = false, esc2 = false, k;
            for (k = j + 1; k < L.length; k++) {
                var c2 = L.charAt(k);
                if (esc2) { esc2 = false; continue; }
                if (c2 === "\\") { esc2 = true; continue; }
                if (inDq2) { if (c2 === '"') inDq2 = false; continue; }
                if (inSq2) { if (c2 === "'") inSq2 = false; continue; }
                if (c2 === '"') inDq2 = true;
                else if (c2 === "'") inSq2 = true;
                else if (c2 === "(" || c2 === "{" || c2 === "[") depth2++;
                else if (c2 === ")" || c2 === "}" || c2 === "]") { depth2--; if (depth2 === 0) break; }
            }
            var handler = L.slice(j + 1, k).trim().replace(/hl\.dsp\./g, "").replace(/hl\./g, "");
            var cm = L.slice(k + 1).match(/--\s*(.*)$/);
            var comboParts = combo.split("+");
            var keyPart = (comboParts[comboParts.length - 1] || "").trim();
            var modsKey = canonList(comboParts.slice(0, comboParts.length - 1));
            if (keyPart !== "")
                map[modsKey + "\u0000" + keyPart.toUpperCase()] = { handler: handler, desc: cm ? cm[1].trim() : "" };
        }
        return map;
    }

    // `mainMod .. " + T"` → "SUPER + T": split on ".." , take string literals
    // as literals, resolve identifiers through the local var table
    function resolveExpr(expr, vars) {
        var pieces = String(expr).split("..");
        var acc = "";
        for (var i = 0; i < pieces.length; i++) {
            var p = pieces[i].trim();
            if (p === "") continue;
            if ((p.charAt(0) === '"' && p.charAt(p.length - 1) === '"') ||
                (p.charAt(0) === "'" && p.charAt(p.length - 1) === "'")) {
                acc += p.slice(1, -1);
                continue;
            }
            acc += (vars[p] !== undefined ? vars[p] : p);
        }
        return acc;
    }

    // canonical mods string for lookup: same order + same names from both sources
    function canonList(tokens) {
        var want = ["CTRL", "SHIFT", "ALT", "SUPER"];
        var have = {};
        for (var i = 0; i < tokens.length; i++) {
            var t = String(tokens[i]).trim().toUpperCase();
            if (t === "LOGO" || t === "META" || t === "M" || t === "MAINMOD") t = "SUPER";
            if (want.indexOf(t) >= 0) have[t] = true;
        }
        var out = [];
        for (var j = 0; j < want.length; j++) if (have[want[j]]) out.push(want[j]);
        return out.join("+");
    }

    function canonMask(m) {
        return canonList([(m & 4) ? "CTRL" : "", (m & 1) ? "SHIFT" : "", (m & 8) ? "ALT" : "", (m & 64) ? "SUPER" : ""]);
    }

    // Hyprland modmask bits → readable names (super — the logo key — is the 64 bit)
    function modText(m) {
        var out = [];
        if (m & 1) out.push("SHIFT");
        if (m & 4) out.push("CTRL");
        if (m & 8) out.push("ALT");
        if (m & 64) out.push("SUPER");
        if (m & 128) out.push("MOD5");
        return out.join(" + ");
    }

    // what a row (and the search) treats as text
    function labelOf(b) {
        if (b.desc) return b.desc;
        if (b.disp === "__lua") return "(registered in hyprland.lua)";
        return (b.disp + (b.arg ? "  " + b.arg : "")) || "(no action)";
    }
    function haystackOf(b) {
        return (labelOf(b) + " " + b.mods + " " + b.key + " " + b.disp + " " + b.arg + " " + b.submap).toLowerCase();
    }

    property string query: ""
    readonly property var rows: {
        var q = query.trim().toLowerCase();
        if (q === "") return raw;
        var out = [];
        for (var i = 0; i < raw.length; i++) if (haystackOf(raw[i]).indexOf(q) >= 0) out.push(raw[i]);
        return out;
    }

    // ───────────────────────── visuals ─────────────────────────
    readonly property string fgStrong: darkMode ? "#F5F5F7" : "#1D1D1F"
    readonly property string fgDim: darkMode ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
    readonly property string cardBg: darkMode ? Qt.rgba(0.075, 0.075, 0.082, 0.97) : Qt.rgba(0.985, 0.985, 0.99, 0.97)
    readonly property string rowHover: darkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property string chipBg: darkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
    readonly property string fieldBg: darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property string hairline: darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)

    // dim the session while the sheet is open
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
        opacity: root.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }   // click outside → close
    }

    Rectangle {
        id: card
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(780, parent.width - 120)
        height: Math.min(560, parent.height - 120)
        radius: 14
        color: root.cardBg
        border.width: 1
        border.color: root.hairline
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Shortcut { sequence: "Escape"; enabled: root.showing; onActivated: root.close() }

        // ── header: title + count, and a macOS "Done" button
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 54

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: "Keyboard Shortcuts"
                    color: root.fgStrong
                    font.family: root.fam
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.rows.length === root.raw.length
                        ? root.raw.length + " shortcuts"
                        : root.rows.length + " of " + root.raw.length + " shortcuts"
                    color: root.fgDim
                    font.family: root.fam
                    font.pixelSize: 12
                }
            }

            Rectangle {
                id: doneBtn
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 26
                radius: 7
                color: doneHover.containsMouse || doneHover.pressed
                    ? (root.darkMode ? "#3A3A3E" : "#E4E4E8")
                    : (root.darkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
                Text {
                    anchors.centerIn: parent
                    text: "Done"
                    color: root.fgStrong
                    font.family: root.fam
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: doneHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.hairline
        }

        // ── search field
        Rectangle {
            id: searchBox
            anchors.top: parent.top
            anchors.topMargin: 66
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            height: 34
            radius: 9
            color: root.fieldBg
            border.width: searchInput.activeFocus ? 1 : 0
            border.color: root.accentColor

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "\uD83D\uDD0D"
                font.pixelSize: 13
                opacity: 0.6
            }

            TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                color: root.fgStrong
                font.family: root.fam
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onTextChanged: root.query = text
                onAccepted: root.close()

                Text {
                    anchors.fill: parent
                    visible: searchInput.text === "" && !searchInput.activeFocus
                    text: "Search shortcuts"
                    color: root.fgDim
                    font.family: root.fam
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                visible: searchInput.text !== ""
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2715"
                color: root.fgDim
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                }
            }
        }

        // ── list
        Flickable {
            id: list
            anchors.top: searchBox.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: listColumn.implicitHeight + 8
            boundsBehavior: Flickable.StopAtBounds

            MouseArea {                                  // wheel scrolling, no scrollbars
                anchors.fill: parent
                onWheel: function (wheel) {
                    if (wheel.angleDelta.y === 0) return;
                    var max = Math.max(0, list.contentHeight - list.height);
                    list.contentY = Math.max(0, Math.min(max, list.contentY - wheel.angleDelta.y));
                    wheel.accepted = true;
                }
            }

            Column {
                id: listColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 0

                Text {
                    visible: root.raw.length === 0
                    text: "Reading binds with hyprctl…"
                    color: root.fgDim
                    font.family: root.fam
                    font.pixelSize: 12
                    topPadding: 48
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }

                Text {
                    visible: root.raw.length > 0 && root.rows.length === 0
                    text: "No shortcuts match \u201C" + root.query + "\u201D"
                    color: root.fgDim
                    font.family: root.fam
                    font.pixelSize: 12
                    topPadding: 48
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }

                Repeater {
                    model: root.rows

                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: listColumn.width

                        // section header whenever the submap group changes
                        Text {
                            visible: index === 0 || root.rows[index - 1].submap !== modelData.submap
                            text: modelData.submap === "" ? "GLOBAL" : modelData.submap.toUpperCase()
                            color: root.accentColor
                            font.family: root.fam
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            font.weight: Font.DemiBold
                            leftPadding: 10
                            topPadding: index === 0 ? 4 : 14
                            bottomPadding: 4
                        }

                        Rectangle {
                            width: parent.width
                            height: 42
                            radius: 8
                            color: rowHover.containsMouse ? root.rowHover : "transparent"

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: keyChip.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.labelOf(modelData)
                                color: root.fgStrong
                                font.family: root.fam
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: keyChip
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: keyText.implicitWidth + 20
                                height: 24
                                radius: 6
                                color: root.chipBg

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: (modelData.mods ? modelData.mods + "  +  " : "") + modelData.key
                                    color: root.fgStrong
                                    font.family: root.fam
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 10 }
            }
        }
    }
}
