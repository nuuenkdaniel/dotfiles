pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../globals"

Rectangle {
  id: root
  
  property int compWidth: 0
  property string screenName: ""
  property int sidebarWidth: 55
  readonly property int trayRadius: compWidth/2

  Layout.alignment: Qt.AlignHCenter
  implicitWidth: compWidth
  implicitHeight: trayLayout.implicitHeight > 0 ? trayLayout.implicitHeight + trayRadius : 0
  visible: trayLayout.implicitHeight > 0
  color: "transparent"
  radius: trayRadius

  // AppMenu { id: menu }
  signal openMenuRequested(real targetY, var menuData)

  ColumnLayout {
    id: trayLayout
    anchors.centerIn: parent
    spacing: root.compWidth*.1

    property int itemSize: root.compWidth*.7
    property int activeHeight: root.compWidth*.7

    Repeater {
      id: trayItemRepeater
      model: SystemTray.items

      delegate: Rectangle {
        id: delegateRoot 
        required property var modelData
        property var trayData: modelData 
        property var lastClearTime: 0

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: trayLayout.itemSize
        Layout.preferredHeight: trayMouse.containsMouse ? trayLayout.activeHeight : trayLayout.itemSize
        radius: trayLayout.itemSize
        color: trayMouse.containsMouse ? "#45475a" : "transparent"

        Behavior on color { 
          ColorAnimation { duration: 200 } 
        }

        Image {
          anchors.fill: parent
          anchors.margins: root.compWidth*.1
          source: delegateRoot.modelData.icon
          fillMode: Image.PreserveAspectFit
          sourceSize.width: parent.width
          sourceSize.height: parent.height
          smooth: true
          antialiasing: true
        }

        MouseArea {
          id: trayMouse
          anchors.fill: parent
          hoverEnabled: true 
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor

          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
              let pos = delegateRoot.mapToItem(null, 0, 0);
              GlobalMenuState.openAt(pos.y, [], 0, false, root.screenName, root.sidebarWidth, delegateRoot.trayData);
            } else if (mouse.button === Qt.LeftButton) {
              delegateRoot.trayData.activate(0, 0) 
              GlobalMenuState.isVisible = false
            }
          }
        }
        Component.onDestruction: if (GlobalMenuState.menuSource === trayData) GlobalMenuState.isVisible = false
      }
    }
  }
}
