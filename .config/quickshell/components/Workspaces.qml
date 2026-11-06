pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../globals"

Rectangle {
  id: root

  property int workspaceWidth: 0
  property int workspaceSpacing: workspaceWidth*.2
  property int activeWorkspaceSize: workspaceWidth*.7
  property int inactiveWorkspaceSize: workspaceWidth*.57
  property int activeFontSize: workspaceWidth*.43
  property int inactiveFontSize: workspaceWidth*.29

  // Replace the map on changes so delegates react to attention updates.
  property var attentionWorkspaces: ({})

  function markAttention(workspaceId) {
    if (workspaceId === undefined || workspaceId === null
        || Hyprland.focusedWorkspace?.id === workspaceId) return;
    const next = Object.assign({}, root.attentionWorkspaces);
    next[String(workspaceId)] = true;
    root.attentionWorkspaces = next;
  }

  function clearAttention(workspaceId) {
    if (!root.attentionWorkspaces[String(workspaceId)]) return;
    const next = Object.assign({}, root.attentionWorkspaces);
    delete next[String(workspaceId)];
    root.attentionWorkspaces = next;
  }

  Connections {
    target: Hyprland

    function onFocusedWorkspaceChanged() {
      root.clearAttention(Hyprland.focusedWorkspace?.id);
    }

    function onRawEvent(event) {
      if (event.name !== "openwindow") return;
      // openwindow: address, workspace name, class, title.
      const workspaceName = event.data.split(",")[1];
      if (!workspaceName) return;
      const workspace = Hyprland.workspaces.values.find(ws => ws.name === workspaceName);
      if (workspace) {
        root.markAttention(workspace.id);
      } else {
        // The event can precede the model update for a newly created workspace.
        const workspaceId = Number(workspaceName);
        if (Number.isInteger(workspaceId) && workspaceId > 0)
          root.markAttention(workspaceId);
      }
    }
  }

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
        readonly property bool needsAttention: !isActive && !!root.attentionWorkspaces[String(modelData.id)]

        Connections {
          target: workspaceDelegate.modelData
          function onUrgentChanged() {
            if (workspaceDelegate.modelData.urgent)
              root.markAttention(workspaceDelegate.modelData.id);
          }
        }

        Component.onCompleted: {
          if (modelData.urgent) root.markAttention(modelData.id);
        }

        // Layered translucent rings keep the halo lightweight and subtle.
        Rectangle {
          anchors.centerIn: parent
          width: parent.width + 8
          height: parent.height + 8
          radius: width / 2
          color: "#10f38ba8"
          border.width: 3
          border.color: "#18f38ba8"
          visible: workspaceDelegate.needsAttention
          z: -1
        }

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: isActive? root.activeWorkspaceSize : root.inactiveWorkspaceSize
        Layout.preferredHeight: isActive? root.activeWorkspaceSize : root.inactiveWorkspaceSize
        radius: isActive? root.activeWorkspaceSize/2 : root.inactiveWorkspaceSize/2
        color: isActive ? "#cba6f7" : needsAttention ? "#795364" : "#585b70"
        border.width: needsAttention ? 1 : 0
        border.color: "#b86c80"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Workspace " + modelData.id
        Keys.onReturnPressed: { GlobalMenuState.isVisible = false; modelData.activate() }
        Keys.onSpacePressed: { GlobalMenuState.isVisible = false; modelData.activate() }

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
            GlobalMenuState.isVisible = false
            workspaceDelegate.modelData.activate()
          }
        }
      }
    }
  }
}
