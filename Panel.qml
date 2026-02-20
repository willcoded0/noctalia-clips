import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 480 * Style.uiScaleRatio
    property real contentPreferredHeight: 620 * Style.uiScaleRatio

    // ── Filter state ──────────────────────────────────────────────────────────
    property string gameFilter: ""

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
        if (!root.gameFilter) return clips
        var meta = root.pluginApi?.mainInstance?.clipMeta ?? {}
        return clips.filter(c => (meta[c] ?? "") === root.gameFilter)
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

            // ── Header ──────────────────────────────────────────────────────
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

            // ── Game filter chips ──────────────────────────────────────────
            Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: Style.marginXS
                visible: root.uniqueGames.length > 0

                // "All" chip
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

            // ── Content ──────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state
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
                        text: root.gameFilter ? "No clips for \u201c" + root.gameFilter + "\u201d" : "No clips yet"
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

                // Clips list
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

                                readonly property string filePath: modelData
                                readonly property string fileName: modelData.split("/").pop()
                                readonly property string game: (root.pluginApi?.mainInstance?.clipMeta ?? {})[modelData] ?? ""
                                readonly property string dateStr: {
                                    var m = fileName.match(/(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})/)
                                    if (!m) return ""
                                    var h = parseInt(m[2]), min = m[3], sec = m[4]
                                    var ampm = h >= 12 ? "PM" : "AM"
                                    h = h % 12 || 12
                                    return m[1] + "  " + h + ":" + min + ":" + sec + " " + ampm
                                }

                                NPopupContextMenu {
                                    id: clipMenu
                                    model: [
                                        { "label": "Open",   "action": "open",   "icon": "media-play" },
                                        { "label": "Copy path", "action": "copy", "icon": "edit-copy" },
                                        { "label": "Delete", "action": "delete", "icon": "trash"      }
                                    ]
                                    onTriggered: action => {
                                        clipMenu.close()
                                        if (action === "open")
                                            root.pluginApi?.mainInstance?.openClip(clipItem.filePath)
                                        else if (action === "copy")
                                            root.pluginApi?.mainInstance?.copyClip(clipItem.filePath)
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
                                            if (mouse.button === Qt.LeftButton)
                                                root.pluginApi?.mainInstance?.openClip(clipItem.filePath)
                                            else if (mouse.button === Qt.RightButton)
                                                PanelService.showContextMenu(clipMenu, clipItem, root.pluginApi?.panelOpenScreen)
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

                                        // Thumbnail
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

                                        // File info
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            // Game badge
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
                                                text: clipItem.fileName
                                                pointSize: Style.fontSizeS
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            NText {
                                                text: clipItem.dateStr
                                                pointSize: Style.fontSizeXS
                                                color: Color.mOnSurfaceVariant
                                                visible: clipItem.dateStr !== ""
                                            }
                                        }

                                        // Action buttons
                                        RowLayout {
                                            spacing: 0

                                            NIconButton {
                                                icon: "edit-copy"
                                                tooltipText: "Copy path"
                                                onClicked: root.pluginApi?.mainInstance?.copyClip(clipItem.filePath)
                                            }

                                            NIconButton {
                                                icon: "media-play"
                                                tooltipText: "Open"
                                                onClicked: root.pluginApi?.mainInstance?.openClip(clipItem.filePath)
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
    }
}
