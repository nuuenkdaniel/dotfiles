pragma Singleton
import QtQuick

QtObject {
    property bool isVisible: false
    property real targetY: 0
    property var menuModel: []
    property bool persist: false
}
