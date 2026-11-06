pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../globals/Theme.js" as Theme

Item {
    id: root
    property string icon
    property string title
    property string detail: ""
    property color accent: Theme.accent
    property bool marked: false
    property bool tooltipReady: false
    signal clicked()
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: title
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    implicitWidth: 32
    implicitHeight: 32
    Layout.alignment: Qt.AlignHCenter
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: mouse.containsMouse || root.activeFocus ? Theme.surface : "transparent"
        MaterialSymbol { anchors.centerIn: parent; text: root.icon; iconSize: 20; color: root.accent; fill: 0 }
        Rectangle { visible: root.marked; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 2; width: 7; height: 7; radius: 4; color: "#cba6f7" }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onContainsMouseChanged: {
            if (containsMouse) delay.restart()
            else { delay.stop(); root.tooltipReady = false }
        }
    }
    Timer { id: delay; interval: 300; onTriggered: root.tooltipReady = true }
    PopupWindow {
        visible: root.visible && mouse.containsMouse && root.tooltipReady
        anchor.item: root
        anchor.rect.x: root.width + 12
        anchor.rect.y: (root.height - implicitHeight) / 2
        implicitWidth: 220
        implicitHeight: labels.implicitHeight + 22
        color: "transparent"
        mask: Region {}
        ToolTipSurface {
            anchors.fill: parent
            ColumnLayout {
                id: labels
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 11; spacing: 4
                Text { Layout.fillWidth: true; text: root.title; textFormat: Text.PlainText; color: root.accent; font.pixelSize: 13; font.bold: true }
                Text { Layout.fillWidth: true; visible: text.length > 0; text: root.detail; textFormat: Text.PlainText; color: "#bac2de"; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 5; elide: Text.ElideRight }
            }
        }
    }
}
