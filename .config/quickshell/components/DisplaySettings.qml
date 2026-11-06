pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../globals"

ColumnLayout {
    id: root
    property bool active: false
    spacing: 16
    onActiveChanged: DisplayState.visiblePanels += active ? 1 : -1
    Component.onDestruction: if (active) DisplayState.visiblePanels -= 1

    Text { text: "Display"; color: "#cdd6f4"; font.pixelSize: 24; font.bold: true }
    Text { Layout.fillWidth: true; text: "Screen brightness"; color: "#bac2de"; font.pixelSize: 13 }
    RowLayout {
        Layout.fillWidth: true
        MaterialSymbol { text: "brightness_6"; iconSize: 28; color: "#cba6f7" }
        Text { Layout.fillWidth: true; text: DisplayState.device || "Detecting backlight…"; color: "#cdd6f4"; font.pixelSize: 13 }
        Text { text: Math.round(DisplayState.brightness * 100) + "%"; color: "#cba6f7"; font.pixelSize: 18; font.bold: true }
    }
    Slider {
        id: brightness
        Layout.fillWidth: true
        implicitHeight: 36
        from: 1; to: 100; stepSize: 1
        enabled: DisplayState.ready
        value: DisplayState.brightness * 100
        Accessible.name: "Screen brightness"
        onMoved: DisplayState.setFraction(value / 100)
        background: Rectangle {
            implicitWidth: 200
            implicitHeight: 6
            x: brightness.leftPadding
            y: brightness.topPadding + (brightness.availableHeight - height) / 2
            width: brightness.availableWidth; height: 6; radius: 3; color: "#45475a"
            Rectangle { width: brightness.visualPosition * parent.width; height: parent.height; radius: 3; color: "#cba6f7" }
        }
        handle: Rectangle {
            x: brightness.leftPadding + brightness.visualPosition * (brightness.availableWidth - width)
            y: brightness.topPadding + (brightness.availableHeight - height) / 2
            implicitWidth: 16; implicitHeight: 16
            width: implicitWidth; height: implicitHeight; radius: 8; color: "#cba6f7"
        }
    }
    RowLayout {
        spacing: 8
        Repeater {
            model: [20, 40, 60, 80, 100]
            delegate: SettingsButton {
                required property int modelData
                text: modelData + "%"
                enabled: DisplayState.ready
                onClicked: DisplayState.setFraction(modelData / 100)
            }
        }
    }
    Text { Layout.fillWidth: true; text: "Stays in sync with your brightness keys and OSD. This controls internal-display brightness; external monitors need their own brightness controls."; color: "#9399b2"; font.pixelSize: 12; wrapMode: Text.Wrap }
    Text { Layout.fillWidth: true; visible: DisplayState.error.length > 0; text: DisplayState.error; color: "#f38ba8"; font.pixelSize: 12; wrapMode: Text.Wrap }
    Item { Layout.fillHeight: true }
}
