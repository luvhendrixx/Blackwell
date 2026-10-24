import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"

// Profile page: lets the user set the picture that shows above their name on the
// MacLock lock screen. The cropped square is saved to ~/.face (and mirrored to
// ~/.face.icon and the AccountsService icon when possible); MacLock watches that
// file and re-applies it live — the very next lock shows the new avatar, no
// logout or restart needed.
Item {
    id: page

    property int rightMargin: 46

    property string home: Quickshell.env("HOME")
    readonly property string facePath: home + "/.face"
    property bool hasFace: false
    property string userName: Quickshell.env("USER") || "user"

    property string pickedSource: ""        // file url of the picture being cropped
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property real baseScale: 0              // cover-fit scale at zoom 1 (most zoomed-out)
    property string statusText: ""
    property int bump: 0                    // cache-buster for the avatar preview

    readonly property int vsize: 280        // preview/crop circle diameter
    property real viewSize: vsize           // temporarily jumps to 512 while saving
    readonly property int outSize: 512      // saved avatar resolution

    // does ~/.face exist?
    Process {
        id: faceProbe
        command: ["sh", "-c", "if [ -f \"$HOME/.face\" ]; then echo yes; else echo no; fi"]
        stdout: StdioCollector {
            onStreamFinished: page.hasFace = (text.trim() === "yes")
        }
    }
    Component.onCompleted: faceProbe.running = true

    // after a save: mirror the avatar for tools that look elsewhere. Nothing here is
    // critical — the lock screen only needs ~/.face — so this is best effort, silent.
    Process {
        id: syncProcess
        command: ["sh", "-c",
            "cp -f \"$HOME/.face\" \"$HOME/.face.icon\" 2>/dev/null; " +
            "if [ -w /var/lib/AccountsService/icons ]; then " +
            "cp -f \"$HOME/.face\" \"/var/lib/AccountsService/icons/$USER\" 2>/dev/null; fi"]
    }

    Process {
        id: resetProcess
        command: ["sh", "-c",
            "rm -f \"$HOME/.face\" \"$HOME/.face.icon\"; " +
            "if [ -w /var/lib/AccountsService/icons ]; then " +
            "rm -f \"/var/lib/AccountsService/icons/$USER\"; fi"]
        onExited: {
            page.hasFace = false;
            page.bump++;
        }
    }

    function setZoom(z) {
        zoom = Math.max(1, Math.min(3, z));
        zoomSlider.value = zoom;
        clampPan();
    }

    // pan limits: the image must keep covering the circle
    function clampPan() {
        if (baseScale <= 0) return;
        var dw = cropImg.naturalWidth * baseScale * zoom;
        var dh = cropImg.naturalHeight * baseScale * zoom;
        var limX = Math.max(0, (dw - viewSize) / 2);
        var limY = Math.max(0, (dh - viewSize) / 2);
        panX = Math.max(-limX, Math.min(limX, panX));
        panY = Math.max(-limY, Math.min(limY, panY));
    }

    function setPicked(url) {
        pickedSource = url;
        zoom = 1; panX = 0; panY = 0; baseScale = 0;
        zoomSlider.value = 1;
        statusText = "";
    }

    // Saving strategy: the editable circle is briefly resized to 512x512 so we can grab
    // the exact crop at full resolution from a visible item (grabbing hidden items is
    // unreliable), then it snaps back. The saved square is anonymous — the lock screen
    // re-masks it into the circle itself.
    function saveAvatar() {
        if (pickedSource === "" || baseScale <= 0) return;
        statusText = "SAVING…";
        viewSize = outSize;
        clampPan();
        grabTimer.restart();
    }

    function resetAvatar() {
        resetProcess.running = true;
    }

    Timer {
        id: grabTimer
        interval: 16
        onTriggered: {
            function restore() {
                page.viewSize = page.vsize;
                page.clampPan();
            }
            cropViewport.grabToImage(function (result) {
                restore();
                if (!result || !result.image.saveToFile(page.facePath)) {
                    page.statusText = "Couldn't save the picture";
                    return;
                }
                page.hasFace = true;
                page.bump++;
                syncProcess.running = true;
                page.statusText = "Saved — it's live on the lock screen already.";
            }, Qt.size(page.outSize, page.outSize));
        }
    }

    // Which avatar the "current" preview shows: the saved one, or the letter fallback.
    readonly property string previewUrl: hasFace ? "file://" + facePath + "?r=" + bump : ""

    // ═════════════ page body ═════════════

    Flickable {
        id: scrollArea
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function (event) {
                if (event.angleDelta.y === 0) return;
                var max = scrollArea.contentHeight - scrollArea.height;
                scrollArea.contentY = Math.max(0, Math.min(max, scrollArea.contentY - event.angleDelta.y));
                event.accepted = true;
            }
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.rightMargin
            spacing: 14

            Text {
                text: "USER PROFILE"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── current avatar + actions
            Row {
                width: parent.width
                height: 150
                spacing: 24

                Item {
                    width: 150; height: 150
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: currentAvatar
                        anchors.fill: parent; radius: width / 2
                        color: "#1a1a1a"
                        border.width: 1; border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            visible: currentAvatarImg.status !== Image.Ready
                            text: page.userName.charAt(0).toUpperCase()
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 48
                        }

                        Image {
                            id: currentAvatarImg
                            anchors.fill: parent
                            anchors.margins: 1
                            source: page.previewUrl
                            fillMode: Image.PreserveAspectCrop
                            smooth: true; mipmap: true; asynchronous: true
                        }

                        // circular mask so the preview matches the lock screen
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: avatarMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                        Item {
                            id: avatarMask
                            width: parent.width; height: parent.height
                            visible: false
                            layer.enabled: true
                            layer.smooth: true
                            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Row {
                        spacing: 10

                        Text {
                            text: page.userName
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "· lock screen avatar"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 10

                        PageButton {
                            label: "CHOOSE IMAGE"
                            onClicked: fileDialog.open()
                        }

                        PageButton {
                            label: "RESET"
                            visible: page.hasFace
                            onClicked: page.resetAvatar()
                        }
                    }

                    Text {
                        text: page.statusText
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        visible: page.statusText !== ""
                        wrapMode: Text.Wrap
                        width: 300
                    }

                    Text {
                        text: "The picture shows above your name on the lock screen.\nChanges apply instantly — no logout needed."
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        opacity: 0.7
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1; color: Theme.border
                visible: page.pickedSource !== ""
            }

            Column {
                width: parent.width
                spacing: 14
                visible: page.pickedSource !== ""

                Text {
                    text: "POSITION & SIZE"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.letterSpacing: 2
                }

                Row {
                    width: parent.width
                    height: page.vsize
                    spacing: 28

                    // ── crop circle: what you see is exactly what gets saved
                    Item {
                        id: cropViewport
                        width: page.viewSize; height: page.viewSize

                        Image {
                            id: cropImg
                            source: page.pickedSource
                            x: (parent.width - width) / 2 + page.panX
                            y: (parent.height - height) / 2 + page.panY
                            width: cropImg.naturalWidth * page.baseScale * page.zoom
                            height: cropImg.naturalHeight * page.baseScale * page.zoom
                            fillMode: Image.Stretch
                            smooth: true; mipmap: true
                            asynchronous: false

                            onStatusChanged: {
                                if (cropImg.status === Image.Ready) {
                                    page.baseScale = Math.max(
                                        page.viewSize / cropImg.naturalWidth,
                                        page.viewSize / cropImg.naturalHeight
                                    );
                                    page.clampPan();
                                }
                            }
                        }

                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: viewportMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                        Item {
                            id: viewportMask
                            width: parent.width; height: parent.height
                            visible: false
                            layer.enabled: true
                            layer.smooth: true
                            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                        }

                        Rectangle {
                            anchors.fill: parent; radius: width / 2
                            color: "transparent"
                            border.width: 1; border.color: Theme.border
                        }

                        MouseArea {
                            id: cropDrag
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.OpenHandCursor
                            acceptedButtons: Qt.LeftButton

                            property real lastX: 0
                            property real lastY: 0

                            onPressed: (mouse) => {
                                lastX = mouse.x; lastY = mouse.y;
                                cursorShape = Qt.ClosedHandCursor;
                            }
                            onReleased: cursorShape = Qt.OpenHandCursor
                            onPositionChanged: (mouse) => {
                                if (!pressed) return;
                                page.panX += mouse.x - lastX;
                                page.panY += mouse.y - lastY;
                                lastX = mouse.x; lastY = mouse.y;
                                page.clampPan();
                            }
                            onWheel: (wheel) => {
                                page.setZoom(page.zoom * (wheel.angleDelta.y > 0 ? 1.08 : 1 / 1.08));
                                wheel.accepted = true;
                            }
                        }
                    }

                    Column {
                        width: parent.width - page.vsize - 28
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        Text {
                            text: "Drag inside the circle to position · scroll (or the slider) to zoom"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            opacity: 0.8
                        }

                        Row {
                            width: parent.width
                            height: 30
                            spacing: 12

                            Text {
                                text: "ZOOM"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.letterSpacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Slider {
                                id: zoomSlider
                                width: parent.width - 70
                                from: 1; to: 3
                                stepSize: 0.01
                                value: page.zoom
                                onMoved: {
                                    page.zoom = value;
                                    page.clampPan();
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 10

                            PageButton {
                                label: "SAVE AVATAR"
                                highlight: true
                                onClicked: page.saveAvatar()
                            }

                            PageButton {
                                label: "DISCARD"
                                onClicked: page.setPicked("")
                            }
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Choose a picture for your avatar"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp *.avif)"]
        onAccepted: page.setPicked(selectedFile)
    }

    // ── shared button
    component PageButton: Rectangle {
        id: btn
        required property string label
        property bool highlight: false
        signal clicked()

        width: label.length * 8 + 24
        height: 34
        radius: Theme.radius
        color: hover.hovered || hover.pressed
            ? (highlight ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.accent, 0.08))
            : (highlight ? Theme.alpha(Theme.accent, 0.06) : "#00000000")
        border.width: 1
        border.color: highlight ? Theme.accent : Theme.border

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.highlight ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
        }
    }
}
