pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../globals"
import "../globals/DashboardUtils.js" as Utils

Item {
    id: root
    required property DashboardData dataSource
    property bool expanded: false
    readonly property var readings: [
        {name: "CPU", icon: "developer_board", value: dataSource.cpu, detail: dataSource.cpu < 0 ? "Sampling…" : "Processor utilization", accent: "#cba6f7", error: dataSource.resourceError},
        {name: "Memory", icon: "memory", value: dataSource.ram.total ? dataSource.ram.used / dataSource.ram.total : -1, detail: Utils.bytes(dataSource.ram.used) + " of " + Utils.bytes(dataSource.ram.total), accent: "#89b4fa", error: dataSource.resourceError},
        {name: "Storage", icon: "hard_drive", value: dataSource.storage.total ? dataSource.storage.used / dataSource.storage.total : -1, detail: Utils.bytes(dataSource.storage.used) + " of " + Utils.bytes(dataSource.storage.total), accent: "#a6e3a1", error: dataSource.storageError}
    ]

    DashboardCard {
        anchors.fill: parent
        visible: !root.expanded
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16
            DashboardLabel { text: "Resources"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#b7abc8" }
            Repeater {
                model: 3
                ColumnLayout {
                    id: compact
                    required property int index
                    readonly property var reading: root.readings[index]
                    Layout.fillWidth: true
                    spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        DashboardLabel { Layout.fillWidth: true; text: compact.reading.name; font.pixelSize: 11; color: "#b7abc8" }
                        DashboardLabel { text: compact.reading.value < 0 ? "—" : Math.round(compact.reading.value * 100) + "%"; font.pixelSize: 13; color: compact.reading.accent }
                    }
                    DashboardMeter { Layout.fillWidth: true; value: compact.reading.value; accent: compact.reading.accent }
                    HoverHandler { id: compactHover }
                    ShellToolTip {
                        visible: compactHover.hovered && root.visible && !root.expanded
                        text: compact.reading.error || compact.reading.detail
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
    RowLayout {
        anchors.fill: parent
        spacing: 12
        visible: root.expanded
        Repeater {
            model: 3
            DashboardCard {
                id: card
                required property int index
                readonly property var reading: root.readings[index]
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        MaterialSymbol { text: card.reading.icon; iconSize: 18; color: card.reading.accent }
                        DashboardLabel { Layout.fillWidth: true; text: card.reading.name; font.pixelSize: 12; color: "#b7abc8" }
                        DashboardLabel { visible: card.reading.name === "Storage"; text: DashboardState.filesystem; color: "#958aa8"; font.pixelSize: 10 }
                    }
                    Item { Layout.fillHeight: true }
                    DashboardLabel { text: card.reading.value < 0 ? "—" : Math.round(card.reading.value * 100) + "%"; font.pixelSize: 32; font.weight: Font.Medium; color: "#e0d9ec" }
                    DashboardLabel { Layout.fillWidth: true; text: card.reading.error ? "Unavailable" : card.reading.detail; font.pixelSize: 11; color: "#958aa8" }
                    Item { implicitHeight: 2 }
                    DashboardMeter { Layout.fillWidth: true; value: card.reading.value; accent: card.reading.accent }
                    HoverHandler { id: detailHover }
                    ShellToolTip {
                        visible: detailHover.hovered && root.visible && root.expanded
                        text: card.reading.error || card.reading.detail
                    }
                }
            }
        }
    }
}
