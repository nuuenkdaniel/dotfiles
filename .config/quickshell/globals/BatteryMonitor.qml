pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "ShellUtils.js" as Utils

Singleton {
    id: root
    property bool ready: false
    readonly property var battery: UPower.displayDevice
    property string error: ""

    function check() {
        if (!root.ready || !battery.ready || !battery.isPresent || !battery.isLaptopBattery) return
        if (!UPower.onBattery) {
            if (warningState.lastBand !== 25) warningState.lastBand = 25
            return
        }
        const percent = battery.percentage * 100
        const band = Utils.warningBand(percent)
        if (band === null || band >= warningState.lastBand) return
        // Skip intermediate warnings after a large drop/suspend; send just one.
        warningState.lastBand = band
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-i", "battery-caution",
            "-u", percent <= 5 ? "critical" : "normal", "Battery low · " + Math.round(percent) + "%",
            "Connect your charger. Another warning will appear after the next 5% drop."])
    }

    Connections {
        target: root.battery
        function onPercentageChanged() { root.check() }
        function onReadyChanged() { root.check() }
    }
    Connections { target: UPower; function onOnBatteryChanged() { root.check() } }
    Timer { id: saveTimer; interval: 100; onTriggered: stateFile.writeAdapter() }
    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-battery-warnings.json"
        printErrors: false
        onLoaded: {
            root.ready = true
            if (![0, 5, 10, 15, 20, 25].includes(warningState.lastBand)) warningState.lastBand = 25
            root.check()
        }
        onLoadFailed: error => {
            root.ready = true
            if (error !== FileViewError.FileNotFound) root.error = "Battery warning state could not be read"
            root.check()
        }
        onAdapterUpdated: if (root.ready) saveTimer.restart()
        JsonAdapter { id: warningState; property int lastBand: 25 }
    }
}
