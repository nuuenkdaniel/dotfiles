pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../globals/DashboardUtils.js" as Utils

ToolTipSurface {
    id: root
    property date date: new Date()
    implicitWidth: 288
    implicitHeight: 292
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: Qt.formatDate(root.date, "MMMM yyyy")
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: "#cba6f7"
            }
            Text {
                text: Qt.formatDate(root.date, "dddd, d MMMM")
                font.pixelSize: 11
                color: "#a69ab9"
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            columnSpacing: 3
            rowSpacing: 3
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 11
                    color: "#a69ab9"
                }
            }
            Repeater {
                objectName: "calendarDays"
                model: Utils.calendar(root.date.getFullYear(), root.date.getMonth())
                Item {
                    id: day
                    required property var modelData
                    readonly property bool today: modelData.year === root.date.getFullYear() && modelData.month === root.date.getMonth() && modelData.day === root.date.getDate()
                    readonly property bool thisMonth: modelData.month === root.date.getMonth()
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 24
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26; radius: 13
                        visible: day.today
                        color: "#cba6f7"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: day.modelData.day
                        font.pixelSize: 12
                        font.weight: day.today ? Font.DemiBold : Font.Normal
                        color: day.today ? "#21182d" : day.thisMonth ? "#cdd6f4" : "#716a81"
                    }
                }
            }
        }
    }
}
