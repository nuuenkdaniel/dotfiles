pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking

ColumnLayout {
    id: root
    property bool active: false
    property var network: null
    property var details: ({})
    property string requestedInterface: ""
    readonly property bool connected: network?.connected ?? false
    readonly property string interfaceName: network?.device?.name ?? ""
    Layout.fillWidth: true
    spacing: 7
    visible: !!network
    onActiveChanged: {
        if (active) refresh()
        else reader.running = false
    }
    onInterfaceNameChanged: { details = ({}); refresh() }
    onConnectedChanged: { details = ({}); if (!connected) reader.running = false; else refresh() }

    function refresh() {
        if (!active || !connected || !interfaceName || reader.running) return
        requestedInterface = interfaceName
        reader.command = ["python3", decodeURIComponent(Qt.resolvedUrl("../bin/shell-info.py").toString().replace("file://", "")), "network", interfaceName]
        reader.running = true
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: [
                ["Network", root.network?.name ?? ""],
                ["Signal", Math.round((root.network?.signalStrength ?? 0) * 100) + "%"],
                ["Security", root.network ? WifiSecurityType.toString(root.network.security) : ""],
                ["Interface", root.interfaceName || "Not reported"]
            ].concat(root.connected ? [
                ["IPv4", (root.details.ipv4 ?? []).join(", ") || "Not assigned"],
                ["IPv6", (root.details.ipv6 ?? []).join(", ") || "Not assigned"],
                ["Gateway", root.details.gateway || "Not assigned"],
                ["DNS", (root.details.dns ?? []).join(", ") || "Not reported"]
            ] : [["Status", "Not connected"]])
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Text { Layout.preferredWidth: 70; text: modelData[0]; color: "#9399b2"; font.pixelSize: 11 }
                Text { Layout.fillWidth: true; text: modelData[1]; textFormat: Text.PlainText; color: "#cdd6f4"; font.pixelSize: 11; wrapMode: Text.Wrap }
            }
        }
        Text { Layout.fillWidth: true; visible: !!root.details.error; text: root.details.error ?? ""; color: "#f38ba8"; font.pixelSize: 11; wrapMode: Text.Wrap }
    }
    Timer { interval: 5000; running: root.active && root.connected; repeat: true; onTriggered: root.refresh() }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active || !root.connected || root.requestedInterface !== root.interfaceName) return
                try {
                    const details = JSON.parse(text)
                    if (!details.interface || details.interface === root.interfaceName) root.details = details
                } catch (error) { root.details = ({ error: "Could not read connection details" }) }
            }
        }
    }
}
