import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property string clipsFolder: {
        var f = pluginApi?.pluginSettings?.clipsFolder
              || pluginApi?.manifest?.metadata?.defaultSettings?.clipsFolder
              || "~/Videos"
        if (f.startsWith("~/")) return Quickshell.env("HOME") + f.substring(1)
        return f
    }

    readonly property int maxClips: pluginApi?.pluginSettings?.maxClips ?? 50

    // Clip list — newest first
    property var clips: []
    property bool ready: false

    // Game metadata: { "/path/to/clip.mp4": "Elden Ring", ... }
    property var clipMeta: ({})

    // New-clip indicator for the bar widget
    property bool hasNewClip: false
    property string latestClip: ""

    readonly property string cacheDir: (Settings.cacheDir || "/tmp/") + "noctalia-clips/"

    // Scratch buffer — mutated in-place during scan, not observed by UI
    property var _scanBuffer: []

    // ── Public functions ──────────────────────────────────────────────────────

    function openClip(path) {
        Quickshell.execDetached(["xdg-open", path])
    }

    function openFolder() {
        Quickshell.execDetached(["xdg-open", root.clipsFolder])
    }

    function copyClip(path) {
        // Copies the file path as plain text to the Wayland clipboard
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' " + shellEscape(path) + " | wl-copy"])
    }

    function deleteClip(path) {
        deleteProc.command = ["rm", "--", path]
        deleteProc.running = true
        root.clips = root.clips.filter(c => c !== path)
        // Clean up metadata
        var meta = Object.assign({}, root.clipMeta)
        delete meta[path]
        root.clipMeta = meta
        if (root.pluginApi) {
            root.pluginApi.pluginSettings.clipMeta = meta
            root.pluginApi.saveSettings()
        }
    }

    function refreshClips() {
        root._scanBuffer = []
        root.clips = []
        root.ready = false
        scanProc.running = false
        scanProc.command = [
            "sh", "-c",
            "find " + shellEscape(root.clipsFolder) +
            " -maxdepth 1 -name '*.mp4' -type f | sort -r | head -" + root.maxClips
        ]
        scanProc.running = true
    }

    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'"
    }

    function saveGameMeta(filepath, game) {
        if (!game || !game.trim() || !root.pluginApi) return
        var meta = Object.assign({}, root.clipMeta)
        meta[filepath] = game.trim()
        root.clipMeta = meta
        root.pluginApi.pluginSettings.clipMeta = meta
        root.pluginApi.saveSettings()
    }

    // ── Processes ─────────────────────────────────────────────────────────────

    Process {
        id: scanProc
        running: false
        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (t) root._scanBuffer.push(t)
            }
        }
        onExited: {
            root.clips = root._scanBuffer.slice()
            root._scanBuffer = []
            root.ready = true
        }
    }

    Process {
        id: deleteProc
        running: false
    }

    // ── IPC ───────────────────────────────────────────────────────────────────

    IpcHandler {
        target: "plugin:clips"

        function clipSaved(filepath: string, game: string) {
            if (!filepath) return
            var newList = [filepath, ...root.clips.filter(c => c !== filepath)]
            if (newList.length > root.maxClips) newList = newList.slice(0, root.maxClips)
            root.clips = newList
            root.latestClip = filepath
            root.hasNewClip = true
            root.saveGameMeta(filepath, game)
            var basename = filepath.split("/").pop()
            var label = game && game.trim() ? game.trim() : basename
            ToastService.showNotice(
                "Clip saved" + (game && game.trim() ? " · " + game.trim() : ""),
                basename,
                "camera-video",
                5000,
                "Open",
                () => root.openClip(filepath)
            )
        }

        function openPanel() {
            root.pluginApi.withCurrentScreen(screen => root.pluginApi.openPanel(screen))
        }

        function openFolder() {
            root.openFolder()
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    onPluginApiChanged: {
        if (pluginApi) {
            root.clipMeta = pluginApi.pluginSettings?.clipMeta ?? ({})
        }
    }

    Component.onCompleted: {
        root.clipMeta = pluginApi?.pluginSettings?.clipMeta ?? ({})
        Quickshell.execDetached(["mkdir", "-p", root.cacheDir])
        refreshClips()
    }

    onClipsFolderChanged: {
        if (root.clipsFolder) refreshClips()
    }
}
