import QtQuick
import Quickshell
import qs.Ui

BarWidget {
    id: root

    Text {
        anchors.centerIn: parent
        text: "Telegram theme"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["omarchy-shell", root.moduleName, "resync"])
    }
}
