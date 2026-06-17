pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
  id: root
  
  property int compWidth: 0
  readonly property int trayRadius: compWidth/2

  Layout.alignment: Qt.AlignHCenter
  implicitWidth: compWidth
  implicitHeight: trayLayout.implicitHeight > 0 ? trayLayout.implicitHeight + trayRadius : 0
  visible: trayLayout.implicitHeight > 0
  color: "transparent"
  radius: trayRadius

  AppMenu { id: menu }

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

        Behavior on Layout.preferredHeight { 
          NumberAnimation { duration: 250; easing.type: Easing.OutExpo } 
        }
        Behavior on color { 
          ColorAnimation { duration: 200 } 
        }

        QsMenuOpener {
          id: menuOpener
          menu: delegateRoot.trayData.menu
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
              menu.targetY = pos.y
              menu.menuModel = menuOpener.children
              if (!menu.visible) { menu.visible = true; }
            } else if (mouse.button === Qt.LeftButton) {
              delegateRoot.trayData.activate(0, 0) 
              menu.visible = false
            }
          }
        }
      }
    }
  }
}
