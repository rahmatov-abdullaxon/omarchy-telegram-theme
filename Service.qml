import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property var manifest: null

    readonly property string pluginId: manifest && manifest.id
        ? String(manifest.id) : "telegram-theme"
    readonly property string sourceDir: manifest && manifest.__sourceDir
        ? String(manifest.__sourceDir) : ""
    readonly property string watchScript: sourceDir
        ? sourceDir + "/bin/omarchy-telegram-watch.sh" : ""
    readonly property string genScript: sourceDir
        ? sourceDir + "/bin/omarchy-telegram-theme-gen.sh" : ""

    function resync() {
        if (!genScript) {
            console.warn("omarchy-telegram-theme: manifest.__sourceDir unavailable, cannot resync")
            return
        }
        resyncProcess.command = ["bash", root.genScript]
        resyncProcess.running = true
    }

    Process {
        id: resyncProcess
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim())
                    console.warn("omarchy-telegram-theme (resync):", text.trim())
            }
        }
    }

    Process {
        id: watcherProcess
        command: root.watchScript ? ["bash", root.watchScript] : []
        running: root.watchScript !== ""
        onExited: function (exitCode) {
            console.warn("omarchy-telegram-theme: watcher exited (code "
                + exitCode + "), restarting in 5s")
            restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 5000
        repeat: false
        onTriggered: {
            watcherProcess.running = false
            watcherProcess.running = true
        }
    }

    IpcHandler {
        target: root.pluginId
        function resync(): void {
            root.resync()
        }
    }

    Component.onCompleted: {
        if (!sourceDir) {
            console.warn("omarchy-telegram-theme: manifest.__sourceDir was not provided, "
                + "cannot locate bundled bin/ scripts")
        }
        console.warn("omarchy-telegram-theme DIAG: onCompleted manifest =",
            JSON.stringify(manifest))
    }

    onManifestChanged: {
        console.warn("omarchy-telegram-theme DIAG: manifest changed, keys =",
            manifest ? JSON.stringify(Object.keys(manifest)) : "null",
            "full =", JSON.stringify(manifest))
    }

    Timer {
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            console.warn("omarchy-telegram-theme DIAG: 3s later, manifest =",
                JSON.stringify(root.manifest),
                "sourceDir =", root.sourceDir)
        }
    }
}
