import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    // ── geometry ──────────────────────────────────────────────────────────
    readonly property real ui: Math.max(0.75, Math.min(1.75, height / 1080))
    readonly property real cardHeight: Math.round(Math.min(height * 0.58, width * 0.54))
    readonly property real cardWidth: Math.round(cardHeight * 1.6)
    readonly property real cardRadius: Math.round(16 * ui)
    readonly property real step: Math.max(1, cardWidth * 0.68)
    readonly property int animDuration: 260

    // ── state ─────────────────────────────────────────────────────────────
    property int startPosition: 0
    property int wheelAccumulator: 0
    property string currentWallpaper: ""
    readonly property string currentWallpaperName: currentWallpaper.split("/").pop()

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperPath: configs.wallpaper_path.replace("$HOME", home)
    readonly property string cachePath: configs.cache_path.replace("$HOME", home)
    readonly property string wallpaperUrl: "file://" + wallpaperPath.replace(/\/+$/, "")
    readonly property string cachePrefix: cachePath.endsWith("/") ? cachePath : cachePath + "/"

    // The picker is launched as its own quickshell config (`qs -p`), so it
    // cannot import the main config's Theme singleton. Read the same matugen
    // palette directly, but keep the overlay's text light: the scrim is always
    // dark, even when the desktop theme is light.
    property var palette: ({})
    readonly property color themeAccent: palette.accent || "#e8e2d5"
    readonly property color uiAccent: {
        const c = themeAccent
        const luminance = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        return luminance > 0.45 ? c : (configs.border_color || "#e8e2d5")
    }
    readonly property color uiText: "#f5f2ec"
    readonly property color uiTextDim: "#c9c5bd"
    readonly property color uiTextFaint: "#8a8680"
    readonly property color uiBgCard: "#141414"
    readonly property string uiFont: "JetBrains Mono"

    function uiAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    implicitWidth: Screen.width
    implicitHeight: Screen.height
    color: "transparent"
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: {
        // Warm previews in the background. Existing thumbnails are reused, so
        // this normally does nothing more than a directory scan.
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh")])
        list.forceActiveFocus()
    }

    onCurrentWallpaperChanged: Qt.callLater(list.centerOnStart)

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
            property int cache_batch_size
            property int thumbnail_size
            property int thumbnail_quality
        }
    }

    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/43pr/quickshell-theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                main.palette = JSON.parse(text())
            } catch (e) {
                console.warn("hyprquickpaper: malformed quickshell-theme.json: " + e)
            }
        }
    }

    // The wallpaper currently drawn by awww, used to open the strip on the
    // image that is already active.
    Process {
        id: wallpaperQuery
        running: true
        command: ["bash", "-c", "awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: main.currentWallpaper = text.trim()
        }
    }

    FolderListModel {
        id: folderModel
        folder: main.wallpaperPath !== "" ? main.wallpaperUrl : ""
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        sortField: FolderListModel.Name
    }

    // ── backdrop ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#d9000000" }
            GradientStop { position: 0.32; color: "#66000000" }
            GradientStop { position: 0.70; color: "#59000000" }
            GradientStop { position: 1.0; color: "#e6000000" }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: Qt.quit()
        onWheel: function(wheel) { main.handleWheel(wheel) }
    }

    function handleWheel(wheel) {
        const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
        if (d === 0) return
        wheel.accepted = true
        main.wheelAccumulator += d
        if (Math.abs(main.wheelAccumulator) < 60) return
        list.navigate(main.wheelAccumulator > 0 ? -1 : 1)
        main.wheelAccumulator = 0
    }

    // ── foreground ────────────────────────────────────────────────────────
    Item {
        id: chrome
        anchors.fill: parent
        z: 1
        opacity: 0
        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }

        // header
        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 48 * main.ui
            anchors.topMargin: 38 * main.ui
            spacing: 13 * main.ui

            Rectangle {
                width: 4 * main.ui
                height: 27 * main.ui
                radius: 2 * main.ui
                color: uiAccent
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 3 * main.ui

                Text {
                    text: "WALLPAPERS"
                    color: uiText
                    font.family: uiFont
                    font.pixelSize: 14 * main.ui
                    font.bold: true
                    font.letterSpacing: 3.2 * main.ui
                }

                Text {
                    text: list.count + (list.count === 1 ? " IMAGE" : " IMAGES")
                    color: uiTextFaint
                    font.family: uiFont
                    font.pixelSize: 9 * main.ui
                    font.letterSpacing: 2 * main.ui
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 48 * main.ui
            anchors.topMargin: 42 * main.ui
            spacing: 20 * main.ui

            Hint { key: "← →"; label: "browse" }
            Hint { key: "ENTER"; label: "apply" }
            Hint { key: "ESC"; label: "close" }
        }

        // filmstrip
        ListView {
            id: list
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4 * main.ui
            height: main.cardHeight
            z: 1
            focus: true
            model: folderModel
            orientation: ListView.Horizontal
            interactive: false
            clip: true
            cacheBuffer: main.step * 3
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0

            property bool ready: false
            property bool userMoved: false
            property int selection: 0
            readonly property string currentName: count > 0 && selection >= 0
                                                  ? folderModel.get(selection, "fileName")
                                                  : ""

            leftMargin: 0
            rightMargin: 0

            // A horizontal ListView does not offset delegates by leftMargin,
            // so centre the strip with spacer items at both ends instead.
            header: Item {
                width: Math.max(0, (list.width - main.step) / 2)
                height: 1
            }

            footer: Item {
                width: Math.max(0, (list.width - main.step) / 2)
                height: 1
            }

            function navigate(delta) {
                if (count <= 0) return
                goTo(selection + delta, true)
            }

            function contentXFor(index) {
                // Screen centre = index * step - contentX + step / 2.
                // The header lets contentX go negative so the first card can
                // also sit exactly in the middle of the screen.
                return index * main.step - (list.width - main.step) / 2
            }

            function goTo(index, markMoved) {
                if (count <= 0) return
                if (markMoved !== false) userMoved = true
                selection = Math.max(0, Math.min(count - 1, index))
                contentX = contentXFor(selection)
            }

            function reflow() {
                if (count <= 0) return
                ready = false
                contentX = contentXFor(Math.max(0, Math.min(count - 1, selection)))
                Qt.callLater(function() { list.ready = true })
            }

            function centerOnStart() {
                if (userMoved || count <= 0) return

                let index = Math.max(0, Math.min(count - 1, main.startPosition))
                if (main.currentWallpaperName !== "") {
                    for (let i = 0; i < count; i++) {
                        if (folderModel.get(i, "fileName") === main.currentWallpaperName) {
                            index = i
                            break
                        }
                    }
                }

                selection = index
                ready = false
                contentX = contentXFor(selection)
                Qt.callLater(function() {
                    list.ready = true
                })
            }

            function applyIndex(index) {
                if (index < 0 || index >= count) return
                const path = folderModel.get(index, "filePath")
                if (!path) return
                Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path])
                Qt.quit()
            }

            function applyCurrent() {
                applyIndex(selection)
            }

            onCountChanged: {
                if (count <= 0) {
                    selection = 0
                    contentX = 0
                } else if (selection > count - 1) {
                    selection = count - 1
                    contentX = contentXFor(selection)
                }
                centerOnStart()
            }
            onWidthChanged: reflow()

            Behavior on contentX {
                enabled: list.ready
                NumberAnimation {
                    duration: main.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            delegate: Item {
                id: tile
                width: main.step
                height: main.cardHeight

                readonly property bool active: index === list.selection
                readonly property bool isCurrent: main.currentWallpaper !== ""
                                                  && (filePath === main.currentWallpaper
                                                      || fileName === main.currentWallpaperName)
                readonly property real slotCenter: x - list.contentX + width / 2
                readonly property real distance: Math.abs(slotCenter - list.width / 2)
                readonly property real norm: Math.min(1, distance / (main.cardWidth * 0.95))
                readonly property real eased: norm * norm * (3 - 2 * norm)
                readonly property real scaleFactor: 1 - 0.38 * eased
                readonly property real opacityFactor: 0.45 + 0.55 * (1 - eased)
                readonly property string thumbUrl: "file://" + main.cachePrefix + fileName + ".thumb.jpg"
                readonly property string originalUrl: "file://" + filePath

                z: active ? 1000 : Math.max(1, 1000 - Math.round(distance))
                property bool fallback: false
                property bool hovered: false

                Item {
                    id: card
                    width: main.cardWidth
                    height: main.cardHeight
                    anchors.centerIn: parent
                    scale: tile.scaleFactor
                    opacity: tile.opacityFactor
                    transformOrigin: Item.Center

                    // Rounded mask, kept outside the layered item so it is
                    // not composited into the preview itself.
                    Rectangle {
                        id: mask
                        anchors.fill: parent
                        radius: main.cardRadius
                        color: "white"
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        id: visual
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: mask
                            // Only the focused card and its neighbours need a
                            // shadow; skipping it on distant cards saves GPU.
                            shadowEnabled: tile.distance < main.cardWidth * 0.9
                            shadowColor: "#000000"
                            shadowOpacity: 0.55
                            shadowBlur: 0.55
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 16 * main.ui
                            shadowScale: 1.01
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: main.cardRadius
                            color: uiBgCard
                        }

                        Image {
                            id: preview
                            anchors.fill: parent
                            source: tile.fallback ? tile.originalUrl : tile.thumbUrl
                            sourceSize.width: Math.ceil(main.cardWidth)
                            sourceSize.height: Math.ceil(main.cardHeight)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            // A thumbnail may not exist yet (new image, first
                            // open after login). Fall back to the original,
                            // decoded at preview size, instead of showing a
                            // "Caching" state.
                            onStatusChanged: {
                                if (status === Image.Error && !tile.fallback)
                                    tile.fallback = true
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: preview.status !== Image.Ready
                            text: preview.status === Image.Error && tile.fallback
                                  ? "NO PREVIEW"
                                  : "LOADING"
                            color: uiTextFaint
                            font.family: uiFont
                            font.pixelSize: 11 * main.ui
                            font.bold: true
                            font.letterSpacing: 2 * main.ui
                        }
                    }

                    // selection border
                    Rectangle {
                        anchors.fill: parent
                        radius: main.cardRadius
                        color: "transparent"
                        border.width: tile.active ? Math.max(2, Math.round(3 * main.ui))
                                                  : Math.max(1, Math.round(1 * main.ui))
                        border.color: tile.active ? uiAccent
                                                  : (tile.hovered ? Qt.rgba(1, 1, 1, 0.45)
                                                                  : Qt.rgba(1, 1, 1, 0.20))
                        Behavior on border.color {
                            ColorAnimation { duration: 160 }
                        }
                    }

                    // which image is currently on the desktop
                    Rectangle {
                        visible: tile.isCurrent
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 16 * main.ui
                        anchors.bottomMargin: 16 * main.ui
                        width: currentLabel.implicitWidth + 18 * main.ui
                        height: 24 * main.ui
                        radius: height / 2
                        color: Qt.rgba(0, 0, 0, 0.55)
                        border.width: 1
                        border.color: uiAlpha(uiAccent, 0.5)

                        Text {
                            id: currentLabel
                            anchors.centerIn: parent
                            text: "CURRENT"
                            color: uiAccent
                            font.family: uiFont
                            font.pixelSize: 8 * main.ui
                            font.bold: true
                            font.letterSpacing: 1.6 * main.ui
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: tile.hovered = true
                        onExited: tile.hovered = false
                        onClicked: list.applyIndex(index)
                        onWheel: function(wheel) { main.handleWheel(wheel) }
                    }
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left) {
                    list.navigate(-1)
                } else if (event.key === Qt.Key_Right) {
                    list.navigate(1)
                } else if (event.key === Qt.Key_Home) {
                    list.goTo(0)
                } else if (event.key === Qt.Key_End) {
                    list.goTo(list.count - 1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                           || event.key === Qt.Key_Space) {
                    list.applyCurrent()
                } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_W
                           || event.key === Qt.Key_Q) {
                    Qt.quit()
                } else {
                    return
                }
                event.accepted = true
            }
        }

        // filename + position
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40 * main.ui
            spacing: 6 * main.ui

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, main.width * 0.68)
                text: list.currentName
                color: uiText
                font.family: uiFont
                font.pixelSize: 15 * main.ui
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: list.count > 0
                      ? (list.selection + 1) + " / " + list.count
                      : ""
                color: uiTextFaint
                font.family: uiFont
                font.pixelSize: 10 * main.ui
                font.letterSpacing: 1.5 * main.ui
            }
        }

        // empty state
        Column {
            anchors.centerIn: parent
            spacing: 11 * main.ui
            visible: list.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: folderModel.status === FolderListModel.Loading
                      ? "Scanning wallpapers…"
                      : "No wallpapers found"
                color: uiText
                font.family: uiFont
                font.pixelSize: 22 * main.ui
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: folderModel.status !== FolderListModel.Loading
                text: "Add images to:"
                color: uiTextDim
                font.family: uiFont
                font.pixelSize: 12 * main.ui
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: folderModel.status !== FolderListModel.Loading
                width: Math.min(implicitWidth, main.width * 0.8)
                text: main.wallpaperPath
                color: uiAccent
                font.family: uiFont
                font.pixelSize: 13 * main.ui
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: folderModel.status !== FolderListModel.Loading
                text: "PNG  ·  JPG  ·  JPEG  ·  WEBP"
                color: uiTextFaint
                font.family: uiFont
                font.pixelSize: 9 * main.ui
                font.letterSpacing: 2 * main.ui
            }
        }
    }

    component Hint: Row {
        id: hint
        property string key
        property string label
        spacing: 7 * main.ui

        Rectangle {
            width: keyLabel.implicitWidth + 14 * main.ui
            height: 22 * main.ui
            radius: 5 * main.ui
            color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: keyLabel
                anchors.centerIn: parent
                text: hint.key
                color: uiTextDim
                font.family: uiFont
                font.pixelSize: 9 * main.ui
                font.bold: true
                font.letterSpacing: 1.2 * main.ui
            }
        }

        Text {
            text: hint.label
            color: uiTextFaint
            font.family: uiFont
            font.pixelSize: 10 * main.ui
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
