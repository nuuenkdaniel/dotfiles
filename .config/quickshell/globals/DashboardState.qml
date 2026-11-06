pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool opened: false
    property string screenName: ""
    property int sidebarWidth: 55
    property int tab: 0
    property bool ready: false
    property string error: ""
    readonly property bool weatherEnabled: preferences.weatherEnabled
    readonly property bool autoLocation: preferences.autoLocation
    readonly property bool locating: locator.running
    property bool locationAttempted: false
    property bool acceptLocationResult: false
    property int locationRevision: 0
    property string locationStatus: "Auto-detection runs once at startup when weather is enabled."
    onReadyChanged: if (ready) Qt.callLater(root.locateOnStartup)
    onAutoLocationChanged: {
        if (autoLocation) Qt.callLater(root.locateOnStartup)
        else { acceptLocationResult = false; locator.running = false; locationStatus = "Automatic location detection is off." }
    }
    onWeatherEnabledChanged: {
        if (weatherEnabled) Qt.callLater(root.locateOnStartup)
        else { acceptLocationResult = false; locator.running = false; locationStatus = "Weather is disabled; saved location kept." }
    }
    readonly property string locationName: preferences.locationName
    readonly property real latitude: preferences.latitude
    readonly property real longitude: preferences.longitude
    readonly property string units: preferences.units
    readonly property string filesystem: preferences.filesystem
    readonly property string avatar: preferences.avatar
    readonly property bool reducedMotion: preferences.reducedMotion
    readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/dashboard"
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../bin/dashboard.py").toString().replace("file://", ""))

    function toggle(name, width) {
        if (opened && screenName === name) { opened = false; return }
        opened = false
        screenName = name
        sidebarWidth = width
        tab = 0
        opened = true
    }
    function setPreference(key, value) {
        if (!ready) return
        if (["weatherEnabled", "autoLocation", "locationName", "latitude", "longitude", "units", "filesystem", "avatar", "reducedMotion"].includes(key))
            preferences[key] = value
    }
    function selectLocation(location) {
        if (!ready) return
        acceptLocationResult = false
        locator.running = false
        locationAttempted = true
        applyLocation(location)
        locationStatus = "Manual location selected; retained until the next startup check."
        preferences.weatherEnabled = true
    }
    function applyLocation(location) {
        preferences.latitude = location.latitude
        preferences.longitude = location.longitude
        preferences.locationName = location.name
        locationRevision++
    }
    function locateOnStartup() {
        if (!ready || !autoLocation || !weatherEnabled) return
        if (locationAttempted) {
            if (!locator.running) locationStatus = "Startup check already attempted; saved location kept until restart."
            return
        }
        locationAttempted = true
        acceptLocationResult = true
        locationStatus = "Checking VPN and network status…"
        locator.running = true
    }
    Process {
        id: locator
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../bin/locate.py").toString().replace("file://", ""))]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.acceptLocationResult || !root.autoLocation || !root.weatherEnabled) return
                root.acceptLocationResult = false
                try {
                    const result = JSON.parse(text)
                    root.locationStatus = (result.reused ? "Earlier startup check: " : "") + (result.message || "Location unavailable; saved location kept.")
                    if (result.location && !result.reused) root.applyLocation(result.location)
                } catch (error) { root.locationStatus = "Location unavailable; saved location kept." }
            }
        }
        onExited: (code, status) => {
            root.acceptLocationResult = false
            if (code !== 0 && root.autoLocation && root.weatherEnabled)
                root.locationStatus = "Location check stopped; saved location kept."
        }
    }
    Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", root.directory]
        onExited: (code, status) => {
            if (code === 0) file.path = root.directory + "/settings.json"
            else root.error = "Could not create dashboard settings directory"
        }
    }
    Timer { id: save; interval: 200; onTriggered: file.writeAdapter() }
    FileView {
        id: file
        printErrors: false
        atomicWrites: true
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) root.ready = true
            else root.error = "Could not read dashboard settings; existing file left untouched"
        }
        onSaveFailed: error => root.error = "Could not save dashboard settings"
        onAdapterUpdated: if (root.ready) save.restart()
        JsonAdapter {
            id: preferences
            property bool weatherEnabled: false
            property bool autoLocation: true
            property string locationName: ""
            property real latitude: 0
            property real longitude: 0
            property string units: "celsius"
            property string filesystem: "/"
            property string avatar: ""
            property bool reducedMotion: false
        }
    }
}
