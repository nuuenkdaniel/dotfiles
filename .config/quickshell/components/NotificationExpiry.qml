import QtQuick

Item {
    id: root
    property int duration: 10000
    property bool paused: false
    property bool active: true
    property real remaining: duration
    property double deadline: 0
    property bool initialized: false
    signal expired()

    function arm() {
        if (!initialized || !active || paused || duration <= 0) return
        deadline = Date.now() + remaining
        alarm.interval = Math.max(1, Math.ceil(remaining))
        alarm.restart()
    }
    function restart() {
        alarm.stop()
        remaining = duration
        arm()
    }
    Component.onCompleted: { initialized = true; restart() }
    onDurationChanged: if (initialized) restart()
    onActiveChanged: { if (!active) alarm.stop(); else restart() }
    onPausedChanged: {
        if (paused) {
            if (alarm.running) remaining = Math.max(0, deadline - Date.now())
            alarm.stop()
        } else arm()
    }
    Timer {
        id: alarm
        onTriggered: {
            root.remaining = Math.max(0, root.deadline - Date.now())
            if (root.remaining > 0) root.arm()
            else root.expired()
        }
    }
}
