pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root
  visible: false
  color: "transparent"
  
  property real targetX: 0
  property real targetY: 0
  property var menuModel: []

  WlrLayershell.layer: WlrLayer.Top

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.visible = false
  }

  Rectangle {
    id: popupMenu
    x: root.visible ? root.targetX : root.targetX - 30
    y: root.targetY
    color: "#1e1e2e"

    topRightRadius: 20
    bottomRightRadius: 20

    implicitWidth: menuLayout.implicitWidth + 20
    implicitHeight: menuLayout.implicitHeight + 20

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowBlur: 1.0
        shadowColor: Qt.rgba(0, 0, 0, 0.75) 
    }

    Behavior on x { 
      enabled: root.visible
      NumberAnimation { duration: 300; easing.type: Easing.OutExpo } 
    }

    Behavior on y { 
      enabled: root.visible
      NumberAnimation { duration: 250; easing.type: Easing.OutExpo } 
    }

    Behavior on implicitWidth { 
      enabled: root.visible
      NumberAnimation { duration: 250; easing.type: Easing.OutExpo } 
    }
    Behavior on implicitHeight { 
      enabled: root.visible
      NumberAnimation { duration: 250; easing.type: Easing.OutExpo } 
    }

    MouseArea {
      anchors.fill: parent
    }

    ColumnLayout {
      id: menuLayout
      anchors.centerIn: parent
      spacing: 4

      Repeater {
        model: root.menuModel

        delegate: Rectangle {
          id: delegateMenu
          required property var modelData
          readonly property bool isSeparator: modelData.isSeparator

          Layout.fillWidth: true
          implicitWidth: isSeparator ? 1 : menuText.implicitWidth + 20
          implicitHeight: isSeparator ? 1 : 30
          radius: isSeparator ? 0 : 6
          color: isSeparator ? "#45475a" : (itemMouse.containsMouse ? "#313244" : "transparent")

          Text {
            id: menuText
            anchors.fill: parent
            anchors.leftMargin: 10
            verticalAlignment: Text.AlignVCenter
            visible: !delegateMenu.isSeparator
            text: delegateMenu.modelData.text ? delegateMenu.modelData.text.replace(/&/g, "") : ""
            color: "#cdd6f4" 
            font.pixelSize: 12
          }

          MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: !delegateMenu.isSeparator
            cursorShape: delegateMenu.isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor

            onClicked: {
              if (!delegateMenu.isSeparator) {
                delegateMenu.modelData.triggered()
                root.visible = false
              }
            }
          }
        }
      }
    }
  }
}
