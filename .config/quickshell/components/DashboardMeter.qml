pragma ComponentBehavior: Bound
import QtQuick
import "../globals"

Rectangle {
    id: root
    property real value: -1
    property color accent: "#cba6f7"
    implicitHeight: 4
    radius: 2
    color: "#3b3449"
    Rectangle {
        width: Math.max(0, Math.min(1, root.value)) * parent.width
        height: parent.height
        radius: 2
        color: root.accent
        Behavior on width { NumberAnimation { duration: DashboardState.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
    }
}
