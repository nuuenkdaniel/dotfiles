pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "ShellUtils.js" as Utils

Singleton {
    id: root
    readonly property bool microphoneMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false
    readonly property bool microphoneAvailable: !!Pipewire.defaultAudioSource?.audio
    property var captureCounts: ({})
    property bool hasV2Events: false
    property bool legacyCapture: false
    readonly property var targets: Object.keys(captureCounts).map(key => key.split(",").slice(1).join(","))
    readonly property bool captureActive: hasV2Events ? Object.keys(captureCounts).length > 0 : legacyCapture
    readonly property string captureBackend: "Hyprland IPC events (no polling)"
    readonly property string coverage: "Listens only to capture events since the shell loaded. Captures already running before startup/reload, captures bypassing Hyprland, and browser-tab-only sharing may not be detected."

    function toggleMicrophone() {
        if (microphoneAvailable) Pipewire.defaultAudioSource.audio.muted = !microphoneMuted
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSource] }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "screencastv2") {
                root.hasV2Events = true
                root.captureCounts = Utils.captureEvent(root.captureCounts, event.data)
            } else if (event.name === "screencast" && !root.hasV2Events) {
                root.legacyCapture = event.data.split(",")[0] === "1"
            }
        }
    }
    IpcHandler {
        target: "microphone"
        function toggle(): void { root.toggleMicrophone() }
    }
}
