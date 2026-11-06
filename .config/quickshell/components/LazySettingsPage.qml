import QtQuick
import QtQuick.Layouts

Loader {
    id: root
    property bool selected: false
    property bool panelActive: false
    readonly property bool pageActive: selected && panelActive
    property bool visited: false
    onPageActiveChanged: if (pageActive) visited = true
    Component.onCompleted: if (pageActive) visited = true
    active: visited
    visible: selected
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.topMargin: 12
    Layout.rightMargin: 8
    Layout.bottomMargin: 8
}
