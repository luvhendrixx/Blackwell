import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Brightness OSD — mirrors the volume flyout style
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 150
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: flyout.open ? flyout : null }

    property bool showing: false
    property bool ready: false
    property real brightness: 0
    property bool hovered: flyoutArea.containsMouse

    IpcHandler {
        target: "brightnessosd"
        function show(): void {
            if (!root.ready) return
            root.refresh()
            root.showing = true
            hideTimer.restart()
        }
    }

    function refresh() {
        if (brightProcess.running) return
        brightProcess.running = true
    }

    Process {
        id: brightProcess
        command: ["sh", "-c", "brightnessctl get | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text.trim())
                if (!isNaN(v)) {
                    root.brightness = Math.max(0, Math.min(1, v / 100))
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (root.hovered) {
                hideTimer.restart()
                return
            }
            root.showing = false
        }
    }

    Timer {
        interval: 700
        repeat: true
        running: root.showing
        onTriggered: root.refresh()
    }

    Timer {
        id: startupTimer
        interval: 2000
        repeat: false
        running: true
        onTriggered: root.ready = true
    }

    Rectangle {
        id: flyout
        property bool open: root.showing
        width: 320
        height: 28
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        radius: 36
        color: Theme.bg
        opacity: open ? 1 : 0
        scale: open ? 1 : 0.9

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: flyoutArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: flyout.open
        }

        Text {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: root.brightness <= 0 ? "󰃠" : (root.brightness < 0.5 ? "󰃠" : "󰃮")
            font.family: "Symbols Nerd Font"
            font.pixelSize: 20
            color: Theme.text
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.brightness * 100) + "%"
            font.pixelSize: 12
            font.bold: true
            color: Theme.text
        }

        Rectangle {
            anchors.left: icon.right
            anchors.leftMargin: 15
            anchors.right: parent.right
            anchors.rightMargin: 68
            anchors.verticalCenter: parent.verticalCenter
            height: 5
            radius: 4
            color: "#555555"

            Rectangle {
                width: parent.width * Math.min(root.brightness, 1)
                height: parent.height
                radius: 4
                color: Theme.text
                Behavior on width { NumberAnimation { duration: 100 } }
            }
        }
    }
}