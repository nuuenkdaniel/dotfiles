pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../globals"

PanelWindow {
  id: root
  visible: GlobalMenuState.isVisible
  color: "transparent"
  
  property real targetX: 0

  WlrLayershell.layer: WlrLayer.Top

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  MouseArea {
    anchors.fill: parent
    onClicked: GlobalMenuState.isVisible = false
  }

  Rectangle {
    id: popupMenu

    x: GlobalMenuState.isVisible ? root.targetX : root.targetX - 30
    y: (GlobalMenuState.targetY + popupMenu.implicitHeight) < root.height ? GlobalMenuState.targetY : root.height - popupMenu.implicitHeight
    color: "#1e1e2e"
    opacity: (menuLayout.implicitHeight > 0 && GlobalMenuState.isVisible) ? 1.0 : 0.0

    topRightRadius: 20
    bottomRightRadius: (y + popupMenu.implicitHeight) == root.height ? 0 : 20

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
      enabled: GlobalMenuState.isVisible
      NumberAnimation { duration: 300; easing.type: Easing.OutExpo } 
    }

    Behavior on y { 
      enabled: GlobalMenuState.isVisible
      NumberAnimation { duration: 500; easing.type: Easing.OutExpo } 
    }

    MouseArea {
      anchors.fill: parent
    }

    ColumnLayout {
      id: menuLayout
      anchors.centerIn: parent
      spacing: 4

      Repeater {
        model: GlobalMenuState.menuModel

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
                if (!GlobalMenuState.persist) { GlobalMenuState.isVisible = false; }
              }
            }
          }
        }
      }
    }
  }
}
