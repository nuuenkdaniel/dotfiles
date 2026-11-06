pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../globals"
import "../globals/DashboardUtils.js" as Utils

Item {
    id: root
    property bool active: true
    readonly property date now: ShellClock.now
    readonly property real contentWidth: Math.max(650, width)
    readonly property real pageHeight: DashboardState.tab === 0 ? 340 : 166
    DashboardData { id: data; active: root.active }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 40
            Layout.maximumHeight: 40
            spacing: 16
            ColumnLayout {
                spacing: 3
                DashboardLabel { text: "Dashboard"; font.pixelSize: 19; font.weight: Font.DemiBold }
                DashboardLabel { text: Qt.formatDate(root.now, "dddd, d MMMM"); color: "#958aa8"; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 224
                implicitHeight: 36
                radius: 12
                color: "#171722"
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    Repeater {
                        model: ["Overview", "Performance"]
                        AbstractButton {
                            id: tabButton
                            required property string modelData
                            required property int index
                            width: 106; height: 28
                            Accessible.name: modelData
                            onClicked: DashboardState.tab = index
                            background: Rectangle { radius: 8; color: DashboardState.tab === tabButton.index ? "#3d314d" : tabButton.hovered || tabButton.activeFocus ? "#292532" : "transparent" }
                            contentItem: DashboardLabel { text: tabButton.modelData; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11; color: DashboardState.tab === tabButton.index ? "#dec6fa" : "#958aa8" }
                        }
                    }
                }
            }
        }
        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: root.pageHeight
            clip: true
            contentWidth: root.contentWidth
            contentHeight: root.pageHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Item {
                width: root.contentWidth
                height: root.pageHeight
                Item {
                    id: overview
                    anchors.fill: parent
                    visible: DashboardState.tab === 0
                    readonly property real mainWidth: width
                    readonly property real weatherWidth: mainWidth * .36
                    DashboardCard {
                        x: 0; y: 0
                        width: overview.weatherWidth
                        height: 98
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 12
                            MaterialSymbol { iconSize: 46; color: "#cba6f7"; text: !DashboardState.weatherEnabled || !DashboardState.locationName || data.weather.temperature === undefined ? "partly_cloudy_day" : Utils.weather(data.weather.code, data.weather.isDay)[0] }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                DashboardLabel {
                                    Layout.fillWidth: true
                                    text: data.weather.temperature !== undefined && DashboardState.weatherEnabled ? Math.round(DashboardState.units === "fahrenheit" ? data.weather.temperature * 9 / 5 + 32 : data.weather.temperature) + (DashboardState.units === "fahrenheit" ? "°F" : "°C") : "Weather"
                                    font.pixelSize: 28; font.weight: Font.Medium; color: "#cba6f7"
                                }
                                DashboardLabel { Layout.fillWidth: true; text: !DashboardState.weatherEnabled || !DashboardState.locationName ? "Set location in Settings" : data.weather.temperature !== undefined ? Utils.weather(data.weather.code, data.weather.isDay)[1] + (data.weather.stale ? " · cached" : "") : data.weatherBusy ? "Loading…" : "Unavailable"; font.pixelSize: 11; color: "#b7abc8" }
                                DashboardLabel { Layout.fillWidth: true; text: DashboardState.weatherEnabled ? DashboardState.locationName : ""; color: "#958aa8"; font.pixelSize: 10 }
                            }
                        }
                        HoverHandler { id: weatherHover }
                        ShellToolTip {
                            visible: weatherHover.hovered && root.active
                            text: data.weatherError || (data.weather.fetched ? "Updated " + Qt.formatDateTime(new Date(data.weather.fetched * 1000), "ddd hh:mm") + " · Open-Meteo / GeoNames" : "Configure weather in Settings → Dashboard")
                        }
                    }
                    DashboardCard {
                        x: overview.weatherWidth + 12; y: 0
                        width: overview.mainWidth - x
                        height: 98
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 14
                            Item {
                                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                                Rectangle { anchors.fill: parent; radius: width / 2; color: "#443452" }
                                DashboardLabel { anchors.centerIn: parent; text: (data.identity.user || "?").slice(0, 1).toUpperCase(); font.pixelSize: 28; color: "#cba6f7" }
                                Image { id: avatar; anchors.fill: parent; visible: false; source: DashboardState.avatar ? (DashboardState.avatar.startsWith("/") ? "file://" + DashboardState.avatar : "") : data.identity.avatar ? "file://" + data.identity.avatar : ""; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize.width: 128; sourceSize.height: 128 }
                                Rectangle { id: avatarMask; anchors.fill: parent; radius: width / 2; visible: false }
                                OpacityMask { anchors.fill: parent; source: avatar; maskSource: avatarMask; visible: avatar.status === Image.Ready }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 8
                                DashboardLabel { Layout.fillWidth: true; text: data.identity.os || "Reading system…"; font.pixelSize: 13 }
                                DashboardLabel { Layout.fillWidth: true; text: data.identity.session || ""; color: "#b7abc8"; font.pixelSize: 12 }
                                DashboardLabel { Layout.fillWidth: true; text: data.identity.uptime === undefined ? "" : "Up " + Math.floor(data.identity.uptime / 3600) + "h " + Math.floor(data.identity.uptime % 3600 / 60) + "m"; color: "#958aa8"; font.pixelSize: 11 }
                            }
                        }
                    }
                    DashboardClock {
                        x: 0; y: 110
                        width: overview.mainWidth - 224
                        height: overview.height - y
                        now: root.now
                    }
                    DashboardResources {
                        x: overview.mainWidth - 212; y: 110
                        width: 212
                        height: overview.height - y
                        dataSource: data
                    }
                }
                Item {
                    anchors.fill: parent
                    visible: DashboardState.tab === 1
                    DashboardResources { anchors.fill: parent; expanded: true; dataSource: data }
                }
            }
        }
    }
}
