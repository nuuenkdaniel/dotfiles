pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../globals/DashboardUtils.js" as Utils

RowLayout {
    id: root
    required property date now
    property int month: now.getMonth()
    property int year: now.getFullYear()
    spacing: 12

    function moveMonth(step) {
        const next = new Date(year, month + step, 1, 12)
        year = next.getFullYear()
        month = next.getMonth()
    }
    DashboardCard {
        Layout.preferredWidth: 96
        Layout.fillHeight: true
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            DashboardLabel { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDateTime(root.now, "HH"); font.pixelSize: 34; color: "#cba6f7"; font.weight: Font.Medium }
            Row { Layout.alignment: Qt.AlignHCenter; spacing: 5; Repeater { model: 3; Rectangle { width: 4; height: 4; radius: 2; color: "#a48bc5" } } }
            DashboardLabel { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDateTime(root.now, "mm"); font.pixelSize: 34; font.weight: Font.Medium }
            DashboardLabel { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8; text: Qt.formatDateTime(root.now, "ddd, d"); color: "#b7abc8"; font.pixelSize: 12 }
        }
    }
    DashboardCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                DashboardIconButton { symbol: "chevron_left"; tooltip: "Previous month"; implicitWidth: 28; implicitHeight: 28; onClicked: root.moveMonth(-1) }
                DashboardLabel { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy"); font.pixelSize: 12; font.bold: true }
                DashboardIconButton { symbol: "chevron_right"; tooltip: "Next month"; implicitWidth: 28; implicitHeight: 28; onClicked: root.moveMonth(1) }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 1; columnSpacing: 1
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    DashboardLabel { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: "#b7abc8"; font.pixelSize: 11 }
                }
                Repeater {
                    model: Utils.calendar(root.year, root.month)
                    Item {
                        id: cell
                        required property var modelData
                        readonly property bool today: modelData.day === root.now.getDate() && modelData.month === root.now.getMonth() && modelData.year === root.now.getFullYear()
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumHeight: 22
                        Rectangle { anchors.centerIn: parent; width: Math.min(27, parent.width); height: width; radius: width / 2; visible: cell.today; color: "#cba6f7" }
                        DashboardLabel { anchors.centerIn: parent; text: cell.modelData.day; font.pixelSize: 12; color: cell.today ? "#21182d" : cell.modelData.month === root.month ? "#cdd6f4" : "#716a81" }
                    }
                }
            }
        }
    }
}
