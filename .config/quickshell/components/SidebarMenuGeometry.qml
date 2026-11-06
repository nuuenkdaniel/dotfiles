import QtQuick

// Animate the surface, not its layout's changing implicit measurements. In
// particular, bottom-clamped y must use the destination height rather than the
// animated height, or the position animation chases a new target every frame.
Item {
    id: root
    property bool animateChanges: false
    property real targetWidth: 240
    property real targetHeight: 0
    property real anchorY: 0
    property real availableHeight: 1080
    property int duration: 500
    property bool initialized: false
    readonly property real targetTop: Math.max(0, Math.min(anchorY - 15, availableHeight - Math.max(0, targetHeight)))
    readonly property bool running: morph.running
    Component.onCompleted: { initialized = true; snap() }
    onTargetWidthChanged: geometryChanged()
    onTargetHeightChanged: geometryChanged()
    onTargetTopChanged: geometryChanged()

    function snap() {
        if (!initialized) return
        morph.stop()
        width = Math.max(1, targetWidth)
        height = Math.max(0, targetHeight)
        y = targetTop
    }
    onAnimateChangesChanged: if (!animateChanges) snap()

    function geometryChanged() {
        if (!initialized) return
        if (animateChanges) Qt.callLater(root.updateGeometry)
        else snap()
    }
    function updateGeometry() {
        if (!animateChanges) { snap(); return }
        const nextWidth = Math.max(1, targetWidth)
        const nextHeight = Math.max(0, targetHeight)
        if (width === nextWidth && height === nextHeight && y === targetTop) return
        // Coalesce model/layout updates, then retarget all three properties from
        // their current values on one animation clock, including rapid reversals.
        morph.stop()
        horizontalSize.to = nextWidth
        verticalSize.to = nextHeight
        position.to = targetTop
        morph.start()
    }
    ParallelAnimation {
        id: morph
        NumberAnimation { id: horizontalSize; target: root; property: "width"; duration: root.duration; easing.type: Easing.OutExpo }
        NumberAnimation { id: verticalSize; target: root; property: "height"; duration: root.duration; easing.type: Easing.OutExpo }
        NumberAnimation { id: position; target: root; property: "y"; duration: root.duration; easing.type: Easing.OutExpo }
    }
}
