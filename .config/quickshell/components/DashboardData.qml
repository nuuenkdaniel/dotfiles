pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../globals"
import "../globals/DashboardUtils.js" as Utils

Item {
    id: root
    property bool active: true
    property var identity: ({})
    property var ram: ({})
    property var storage: ({})
    property var previousCpu: null
    property real cpu: -1
    property var weather: ({})
    property string resourceError: ""
    property string storageError: ""
    property string weatherError: ""
    property string weatherKey: ""
    property string requestedFilesystem: ""
    readonly property bool weatherBusy: weatherReader.running

    function parse(text) {
        try { return JSON.parse(text) } catch (error) { return {error: "Could not read dashboard data"} }
    }
    function refreshResources() { if (active && !resourceReader.running) resourceReader.running = true }
    function refreshStorage() {
        if (!active || storageReader.running) return
        requestedFilesystem = DashboardState.filesystem
        storageReader.command = ["python3", DashboardState.script, "storage", requestedFilesystem]
        storageReader.running = true
    }
    function refreshWeather() {
        if (!active || !DashboardState.ready || DashboardState.locating || !DashboardState.weatherEnabled || !DashboardState.locationName || weatherReader.running) return
        weatherKey = DashboardState.latitude + "," + DashboardState.longitude
        weatherReader.command = ["python3", DashboardState.script, "weather", String(DashboardState.latitude), String(DashboardState.longitude)]
        weatherReader.running = true
    }
    Component.onCompleted: { identityReader.running = true; refreshStorage(); refreshWeather() }
    onActiveChanged: {
        if (!active) { resourceReader.running = false; storageReader.running = false; weatherReader.running = false; identityReader.running = false }
        else Qt.callLater(root.resume)
    }
    function resume() {
        if (!active) return
        if (!identity.user && !identityReader.running) identityReader.running = true
        refreshStorage()
        refreshWeather()
    }
    Connections {
        target: DashboardState
        function onReadyChanged() { root.refreshWeather() }
        function onLocatingChanged() { if (!DashboardState.locating) Qt.callLater(root.refreshWeather) }
        function onLocationRevisionChanged() {
            if (!root.active) return
            weatherReader.running = false
            root.weather = ({})
            root.weatherError = ""
            Qt.callLater(root.refreshWeather)
        }
        function onWeatherEnabledChanged() {
            if (!root.active) return
            if (DashboardState.weatherEnabled) Qt.callLater(root.refreshWeather)
            else { weatherReader.running = false; root.weather = ({}) }
        }
        function onFilesystemChanged() { if (root.active) { root.storage = ({}); root.refreshStorage() } }
    }
    Timer { interval: 2000; running: root.active; triggeredOnStart: true; repeat: true; onTriggered: root.refreshResources() }
    Timer { interval: 30000; running: root.active; repeat: true; onTriggered: root.refreshStorage() }
    Process {
        id: resourceReader
        command: ["python3", DashboardState.script, "resources"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active) return
                const result = root.parse(text)
                root.resourceError = result.error || ""
                if (result.error) return
                root.cpu = Utils.cpuUsage(root.previousCpu, result.cpu)
                root.previousCpu = result.cpu
                root.ram = result.ram
            }
        }
    }
    Process {
        id: storageReader
        onExited: if (root.active && root.requestedFilesystem !== DashboardState.filesystem) Qt.callLater(root.refreshStorage)
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active || root.requestedFilesystem !== DashboardState.filesystem) return
                const result = root.parse(text)
                root.storageError = result.error || ""
                root.storage = result.error ? ({}) : result
            }
        }
    }
    Process {
        id: identityReader
        command: ["python3", DashboardState.script, "identity"]
        stdout: StdioCollector { onStreamFinished: if (root.active) root.identity = root.parse(text) }
    }
    Process {
        id: weatherReader
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active || root.weatherKey !== DashboardState.latitude + "," + DashboardState.longitude) return
                const result = root.parse(text)
                root.weatherError = result.error || ""
                root.weather = result
            }
        }
    }
}
