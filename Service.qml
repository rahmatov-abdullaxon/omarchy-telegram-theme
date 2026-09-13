import QtQuick
import Quickshell
import Quickshell.Io

// Headless "service" kind entry point. No UI -- this just keeps the
// already-tested bash watcher (bin/omarchy-telegram-watch.sh) running as a
// supervised child process for as long as the plugin is enabled, and
// exposes a "resync" IPC method the bar widget (and `omarchy-shell`) can
// call to force an immediate one-off regenerate.
//
// The actual color-mapping, image-downscaling, and Telegram-restart logic
// all lives in the bundled bin/ scripts, which were built and tested
// extensively against a real Omarchy install outside of this plugin
// wrapper. This file's only job is to launch and supervise them.
Item {
    id: root

    // Injected by the host after this component loads (see
    // docs/plugin-structure-and-manifest.md: "Service ... entry points may
    // declare omarchyPath, shell, manifest, pluginRegistry, and
    // barWidgetRegistry"). Do not mark these required.
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

    // One-off manual resync (called by the bar widget's click handler and
    // by the resync IPC method below).
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

    // Long-running watcher. `running: true` starts it; toggling `running`
    // false then true again is used below to restart it after an
    // unexpected exit -- this mirrors systemd's Restart=on-failure, but I
    // have not been able to verify this specific restart-by-retoggle
    // behavior against a live Quickshell runtime, so please confirm it
    // actually restarts the process when testing.
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

    // Lets `omarchy-shell <plugin-id> resync` trigger an immediate re-sync
    // without waiting for the next theme/wallpaper change. Modeled on the
    // confirmed IpcHandler pattern from docs/bar-widgets-and-settings.md;
    // I have not independently confirmed that `target` must exactly equal
    // the manifest id for `omarchy-shell` to route to it, though every
    // real example I found is consistent with that.
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
    }
}
