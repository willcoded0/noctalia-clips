import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

// Displays a video thumbnail, extracting it on first use via ffmpeg.
Item {
    id: root

    property string filePath: ""
    property string cacheDir: "/tmp/"

    // Use the filename as the cache key (timestamps in the name make it unique)
    readonly property string thumbPath: {
        var name = filePath.split("/").pop().replace(/\.mp4$/i, "")
        return cacheDir + name + ".jpg"
    }

    Rectangle {
        anchors.fill: parent
        color: Color.mSurfaceVariant
        radius: Style.radiusS

        Image {
            id: img
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            clip: true

            onStatusChanged: {
                if (status === Image.Error && source.toString() !== "") {
                    // Cache miss — kick off extraction
                    extractProc.running = false
                    extractProc.command = [
                        "ffmpeg",
                        "-loglevel", "quiet",
                        "-ss", "3",
                        "-i", root.filePath,
                        "-vframes", "1",
                        "-q:v", "4",
                        "-vf", "scale=320:-1",
                        root.thumbPath,
                        "-y"
                    ]
                    extractProc.running = true
                }
            }
        }

        // Fallback icon while loading or on permanent failure
        NIcon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            icon: "camera-video"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurfaceVariant
        }
    }

    Process {
        id: extractProc
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                img.source = ""
                img.source = "file://" + root.thumbPath
            }
        }
    }

    Component.onCompleted: {
        img.source = "file://" + root.thumbPath
    }
}
