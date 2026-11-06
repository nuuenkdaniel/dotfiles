pragma ComponentBehavior: Bound
import QtQuick
import "../globals/Theme.js" as Theme

Rectangle {
    id: root
    property string text
    property bool selected: false
    property bool danger: false
    signal clicked()
    implicitWidth: caption.implicitWidth + 22
    implicitHeight: 32
    radius: 8
    opacity: enabled ? 1 : .4
    color: selected ? Theme.selected : mouse.containsMouse || activeFocus ? Theme.hover : Theme.surface
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Text {
        id: caption
        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        color: root.danger ? Theme.danger : Theme.accent
        font.pixelSize: 12
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
