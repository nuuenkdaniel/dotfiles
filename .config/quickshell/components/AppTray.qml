pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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

  ColumnLayout {
    id: trayLayout
    anchors.centerIn: parent
    spacing: root.compWidth*.1

    property int itemSize: root.compWidth*.6
    property int activeHeight: root.compWidth*.8

    Repeater {
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

        HyprlandFocusGrab {
          active: bubbleMenu.visible 

          windows: [bubbleMenu] 

          onCleared: {
            trayLayout.lastClearTime = Date.now()
            bubbleMenu.visible = false
          }
        }

        QsMenuOpener {
          id: menuOpener
          menu: delegateRoot.trayData.menu
        }

        PopupWindow {
          id: bubbleMenu
          implicitWidth: menuLayout.implicitWidth + 20
          implicitHeight: menuLayout.implicitHeight + 20

          anchor {
            // window: sidebar
            item: delegateRoot
            edges: Edges.Right
          }

          color: "transparent"

          onVisibleChanged: {
            if (visible) {
              menuBackground.forceActiveFocus()
            }
          }

          Rectangle {
            id: menuBackground
            anchors.fill: parent 
            anchors.margins: 10 
            color: "#1e1e2e"
            radius: 12
            border.color: "#cba6f7"
            border.width: 1

            focus: true
            onActiveFocusChanged: {
              if (!activeFocus && bubbleMenu.visible) {
                trayLayout.lastClearTime = Date.now()
                bubbleMenu.visible = false
              }
            }

            ColumnLayout {
              id: menuLayout
              anchors.centerIn: parent
              spacing: 4

              Repeater {
                model: menuOpener.children

                delegate: Rectangle {
                  id: delegateMenu
                  required property var modelData
                  readonly property bool isSeparator: modelData.isSeparator

                  Layout.fillWidth: true
                  implicitWidth: 140
                  implicitHeight: isSeparator ? 1 : 30
                  radius: isSeparator ? 0 : 6
                  color: isSeparator ? "#45475a" : (itemMouse.containsMouse ? "#313244" : "transparent")

                  Text {
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
                        bubbleMenu.visible = false 
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Image {
          anchors.fill: parent
          anchors.margins: root.compWidth*.1
          source: delegateRoot.modelData.icon
          fillMode: Image.PreserveAspectFit
        }

        MouseArea {
          id: trayMouse
          anchors.fill: parent
          hoverEnabled: true 
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor

          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {

              if (Date.now() - delegateRoot.lastClearTime < 100) {
                return
              }

              if (!bubbleMenu.visible) {
                if (delegateRoot.trayData.menu && typeof delegateRoot.trayData.menu.update === "function") {
                  delegateRoot.trayData.menu.update()
                }
                bubbleMenu.visible = true 
              } else {
                bubbleMenu.visible = false
              }

            } else if (mouse.button === Qt.LeftButton) {
              delegateRoot.trayData.activate(0, 0) 
            }
          }
        }
      }
    }
  }
}
