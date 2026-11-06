pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    property string symbol: ""
    property string tooltip: ""
    property bool highlighted: false
    implicitWidth: 36
    implicitHeight: 36
    Accessible.name: tooltip
    ShellToolTip {
        visible: root.hovered && root.visible && root.tooltip.length > 0
        text: root.tooltip
        delay: 500
    }
    background: Rectangle { radius: width / 2; color: root.down ? "#615070" : root.hovered || root.activeFocus || root.highlighted ? "#443651" : "transparent" }
    contentItem: MaterialSymbol { text: root.symbol; iconSize: 22; color: root.enabled ? "#cba6f7" : "#6c667c"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
}
