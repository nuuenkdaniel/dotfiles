pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Rectangle {
  id: root

  property int workspaceWidth: 0
  property int workspaceSpacing: workspaceWidth*.2
  property int activeWorkspaceSize: workspaceWidth*.7
  property int inactiveWorkspaceSize: workspaceWidth*.57
  property int activeFontSize: workspaceWidth*.43
  property int inactiveFontSize: workspaceWidth*.29

  Layout.alignment: Qt.AlignHCenter
  implicitWidth: workspaceWidth
  implicitHeight: workspaceLayout.implicitHeight + root.implicitWidth/2
  color: "#313244"
  radius: root.implicitWidth/2
  visible: Hyprland.workspaces.values.length > 1

  ColumnLayout {
    id: workspaceLayout
    anchors.centerIn: parent
    spacing: root.workspaceSpacing

    Repeater {
      id: workspaceRepeater
      model: Hyprland.workspaces

      delegate: Rectangle {
        id: workspaceDelegate
        required property var modelData
        readonly property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: isActive? root.activeWorkspaceSize : root.inactiveWorkspaceSize
        Layout.preferredHeight: isActive? root.activeWorkspaceSize : root.inactiveWorkspaceSize
        radius: isActive? root.activeWorkspaceSize/2 : root.inactiveWorkspaceSize/2
        color: isActive ? "#cba6f7" : "#585b70"

        Behavior on Layout.preferredWidth { 
          NumberAnimation { duration: 250; easing.type: Easing.OutExpo } 
        }
        Behavior on Layout.preferredHeight { 
          NumberAnimation { duration: 250; easing.type: Easing.OutExpo } 
        }
        Behavior on color { 
          ColorAnimation { duration: 200 } 
        }

        Text {
          anchors.centerIn: parent
          text: workspaceDelegate.modelData.id
          color: workspaceDelegate.isActive ? "#11111b" : "#cdd6f4" 
          font.family: "mononoki Nerd Font"
          font.pixelSize: workspaceDelegate.isActive ? root.activeFontSize : root.inactiveFontSize
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Hyprland.dispatch("workspace " + workspaceDelegate.modelData.id)
          }
        }
      }
    }
  }
}
