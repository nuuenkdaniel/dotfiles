pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool ready: false
    property int current: 0
    property int maximum: 1
    property string device: ""
    property int visiblePanels: 0
    property bool osdVisible: false
    property int requestedPercent: 0
    property int writingPercent: 0
    property string error: ""
    readonly property real brightness: maximum > 0 ? current / maximum : 0
    signal levelChanged()
    Component.onCompleted: refresh()

    function refresh() {
        if (reader.running) return
        reader.initialRead = !ready
        reader.command = ready ? ["cat", "/sys/class/backlight/" + device + "/brightness"] : ["brightnessctl", "-m"]
        reader.running = true
    }

    function setFraction(value) {
        if (!ready) return
        requestedPercent = Math.round(Math.max(0, Math.min(1, value)) * 100)
        current = Math.round(maximum * requestedPercent / 100)
        if (!writeTimer.running) writeTimer.start()
        levelChanged()
    }

    Timer {
        interval: 500
        running: root.visiblePanels > 0 || root.osdVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        id: writeTimer
        interval: 60
        onTriggered: {
            if (writer.running) { restart(); return }
            root.writingPercent = root.requestedPercent
            writer.command = ["brightnessctl", "--device", root.device, "set", root.writingPercent + "%"]
            writer.running = true
        }
    }
    Process {
        id: reader
        property bool initialRead: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (writer.running || writeTimer.running) return
                const fields = text.trim().split("\n")[0].split(",")
                const current = reader.initialRead ? Number(fields[2]) : Number(text.trim())
                const maximum = reader.initialRead ? Number(fields[4]) : root.maximum
                if (!text.trim() || (reader.initialRead && fields.length < 5) || !Number.isFinite(current) || !(maximum > 0)) return
                const changed = root.ready && (root.current !== current || root.maximum !== maximum)
                root.current = current
                root.maximum = maximum
                if (reader.initialRead) root.device = fields[0]
                root.ready = true
                root.error = ""
                if (changed) root.levelChanged()
            }
        }
        onExited: (code, status) => { if (code !== 0) { root.ready = false; root.error = "No accessible display backlight (brightnessctl)" } }
    }
    Process {
        id: writer
        stderr: StdioCollector { id: writerError }
        onExited: (code, status) => {
            root.error = code === 0 ? "" : writerError.text.trim() || "Brightness change failed"
            if (root.requestedPercent !== root.writingPercent) writeTimer.restart()
            else root.refresh()
        }
    }
}
