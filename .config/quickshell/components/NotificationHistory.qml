pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../globals"
import "../globals/ShellUtils.js" as Utils

ColumnLayout {
    id: root
    property bool active: false
    property bool confirmClear: false
    signal closeRequested()
    readonly property var filtered: NotificationCenter.entries.filter(entry => {
        const query = search.text.trim().toLowerCase()
        return !query || [entry.appName, entry.summary, entry.body].join(" ").toLowerCase().includes(query)
    })
    spacing: 12
    onActiveChanged: if (active) NotificationCenter.markRead()
    Connections { target: NotificationCenter; function onEntriesChanged() { if (root.active) NotificationCenter.markRead() } }
    Timer { id: clearTimer; interval: 5000; onTriggered: root.confirmClear = false }

    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Notifications"; color: "#cdd6f4"; font.pixelSize: 24; font.bold: true }
        SettingsButton {
            text: root.confirmClear ? "Confirm clear" : "Clear history"
            danger: root.confirmClear
            enabled: NotificationCenter.entries.length > 0
            onClicked: {
                if (root.confirmClear) { NotificationCenter.clear(); root.confirmClear = false }
                else { root.confirmClear = true; clearTimer.restart() }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Last 100 notifications · Saved locally. Expired messages are read-only."
        color: "#9399b2"; font.pixelSize: 12; wrapMode: Text.Wrap
    }
    Text {
        Layout.fillWidth: true
        visible: NotificationCenter.error.length > 0
        text: NotificationCenter.error
        color: "#f38ba8"; font.pixelSize: 12; wrapMode: Text.Wrap
    }
    TextField {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search notifications"
        color: "#cdd6f4"; placeholderTextColor: "#9399b2"
        font.pixelSize: 13
        background: Rectangle { color: "#181825"; radius: 9; border.width: search.activeFocus ? 1 : 0; border.color: "#6b587f" }
    }
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: root.filtered
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Rectangle {
            id: record
            required property var modelData
            property bool expanded: false
            width: list.width - 12
            implicitHeight: row.implicitHeight + 24
            radius: 10
            color: recordHover.hovered ? "#343044" : "#282535"
            HoverHandler { id: recordHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: NotificationCenter.liveNotification(record.modelData) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (NotificationCenter.activate(record.modelData)) root.closeRequested()
                    else record.expanded = !record.expanded
                }
            }
            RowLayout {
                id: row
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12
                spacing: 10
                Item {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 30; implicitHeight: 30
                    Image {
                        id: icon
                        anchors.fill: parent
                        source: {
                            return Utils.notificationIcon(record.modelData.appIcon || "", name => Quickshell.iconPath(name, true))
                        }
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 30; sourceSize.height: 30
                    }
                    MaterialSymbol { anchors.centerIn: parent; visible: icon.status !== Image.Ready; text: "notifications"; iconSize: 23; color: "#cba6f7" }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: record.modelData.appName && record.modelData.appName.toLowerCase() !== "notify-send" ? record.modelData.appName : "Notification"
                            textFormat: Text.PlainText
                            color: "#cba6f7"; font.pixelSize: 11; elide: Text.ElideRight
                        }
                        Text { text: Qt.formatDateTime(new Date(record.modelData.timestamp), "dd MMM · hh:mm"); color: "#9399b2"; font.pixelSize: 10 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: record.modelData.summary
                        textFormat: Text.PlainText
                        color: "#cdd6f4"; font.pixelSize: 13; font.bold: true
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: record.modelData.body
                        textFormat: Text.PlainText
                        color: "#bac2de"; font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: record.expanded ? 100 : 4
                        elide: Text.ElideRight
                    }
                }
                Item {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 20; implicitHeight: 24
                    MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 18; color: removeMouse.containsMouse ? "#f38ba8" : "#9399b2" }
                    MouseArea { id: removeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationCenter.remove(record.modelData.key) }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: search.text ? "No matching notifications" : "You're all caught up"
            color: "#9399b2"; font.pixelSize: 14
        }
    }
}
