pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../globals"

ColumnLayout {
    id: root
    property bool active: false
    property var info: ({})
    property string error: ""
    signal closeRequested()
    spacing: 12
    onActiveChanged: if (active) refresh()

    function refresh() { if (!reader.running) reader.running = true }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "About & diagnostics"; color: "#cdd6f4"; font.pixelSize: 24; font.bold: true }
        SettingsButton { text: "Refresh"; enabled: !reader.running; onClicked: root.refresh() }
    }
    Text { Layout.fillWidth: true; text: "Read-only checks · No serial numbers, passwords, or full configuration files are collected."; color: "#9399b2"; font.pixelSize: 12; wrapMode: Text.Wrap }
    Flickable {
        id: scroll
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentHeight: content.implicitHeight
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: content
            width: scroll.width - 12
            spacing: 9
            Repeater {
                model: [["System", root.info.os], ["Laptop", root.info.model], ["Kernel", root.info.kernel], ["Quickshell", root.info.quickshell], ["Hyprland", root.info.hyprland]]
                delegate: Detail { required property var modelData; label: modelData[0]; value: modelData[1] ?? "Reading…" }
            }
            Text { text: "Services"; color: "#cba6f7"; font.pixelSize: 14; font.bold: true; Layout.topMargin: 8 }
            Repeater {
                model: Object.keys(root.info.services ?? ({}))
                delegate: Detail {
                    required property string modelData
                    label: modelData
                    value: root.info.services[modelData]
                    valueColor: value === "active" ? "#a6e3a1" : "#9399b2"
                }
            }
            Text { text: "Privacy indicators"; color: "#cba6f7"; font.pixelSize: 14; font.bold: true; Layout.topMargin: 8 }
            Detail { label: "Default microphone"; value: !PrivacyState.microphoneAvailable ? "Unavailable" : PrivacyState.microphoneMuted ? "Muted" : "Not muted" }
            Detail { label: "Screen capture"; value: PrivacyState.captureActive ? "Detected" : "No capture detected"; valueColor: PrivacyState.captureActive ? "#f38ba8" : "#bac2de" }
            Detail { label: "Capture backend"; value: PrivacyState.captureBackend }
            Text { Layout.fillWidth: true; text: PrivacyState.coverage; color: "#9399b2"; font.pixelSize: 11; wrapMode: Text.Wrap }
            Text { text: "Tools"; color: "#cba6f7"; font.pixelSize: 14; font.bold: true; Layout.topMargin: 8 }
            Repeater {
                model: Object.keys(root.info.tools ?? ({}))
                delegate: Detail { required property string modelData; label: modelData; value: root.info.tools[modelData] ? "Available" : "Missing" }
            }
            Detail { label: "Notification history"; value: NotificationCenter.entries.length + " saved (maximum 100)" }
            Text { Layout.fillWidth: true; visible: NotificationCenter.error.length > 0; text: NotificationCenter.error; color: "#f38ba8"; font.pixelSize: 11; wrapMode: Text.Wrap }
            Text { Layout.fillWidth: true; visible: BatteryMonitor.error.length > 0; text: BatteryMonitor.error; color: "#f38ba8"; font.pixelSize: 11; wrapMode: Text.Wrap }
            Text { Layout.fillWidth: true; visible: root.error.length > 0; text: root.error; color: "#f38ba8"; font.pixelSize: 11; wrapMode: Text.Wrap }
            SettingsButton {
                text: "Copy diagnostics"
                onClicked: Quickshell.clipboardText = JSON.stringify({
                    system: root.info, microphoneMuted: PrivacyState.microphoneMuted,
                    captureDetected: PrivacyState.captureActive, captureBackend: PrivacyState.captureBackend,
                    captureCoverage: PrivacyState.coverage
                }, null, 2)
            }
            SettingsButton {
                visible: !!root.info.batteryFeature
                text: "Battery feature cleanup…"
                onClicked: {
                    const script = decodeURIComponent(Qt.resolvedUrl("../bin/uninstall-power.sh").toString().replace("file://", ""))
                    Quickshell.execDetached(["kitty", "--hold", "bash", script])
                    root.closeRequested()
                }
            }
        }
    }
    Process {
        id: reader
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../bin/shell-info.py").toString().replace("file://", ""))]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text); root.error = root.info.error ?? "" } catch (error) { root.error = "Could not read diagnostics" } } }
    }
    component Detail: RowLayout {
        id: detail
        property string label
        property string value
        property color valueColor: "#bac2de"
        Layout.fillWidth: true
        spacing: 12
        Text { Layout.preferredWidth: 145; text: detail.label; color: "#9399b2"; font.pixelSize: 11; wrapMode: Text.Wrap }
        Text { Layout.fillWidth: true; text: detail.value; textFormat: Text.PlainText; color: detail.valueColor; font.pixelSize: 11; wrapMode: Text.Wrap }
    }
}
