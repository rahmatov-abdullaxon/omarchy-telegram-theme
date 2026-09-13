import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property var manifest: null

    readonly property string pluginId: manifest && manifest.id
        ? String(manifest.id) : "telegram-theme"
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string sourceDir: (pluginId && homeDir)
        ? homeDir + "/.config/omarchy/plugins/" + pluginId : ""
    readonly property string watchScript: sourceDir
        ? sourceDir + "/bin/omarchy-telegram-watch.sh" : ""
    readonly property string genScript: sourceDir
        ? sourceDir + "/bin/omarchy-telegram-theme-gen.sh" : ""

    function resync() {
        if (!genScript) {
            console.warn("omarchy-telegram-theme: sourceDir unavailable, cannot resync")
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

    onSourceDirChanged: {
        if (sourceDir)
            console.warn("omarchy-telegram-theme: resolved sourceDir =", sourceDir)
    }

    Component.onCompleted: {
        console.warn("omarchy-telegram-theme: onCompleted, sourceDir currently =", sourceDir)
    }
}
