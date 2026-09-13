import QtQuick
import Quickshell
import qs.Ui

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
        onClicked: Quickshell.execDetached(["omarchy-shell", root.pluginId, "resync"])
    }
}
