import QtQuick

QtObject {
    id: root
    property bool opened: false
    property real progress: 0
    readonly property real offset: -28 * (1 - progress)
    readonly property bool running: animation.running
    onOpenedChanged: if (animation) restart()
    Component.onCompleted: if (opened) restart()

    function restart() {
        animation.stop()
        progress = 0
        if (opened) animation.start()
    }
    property NumberAnimation animation: NumberAnimation {
        target: root
        property: "progress"
        from: 0; to: 1
        duration: 200
        easing.type: Easing.OutCubic
    }
}
