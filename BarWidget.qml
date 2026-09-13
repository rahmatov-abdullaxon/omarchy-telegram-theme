import QtQuick
import Quickshell
import qs.Ui

// Minimal bar-widget entry point, deliberately kept close to the confirmed
// example in docs/bar-widgets-and-settings.md. This plugin doesn't need
// user-configurable settings, so it skips the setting()/schema machinery
// entirely rather than inventing fields it doesn't use.
BarWidget {
    id: root

    readonly property string pluginId: manifest && manifest.id
        ? String(manifest.id) : "telegram-theme"

    Text {
        anchors.centerIn: parent
        text: "Telegram theme"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["omarchy-shell", root.pluginId, "resync"])

        ToolTip.visible: containsMouse
        ToolTip.text: "Click to force an immediate Telegram theme resync"
    }
}
