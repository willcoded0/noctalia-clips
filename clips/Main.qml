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

    property var clips: []
    property bool ready: false
    property var clipMeta: ({})
    property var clipDurations: ({})
    property var clipFavorites: []
    property bool hasNewClip: false
    property string latestClip: ""

    readonly property string cacheDir: (Settings.cacheDir || "/tmp/") + "noctalia-clips/"
    property var _scanBuffer: []

    function openClip(path) {
        Quickshell.execDetached(["xdg-open", path])
    }

    function openFolder() {
        Quickshell.execDetached(["xdg-open", root.clipsFolder])
    }

    function copyClip(path) {
        Quickshell.execDetached(["sh", "-c",
            "printf 'file://%s\\r\\n' " + shellEscape(path) + " | wl-copy --type=text/uri-list"])
    }

    function deleteClip(path) {
        var thumbName = path.split("/").pop().replace(/\.mp4$/i, "") + ".jpg"
        Quickshell.execDetached(["rm", "-f", "--", root.cacheDir + thumbName])
        deleteProc.command = ["rm", "--", path]
        deleteProc.running = true
        root.clips = root.clips.filter(c => c !== path)
        var meta = Object.assign({}, root.clipMeta)
        delete meta[path]
        root.clipMeta = meta
        var dur = Object.assign({}, root.clipDurations)
        delete dur[path]
        root.clipDurations = dur
        root.clipFavorites = root.clipFavorites.filter(f => f !== path)
        if (root.pluginApi) {
            root.pluginApi.pluginSettings.clipMeta = meta
            root.pluginApi.pluginSettings.clipDurations = dur
            root.pluginApi.pluginSettings.clipFavorites = root.clipFavorites.slice()
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

    function fetchDurations() {
        if (root.clips.length === 0) return
        var newClips = root.clips.filter(p => root.clipDurations[p] === undefined)
        if (newClips.length === 0) return
        var paths = newClips.map(p => shellEscape(p)).join(" ")
        var cmd = "printf '%s\\n' " + paths +
                  " | while IFS= read -r f; do" +
                  " d=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 \"$f\" 2>/dev/null);" +
                  " printf '%s|%s\\n' \"$f\" \"$d\";" +
                  " done"
        durationProc.running = false
        durationProc.command = ["sh", "-c", cmd]
        durationProc.running = true
    }

    function formatDuration(seconds) {
        var s = Math.round(parseFloat(seconds))
        if (isNaN(s) || s < 0) return ""
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        if (h > 0)
            return h + ":" + String(m).padStart(2, "0") + ":" + String(sec).padStart(2, "0")
        return m + ":" + String(sec).padStart(2, "0")
    }

    function toggleFavorite(path) {
        var favs = root.clipFavorites.slice()
        var idx = favs.indexOf(path)
        if (idx >= 0)
            favs.splice(idx, 1)
        else
            favs.unshift(path)
        root.clipFavorites = favs
        if (root.pluginApi) {
            root.pluginApi.pluginSettings.clipFavorites = favs
            root.pluginApi.saveSettings()
        }
    }

    function renameClip(oldPath, newName) {
        var dir = oldPath.substring(0, oldPath.lastIndexOf("/") + 1)
        var newPath = dir + newName
        root.clips = root.clips.map(c => c === oldPath ? newPath : c)
        var meta = Object.assign({}, root.clipMeta)
        if (meta[oldPath] !== undefined) {
            meta[newPath] = meta[oldPath]
            delete meta[oldPath]
        }
        root.clipMeta = meta
        var dur = Object.assign({}, root.clipDurations)
        if (dur[oldPath] !== undefined) {
            dur[newPath] = dur[oldPath]
            delete dur[oldPath]
        }
        root.clipDurations = dur
        root.clipFavorites = root.clipFavorites.map(f => f === oldPath ? newPath : f)
        if (root.pluginApi) {
            root.pluginApi.pluginSettings.clipMeta = meta
            root.pluginApi.pluginSettings.clipDurations = dur
            root.pluginApi.pluginSettings.clipFavorites = root.clipFavorites.slice()
            root.pluginApi.saveSettings()
        }
        renameProc.running = false
        renameProc.command = ["mv", "--", oldPath, newPath]
        renameProc.running = true
    }

    function trimClip(path) {
        Quickshell.execDetached(["sh", "-c",
            "if command -v losslesscut >/dev/null 2>&1; then losslesscut " + shellEscape(path) + "; " +
            "elif command -v LosslessCut >/dev/null 2>&1; then LosslessCut " + shellEscape(path) + "; " +
            "elif command -v kdenlive >/dev/null 2>&1; then kdenlive " + shellEscape(path) + "; " +
            "else xdg-open " + shellEscape(path) + "; fi"])
    }

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
            root.fetchDurations()
        }
    }

    Process {
        id: deleteProc
        running: false
    }

    Process {
        id: durationProc
        running: false
        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (!t) return
                var sep = t.lastIndexOf("|")
                if (sep < 0) return
                var path = t.substring(0, sep)
                var secs = t.substring(sep + 1).trim()
                var formatted = root.formatDuration(secs)
                if (path && formatted) {
                    var dur = Object.assign({}, root.clipDurations)
                    dur[path] = formatted
                    root.clipDurations = dur
                }
            }
        }
        onExited: {
            if (root.pluginApi) {
                root.pluginApi.pluginSettings.clipDurations = root.clipDurations
                root.pluginApi.saveSettings()
            }
        }
    }

    Process {
        id: renameProc
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) root.refreshClips()
        }
    }

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
            root.fetchDurations()
            var basename = filepath.split("/").pop()
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

    onPluginApiChanged: {
        if (pluginApi) {
            root.clipMeta      = pluginApi.pluginSettings?.clipMeta      ?? ({})
            root.clipDurations = pluginApi.pluginSettings?.clipDurations ?? ({})
            root.clipFavorites = pluginApi.pluginSettings?.clipFavorites ?? []
        }
    }

    Component.onCompleted: {
        root.clipMeta      = pluginApi?.pluginSettings?.clipMeta      ?? ({})
        root.clipDurations = pluginApi?.pluginSettings?.clipDurations ?? ({})
        root.clipFavorites = pluginApi?.pluginSettings?.clipFavorites ?? []
        Quickshell.execDetached(["mkdir", "-p", root.cacheDir])
        refreshClips()
    }

    onClipsFolderChanged: {
        if (root.clipsFolder) refreshClips()
    }
}
