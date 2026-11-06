pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../globals"

ColumnLayout {
    id: root
    property bool active: false
    property var locations: []
    property var filesystems: ["/"]
    property string searchError: ""
    property string searchedQuery: ""
    spacing: 12
    onActiveChanged: {
        if (active && !mountReader.running) mountReader.running = true
        if (!active) searchReader.running = false
    }
    DashboardLabel { text: "Dashboard"; font.pixelSize: 24; font.bold: true }
    DashboardLabel { Layout.fillWidth: true; text: "Weather, storage, and appearance for your top dropdown."; color: "#9399b2"; wrapMode: Text.Wrap }
    Flickable {
        id: scroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: fields.implicitHeight
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: fields
            width: scroll.width - 12
            spacing: 12
            enabled: DashboardState.ready
            DashboardLabel { text: "Weather"; color: "#cba6f7"; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                SettingsButton { text: DashboardState.weatherEnabled ? "Enabled" : "Disabled"; selected: DashboardState.weatherEnabled; onClicked: DashboardState.setPreference("weatherEnabled", !DashboardState.weatherEnabled) }
                Item { Layout.fillWidth: true }
                SettingsButton { text: "°C"; selected: DashboardState.units === "celsius"; onClicked: DashboardState.setPreference("units", "celsius") }
                SettingsButton { text: "°F"; selected: DashboardState.units === "fahrenheit"; onClicked: DashboardState.setPreference("units", "fahrenheit") }
            }
            DashboardLabel { Layout.fillWidth: true; text: DashboardState.locationName || "No location selected"; wrapMode: Text.Wrap; elide: Text.ElideNone }
            SettingsButton {
                text: DashboardState.autoLocation ? "Startup auto-location: on" : "Startup auto-location: off"
                selected: DashboardState.autoLocation
                onClicked: DashboardState.setPreference("autoLocation", !DashboardState.autoLocation)
            }
            DashboardLabel { Layout.fillWidth: true; text: DashboardState.locating ? "Checking network / location…" : DashboardState.locationStatus; color: "#b7abc8"; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideNone }
            DashboardLabel { Layout.fillWidth: true; text: "At most one IP-location lookup per Quickshell process, only when weather is enabled. Ordinary Tailscale mesh is allowed; exit nodes, other VPNs/proxies, uncertain checks, and offline starts keep your saved location. No polling or retry on network changes. ipapi.co receives your public IP; unusual VPNs/proxies can evade detection."; color: "#9399b2"; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideNone }
            RowLayout {
                Layout.fillWidth: true
                Field { id: city; Layout.fillWidth: true; placeholderText: "Search city or postal code"; onAccepted: root.search() }
                SettingsButton { text: searchReader.running ? "Searching…" : "Search"; enabled: !searchReader.running && city.text.trim().length >= 2; onClicked: root.search() }
            }
            Repeater {
                model: root.locations
                AbstractButton {
                    id: locationButton
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Math.max(38, locationLabel.implicitHeight + 16)
                    background: Rectangle { radius: 8; color: locationButton.hovered || locationButton.activeFocus ? "#40354f" : "#282535" }
                    contentItem: DashboardLabel { id: locationLabel; text: locationButton.modelData.name; wrapMode: Text.Wrap; elide: Text.ElideNone; padding: 8 }
                    onClicked: { DashboardState.selectLocation(modelData); root.locations = []; city.text = "" }
                }
            }
            DashboardLabel { Layout.fillWidth: true; visible: root.searchError.length > 0; text: root.searchError; color: "#f38ba8"; wrapMode: Text.Wrap; elide: Text.ElideNone }
            DashboardLabel { Layout.fillWidth: true; text: "Manual search sends the city name to Open-Meteo / GeoNames. Weather sends your selected coordinates to Open-Meteo and is cached for 30 minutes. Weather refreshes only on opening; the optional startup location check can run while closed."; color: "#9399b2"; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideNone }
            DashboardLabel { text: "Storage filesystem"; color: "#cba6f7"; font.bold: true; Layout.topMargin: 6 }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.filesystems
                    SettingsButton {
                        required property string modelData
                        text: modelData
                        selected: DashboardState.filesystem === modelData
                        onClicked: DashboardState.setPreference("filesystem", modelData)
                    }
                }
            }
            DashboardLabel { Layout.fillWidth: true; text: "Selected: " + DashboardState.filesystem + ". Shows filesystem used/total, not a sum of drives. Only local filesystems are listed."; color: "#9399b2"; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideNone }
            DashboardLabel { text: "Appearance"; color: "#cba6f7"; font.bold: true; Layout.topMargin: 6 }
            DashboardLabel { text: "Avatar image (absolute local path)"; color: "#bac2de" }
            RowLayout {
                Layout.fillWidth: true
                Field { id: avatar; Layout.fillWidth: true; text: DashboardState.avatar; placeholderText: "/home/…/avatar.png" }
                SettingsButton { text: "Apply"; enabled: avatar.text.trim() === "" || avatar.text.trim().startsWith("/"); onClicked: DashboardState.setPreference("avatar", avatar.text.trim()) }
            }
            DashboardLabel { Layout.fillWidth: true; text: "Leave blank to use ~/.face or your initial. Images stay local."; color: "#9399b2"; font.pixelSize: 11; wrapMode: Text.Wrap }
            SettingsButton { text: DashboardState.reducedMotion ? "Reduced motion: on" : "Reduced motion: off"; selected: DashboardState.reducedMotion; onClicked: DashboardState.setPreference("reducedMotion", !DashboardState.reducedMotion) }
            DashboardLabel { Layout.fillWidth: true; text: "CPU and RAM update only while the dashboard is open. No resource history or background monitoring service."; color: "#9399b2"; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideNone }
            DashboardLabel { Layout.fillWidth: true; visible: DashboardState.error.length > 0; text: DashboardState.error; color: "#f38ba8"; wrapMode: Text.Wrap }
        }
    }
    function search() {
        if (searchReader.running || city.text.trim().length < 2) return
        searchedQuery = city.text.trim()
        locations = []
        searchError = ""
        searchReader.command = ["python3", DashboardState.script, "search", searchedQuery]
        searchReader.running = true
    }
    Process {
        id: searchReader
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active) return
                try {
                    const result = JSON.parse(text)
                    root.locations = result.results || []
                    root.searchError = result.error || (root.locations.length ? "" : "No matching locations. Try a nearby city.")
                } catch (error) { root.searchError = "Location search unavailable" }
            }
        }
    }
    Process {
        id: mountReader
        command: ["python3", DashboardState.script, "identity"]
        stdout: StdioCollector { onStreamFinished: { try { root.filesystems = JSON.parse(text).mounts || ["/"] } catch (error) {} } }
    }
    component Field: TextField {
        color: "#cdd6f4"
        placeholderTextColor: "#9399b2"
        font.pixelSize: 12
        selectByMouse: true
        background: Rectangle { implicitHeight: 36; radius: 8; color: "#181825"; border.width: parent.activeFocus ? 1 : 0; border.color: "#cba6f7" }
    }
}
