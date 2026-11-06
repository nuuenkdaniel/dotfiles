pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    id: root
    property bool opened: false
    property bool reducedMotion: false
    property bool presented: false
    property real progress: 0
    readonly property bool running: animation.running

    onOpenedChanged: if (animation) animate()
    Component.onCompleted: if (opened) animate()

    function animate() {
        // Presentation is latched until closing FINISHES. Stopping/reversing an
        // animation must never unmap the window or recreate its Loader contents.
        if (opened) presented = true
        animation.stop()
        animation.to = opened ? 1 : 0
        animation.duration = reducedMotion ? 130 : opened ? 460 : 260
        animation.easing.type = reducedMotion ? Easing.OutCubic : opened ? Easing.OutBack : Easing.InCubic
        animation.start()
    }

    function reset() {
        animation.stop()
        progress = 0
        presented = false
        if (opened) animate()
    }

    property NumberAnimation animation: NumberAnimation {
        target: root
        property: "progress"
        easing.overshoot: .65
        onFinished: if (!root.opened) root.presented = false
    }
}
