pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

PopupWindow {
    id: root
    required property Item anchorItem
    property bool hovered: false
    property date date: new Date()
    property bool ready: false
    onHoveredChanged: {
        if (hovered) delay.restart()
        else { delay.stop(); ready = false }
    }
    Timer { id: delay; interval: 350; onTriggered: root.ready = true }
    anchor.item: anchorItem
    anchor.rect.x: anchorItem.width + 14
    anchor.rect.y: (anchorItem.height - implicitHeight) / 2
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
    visible: hovered && ready && anchorItem.visible
    implicitWidth: 288
    implicitHeight: 292
    color: "transparent"
    grabFocus: false
    mask: Region {}
    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: CalendarPreview { date: root.date }
    }
}
