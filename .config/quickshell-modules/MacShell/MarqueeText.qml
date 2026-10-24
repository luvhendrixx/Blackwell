// One line of text that scrolls when it is too long (like the Now Playing subtitle on macOS):
// it rests for a moment, glides left in a loop, and fades out at both ends. Text that fits just sits still.
// The glide uses an XAnimator rather than a plain property animation: animators run on the render
// thread, so the text keeps a perfectly even pace even while the GUI thread is busy doing other work.
import QtQuick
import QtQuick.Effects

Item {
    id: m

    property string text: ""
    property color color: "white"
    property string fam: "Inter"
    property real pixelSize: 16
    property int weight: Font.Medium
    property real fade: 18            // px of fade at each end while scrolling
    property real startPad: 0         // where the text starts when it fits (the region itself may begin further left)
    property real speed: 34           // px / s
    property bool animate: true

    height: Math.ceil(pixelSize * 1.3)
    readonly property real gap: pixelSize * 3
    readonly property bool overflow: probe.implicitWidth > width - startPad
    // full seamless cycle: the text travels one copy + the gap, then the loop repeats
    readonly property real lap: probe.implicitWidth + gap

    Text {
        id: probe
        visible: false
        text: m.text
        font.family: m.fam
        font.pixelSize: m.pixelSize
        font.weight: m.weight
    }

    Item {
        id: strip
        anchors.fill: parent
        visible: false
        clip: true
        Row {
            id: row
            spacing: m.gap
            Text {
                text: m.text
                color: m.color
                height: strip.height
                verticalAlignment: Text.AlignVCenter
                font.family: m.fam
                font.pixelSize: m.pixelSize
                font.weight: m.weight
            }
            Text {
                visible: m.overflow
                text: m.text
                color: m.color
                height: strip.height
                verticalAlignment: Text.AlignVCenter
                font.family: m.fam
                font.pixelSize: m.pixelSize
                font.weight: m.weight
            }
        }
    }

    Rectangle {   // soft left / right edges
        id: edgeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: Math.min(0.45, m.fade / Math.max(1, m.width)); color: "black" }
            GradientStop { position: Math.max(0.55, 1 - m.fade / Math.max(1, m.width)); color: "black" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: strip
        maskEnabled: m.overflow
        maskSource: edgeMask
    }

    // ── motion ──
    // x is owned by the animator (no binding on Row.x): the old version animated a helper
    // property and bounced it through a binding every frame, which could stutter; this writes
    // straight through on the render thread instead.
    XAnimator {
        id: glide
        target: row
        loops: 1
        easing.type: Easing.Linear
        onStopped: {              // a lap finished by itself: park at the rest position, wait, go again
            if (m.lapEnded) {
                m.lapEnded = false;
                row.x = m.startPad;
                if (m.scrollOn) restTimer.restart();
            }
        }
    }
    property bool lapEnded: false
    Timer {
        id: restTimer
        interval: 2400
        onTriggered: if (m.scrollOn) m.beginLap()
    }

    readonly property bool scrollOn: overflow && animate && visible

    function beginLap() {
        lapEnded = false;         // the restart's stop event must not be mistaken for a finished lap
        glide.from = startPad;
        glide.to = startPad - lap;
        glide.duration = Math.max(1, lap / Math.max(1, speed) * 1000);
        glide.start();
        lapEnded = true;          // from now on, only stopping for real can fire the handler
    }

    function update() {           // re-derive the motion from every relevant state change
        restTimer.stop();
        lapEnded = false;
        if (glide.running) glide.stop();
        row.x = startPad;         // parks at the rest position: text change, pause, hide, resize
        if (scrollOn) restTimer.restart();
    }

    // row.x must NOT be a binding: the animator owns the property
    Component.onCompleted: row.x = startPad

    onTextChanged: update()
    onOverflowChanged: update()
    onLapChanged: update()
    onVisibleChanged: update()
    // startPad follows the layout's scale factor; a change generally means a resize/redress
    onStartPadChanged: update()
}
