pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../globals"

ColumnLayout {
    id: root
    property int compWidth: 38
    property bool captureVisible: false
    signal diagnosticsRequested()
    visible: PrivacyState.microphoneMuted || captureVisible
    spacing: 3
    Layout.alignment: Qt.AlignHCenter
    Connections {
        target: PrivacyState
        function onCaptureActiveChanged() {
            if (PrivacyState.captureActive) captureDelay.restart()
            else { captureDelay.stop(); root.captureVisible = false }
        }
    }
    Component.onCompleted: if (PrivacyState.captureActive) captureDelay.start()
    Timer { id: captureDelay; interval: 300; onTriggered: root.captureVisible = PrivacyState.captureActive }
    SidebarBadge {
        visible: PrivacyState.microphoneMuted
        icon: "mic_off"
        title: "Microphone muted"
        detail: "Default input · Click to unmute"
        accent: "#f38ba8"
        onClicked: PrivacyState.toggleMicrophone()
    }
    SidebarBadge {
        visible: root.captureVisible
        icon: "screen_record"
        title: "Screen capture active"
        detail: PrivacyState.targets.length ? PrivacyState.targets.join("\n") : "Screen sharing or recording detected"
        accent: "#f38ba8"
        onClicked: root.diagnosticsRequested()
    }
}
