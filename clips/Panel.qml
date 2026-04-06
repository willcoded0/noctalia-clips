import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 600 * Style.uiScaleRatio
    property real contentPreferredHeight: 680 * Style.uiScaleRatio

    property string gameFilter: ""
    property string sortOrder: "newest"
    property string hoveredClipPath: ""
    property int previewY: 0

    readonly property var uniqueGames: {
        var meta = root.pluginApi?.mainInstance?.clipMeta ?? {}
        var seen = {}
        var result = []
        Object.values(meta).forEach(g => {
            if (g && !seen[g]) { seen[g] = true; result.push(g) }
        })
        return result.sort()
    }

    readonly property var filteredClips: {
        var clips = root.pluginApi?.mainInstance?.clips ?? []
        var meta  = root.pluginApi?.mainInstance?.clipMeta ?? {}
        var favs  = root.pluginApi?.mainInstance?.clipFavorites ?? []
        var filtered
        if (root.gameFilter === "__favorites__") {
            filtered = clips.filter(c => favs.indexOf(c) >= 0)
        } else if (root.gameFilter) {
            filtered = clips.filter(c => (meta[c] ?? "") === root.gameFilter)
        } else {
            filtered = clips.slice()
        }

        if (root.sortOrder === "oldest") {
            return filtered.slice().reverse()
        } else if (root.sortOrder === "game") {
            return filtered.slice().sort((a, b) => {
                var ga = (meta[a] ?? "").toLowerCase()
                var gb = (meta[b] ?? "").toLowerCase()
                return ga < gb ? -1 : ga > gb ? 1 : 0
            })
        } else if (root.sortOrder === "favorites") {
            return filtered.slice().sort((a, b) => {
                var fa = favs.indexOf(a) >= 0
                var fb = favs.indexOf(b) >= 0
                if (fa && !fb) return -1
                if (!fa && fb) return 1
                return 0
            })
        }
        return filtered
    }

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon: "camera-video"
                    pointSize: Style.fontSizeL
                    color: Color.mPrimary
                }

                NText {
                    text: "Clips"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "folder-open"
                    tooltipText: "Open clips folder"
                    onClicked: root.pluginApi?.mainInstance?.openFolder()
                }

                NIconButton {
                    icon: "refresh"
                    tooltipText: "Refresh"
                    onClicked: root.pluginApi?.mainInstance?.refreshClips()
                }
            }

            NDivider { Layout.fillWidth: true }

            Flow {
                Layout.fillWidth: true
                spacing: Style.marginXS

                Repeater {
                    model: [
                        { "label": "Newest",         "value": "newest"    },
                        { "label": "Oldest",         "value": "oldest"    },
                        { "label": "By Game",        "value": "game"      },
                        { "label": "Favorites First","value": "favorites" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        radius: Style.radiusS
                        color: root.sortOrder === modelData.value ? Color.mPrimary : Color.mSurfaceVariant
                        implicitWidth: sortChipLabel.implicitWidth + Style.marginS * 2
                        implicitHeight: sortChipLabel.implicitHeight + Style.marginXS * 2

                        NText {
                            id: sortChipLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            pointSize: Style.fontSizeXS
                            color: root.sortOrder === modelData.value ? Color.mOnPrimary : Color.mOnSurface
                            font.weight: Style.fontWeightSemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sortOrder = modelData.value
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Style.marginXS
                visible: root.uniqueGames.length > 0
                         || (root.pluginApi?.mainInstance?.clipFavorites ?? []).length > 0

                Rectangle {
                    radius: Style.radiusS
                    color: root.gameFilter === "" ? Color.mPrimary : Color.mSurfaceVariant
                    implicitWidth: allLabel.implicitWidth + Style.marginS * 2
                    implicitHeight: allLabel.implicitHeight + Style.marginXS * 2

                    NText {
                        id: allLabel
                        anchors.centerIn: parent
                        text: "All"
                        pointSize: Style.fontSizeXS
                        color: root.gameFilter === "" ? Color.mOnPrimary : Color.mOnSurface
                        font.weight: Style.fontWeightSemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.gameFilter = ""
                    }
                }

                Rectangle {
                    radius: Style.radiusS
                    color: root.gameFilter === "__favorites__" ? Color.mPrimary : Color.mSurfaceVariant
                    implicitWidth: favsFilterLabel.implicitWidth + Style.marginS * 2
                    implicitHeight: favsFilterLabel.implicitHeight + Style.marginXS * 2

                    NText {
                        id: favsFilterLabel
                        anchors.centerIn: parent
                        text: "Favorites ★"
                        pointSize: Style.fontSizeXS
                        color: root.gameFilter === "__favorites__" ? Color.mOnPrimary : Color.mOnSurface
                        font.weight: Style.fontWeightSemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.gameFilter = (root.gameFilter === "__favorites__" ? "" : "__favorites__")
                    }
                }

                Repeater {
                    model: root.uniqueGames
                    delegate: Rectangle {
                        required property string modelData
                        radius: Style.radiusS
                        color: root.gameFilter === modelData ? Color.mPrimary : Color.mSurfaceVariant
                        implicitWidth: chipLabel.implicitWidth + Style.marginS * 2
                        implicitHeight: chipLabel.implicitHeight + Style.marginXS * 2

                        NText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData
                            pointSize: Style.fontSizeXS
                            color: root.gameFilter === modelData ? Color.mOnPrimary : Color.mOnSurface
                            font.weight: Style.fontWeightSemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.gameFilter = (root.gameFilter === modelData ? "" : modelData)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.filteredClips.length === 0
                    spacing: Style.marginM

                    NIcon {
                        icon: "camera-video"
                        pointSize: Style.fontSizeXXL * 2
                        color: Color.mOnSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                    }

                    NText {
                        text: root.gameFilter === "__favorites__"
                              ? "No favorites yet"
                              : root.gameFilter
                                ? "No clips for “" + root.gameFilter + "”"
                                : "No clips yet"
                        pointSize: Style.fontSizeL
                        color: Color.mOnSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                    }

                    NText {
                        text: "Press Super+K during a game to save a replay"
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        visible: !root.gameFilter
                    }
                }

                NScrollView {
                    id: scrollView
                    anchors.fill: parent
                    visible: root.filteredClips.length > 0

                    Column {
                        width: scrollView.width
                        spacing: Style.marginXS

                        Repeater {
                            model: root.filteredClips

                            delegate: Item {
                                id: clipItem
                                width: scrollView.width
                                height: 88 * Style.uiScaleRatio

                                property bool renaming: false

                                readonly property string filePath: modelData
                                readonly property string fileName: modelData.split("/").pop()
                                readonly property string fileNameNoExt: fileName.replace(/\.mp4$/i, "")
                                readonly property string game: (root.pluginApi?.mainInstance?.clipMeta ?? {})[modelData] ?? ""
                                readonly property bool clipFavorite: (root.pluginApi?.mainInstance?.clipFavorites ?? []).indexOf(modelData) >= 0
                                readonly property string duration: (root.pluginApi?.mainInstance?.clipDurations ?? {})[modelData] ?? ""
                                readonly property string dateStr: {
                                    var m = fileName.match(/(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})/)
                                    if (!m) return ""
                                    var h = parseInt(m[2]), min = m[3], sec = m[4]
                                    var ampm = h >= 12 ? "PM" : "AM"
                                    h = h % 12 || 12
                                    return m[1] + "  " + h + ":" + min + ":" + sec + " " + ampm
                                }

                                function confirmRename() {
                                    var n = renameField.text.trim()
                                    if (n) {
                                        root.pluginApi?.mainInstance?.renameClip(clipItem.filePath, n + ".mp4")
                                        clipItem.renaming = false
                                    }
                                }

                                NPopupContextMenu {
                                    id: clipMenu
                                    model: [
                                        { "label": "Open",      "action": "open",     "icon": "media-play" },
                                        { "label": "Copy",      "action": "copy",     "icon": "copy"       },
                                        { "label": clipItem.clipFavorite ? "Unfavorite" : "Favorite",
                                          "action": "favorite", "icon": "star"                             },
                                        { "label": "Rename",    "action": "rename",   "icon": "edit"       },
                                        { "label": "Trim",      "action": "trim",     "icon": "scissors"   },
                                        { "label": "Delete",    "action": "delete",   "icon": "trash"      }
                                    ]
                                    onTriggered: action => {
                                        clipMenu.close()
                                        if (action === "open")
                                            root.pluginApi?.mainInstance?.openClip(clipItem.filePath)
                                        else if (action === "copy")
                                            root.pluginApi?.mainInstance?.copyClip(clipItem.filePath)
                                        else if (action === "favorite")
                                            root.pluginApi?.mainInstance?.toggleFavorite(clipItem.filePath)
                                        else if (action === "rename")
                                            clipItem.renaming = true
                                        else if (action === "trim")
                                            root.pluginApi?.mainInstance?.trimClip(clipItem.filePath)
                                        else if (action === "delete")
                                            root.pluginApi?.mainInstance?.deleteClip(clipItem.filePath)
                                    }
                                }

                                Rectangle {
                                    anchors { fill: parent; margins: 2 }
                                    radius: Style.radiusM
                                    color: hoverArea.containsMouse ? Color.mHover : "transparent"

                                    MouseArea {
                                        id: hoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => {
                                            if (clipItem.renaming) return
                                            if (mouse.button === Qt.LeftButton)
                                                root.pluginApi?.mainInstance?.openClip(clipItem.filePath)
                                            else if (mouse.button === Qt.RightButton)
                                                PanelService.showContextMenu(clipMenu, clipItem, root.pluginApi?.panelOpenScreen)
                                        }
                                        onEntered: {
                                            root.hoveredClipPath = clipItem.filePath
                                            var pos = clipItem.mapToItem(panelContainer, 0, clipItem.height / 2)
                                            root.previewY = Math.max(0, Math.min(
                                                pos.y - 90,
                                                panelContainer.height - 180))
                                        }
                                        onExited: {
                                            if (root.hoveredClipPath === clipItem.filePath)
                                                root.hoveredClipPath = ""
                                        }
                                    }

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: Style.marginS
                                            rightMargin: Style.marginS
                                            topMargin: Style.marginXS
                                            bottomMargin: Style.marginXS
                                        }
                                        spacing: Style.marginM

                                        Rectangle {
                                            width: 128 * Style.uiScaleRatio
                                            height: 72 * Style.uiScaleRatio
                                            radius: Style.radiusS
                                            color: Color.mSurfaceVariant
                                            clip: true

                                            Thumbnail {
                                                anchors.fill: parent
                                                filePath: clipItem.filePath
                                                cacheDir: root.pluginApi?.mainInstance?.cacheDir ?? "/tmp/"
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Rectangle {
                                                visible: clipItem.game !== ""
                                                color: Color.mPrimary
                                                radius: Style.radiusXS
                                                implicitWidth: gameLabel.implicitWidth + Style.marginS * 2
                                                implicitHeight: gameLabel.implicitHeight + Style.marginXXS * 2

                                                NText {
                                                    id: gameLabel
                                                    anchors.centerIn: parent
                                                    text: clipItem.game
                                                    pointSize: Style.fontSizeXS
                                                    color: Color.mOnPrimary
                                                    font.weight: Style.fontWeightSemiBold
                                                }
                                            }

                                            NText {
                                                visible: !clipItem.renaming
                                                text: clipItem.fileName
                                                pointSize: Style.fontSizeS
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            TextField {
                                                id: renameField
                                                visible: clipItem.renaming
                                                Layout.fillWidth: true
                                                text: clipItem.fileNameNoExt
                                                color: Color.mOnSurface
                                                placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                                                selectByMouse: true
                                                topPadding: 2
                                                bottomPadding: 2
                                                leftPadding: Style.marginXS
                                                rightPadding: Style.marginXS
                                                font.family: Settings.data.ui.fontDefault
                                                font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                                                font.weight: Style.fontWeightRegular
                                                background: Rectangle {
                                                    color: Color.mSurfaceVariant
                                                    radius: Style.radiusXS
                                                }
                                                Keys.onReturnPressed: clipItem.confirmRename()
                                                Keys.onEscapePressed: clipItem.renaming = false
                                                onVisibleChanged: {
                                                    if (visible) Qt.callLater(function() {
                                                        renameField.forceActiveFocus()
                                                        renameField.selectAll()
                                                    })
                                                }
                                            }

                                            RowLayout {
                                                visible: !clipItem.renaming
                                                spacing: Style.marginS

                                                NText {
                                                    text: clipItem.dateStr
                                                    pointSize: Style.fontSizeXS
                                                    color: Color.mOnSurfaceVariant
                                                    visible: clipItem.dateStr !== ""
                                                }

                                                NText {
                                                    text: clipItem.duration
                                                    pointSize: Style.fontSizeXS
                                                    color: Color.mOnSurfaceVariant
                                                    visible: clipItem.duration !== ""
                                                }
                                            }
                                        }

                                        RowLayout {
                                            spacing: 0

                                            NIconButton {
                                                visible: !clipItem.renaming
                                                icon: clipItem.clipFavorite ? "star-filled" : "star"
                                                tooltipText: clipItem.clipFavorite ? "Unfavorite" : "Favorite"
                                                onClicked: root.pluginApi?.mainInstance?.toggleFavorite(clipItem.filePath)
                                            }

                                            NIconButton {
                                                visible: !clipItem.renaming
                                                icon: "copy"
                                                tooltipText: "Copy"
                                                onClicked: root.pluginApi?.mainInstance?.copyClip(clipItem.filePath)
                                            }

                                            NIconButton {
                                                visible: !clipItem.renaming
                                                icon: "media-play"
                                                tooltipText: "Open"
                                                onClicked: root.pluginApi?.mainInstance?.openClip(clipItem.filePath)
                                            }

                                            NIconButton {
                                                visible: !clipItem.renaming
                                                icon: "edit"
                                                tooltipText: "Rename"
                                                onClicked: clipItem.renaming = true
                                            }

                                            NIconButton {
                                                visible: !clipItem.renaming && hoverArea.containsMouse
                                                icon: "scissors"
                                                tooltipText: "Trim"
                                                onClicked: root.pluginApi?.mainInstance?.trimClip(clipItem.filePath)
                                            }

                                            NIconButton {
                                                visible: clipItem.renaming
                                                icon: "check"
                                                tooltipText: "Confirm rename"
                                                onClicked: clipItem.confirmRename()
                                            }

                                            NIconButton {
                                                visible: clipItem.renaming
                                                icon: "close"
                                                tooltipText: "Cancel"
                                                onClicked: clipItem.renaming = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: previewPopup
            visible: root.hoveredClipPath !== ""
            x: panelContainer.width + 8
            y: root.previewY
            width: 320
            height: 180
            radius: Style.radiusM
            color: Color.mSurface
            clip: true
            z: 10

            onVisibleChanged: visible ? previewVideo.play() : previewVideo.stop()

            Video {
                id: previewVideo
                anchors.fill: parent
                source: root.hoveredClipPath ? "file://" + root.hoveredClipPath : ""
                fillMode: VideoOutput.PreserveAspectCrop
                muted: true
                autoPlay: false
                onPositionChanged: {
                    if (position >= 30000) {
                        seek(0)
                        play()
                    }
                }
            }

            NIcon {
                anchors.centerIn: parent
                visible: previewVideo.playbackState !== MediaPlayer.PlayingState
                icon: "camera-video"
                pointSize: Style.fontSizeXXL
                color: Color.mOnSurfaceVariant
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Color.mOutline
                border.width: 1
            }
        }
    }
}
