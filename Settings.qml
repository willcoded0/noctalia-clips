import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    spacing: Style.marginM

    property string clipsFolder: pluginApi?.pluginSettings?.clipsFolder
        || pluginApi?.manifest?.metadata?.defaultSettings?.clipsFolder
        || "~/Videos"

    property int maxClips: pluginApi?.pluginSettings?.maxClips ?? 50

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            root.clipsFolder = root.pluginApi?.pluginSettings?.clipsFolder
                || root.pluginApi?.manifest?.metadata?.defaultSettings?.clipsFolder
                || "~/Videos"
            root.maxClips = root.pluginApi?.pluginSettings?.maxClips ?? 50
        }
    }

    function save() {
        if (!pluginApi) return
        pluginApi.pluginSettings.clipsFolder = root.clipsFolder
        pluginApi.pluginSettings.maxClips = root.maxClips
        pluginApi.saveSettings()
        root.pluginApi?.mainInstance?.refreshClips()
    }

    // ── Clips folder ──────────────────────────────────────────────────────────

    NLabel {
        label: "Clips Folder"
        description: "Where gpu-screen-recorder saves replay clips (set in gsr-replay.service)"
    }

    NFilePicker {
        id: folderPicker
        title: "Select clips folder"
        initialPath: {
            var f = root.clipsFolder
            if (f.startsWith("~/")) return Quickshell.env("HOME") + f.substring(1)
            return f
        }
        selectionMode: "folders"
        onAccepted: paths => {
            if (paths && paths.length > 0) {
                root.clipsFolder = paths[0]
                root.save()
            }
        }
    }

    NButton {
        text: root.clipsFolder
        icon: "folder-open"
        Layout.fillWidth: true
        onClicked: folderPicker.openFilePicker()
    }

    // ── Max clips ─────────────────────────────────────────────────────────────

    NLabel {
        label: "Maximum Clips"
        description: "How many clips to show in the panel (oldest are hidden)"
    }

    NTextInput {
        placeholderText: "50"
        text: root.maxClips.toString()
        Layout.fillWidth: true
        onTextChanged: {
            var n = parseInt(text)
            if (!isNaN(n) && n > 0 && n !== root.maxClips) {
                root.maxClips = n
                root.save()
            }
        }
    }
}
