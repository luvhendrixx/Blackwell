// Out-of-line lock-screen video wallpaper.
//
// The QtMultimedia import lives HERE, not in LockScreen.qml, so the lock can
// never be taken hostage by a broken/missing module: this file is only loaded
// (via Loader) when a video wallpaper is actually set. Without qt6-multimedia
// installed the loader reports Error and the lock simply uses the static
// wallpaper — everything else keeps working.
import QtQuick
import QtMultimedia

Item {
    id: root

    property string video: ""   // absolute path to the video file

    MediaPlayer {
        source: root.video !== "" ? "file://" + root.video : ""
        loops: MediaPlayer.Infinite
        videoOutput: vo
        Component.onCompleted: play()
    }
    VideoOutput {
        id: vo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
