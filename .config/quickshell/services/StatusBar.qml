pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components"

Item {
  id: root

  property bool visibleState: true
  IpcHandler {
    target: "status"
    function toggle(): void {
      root.visibleState = !root.visibleState;
    }
  }
  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: sidebar
        required property var modelData
        screen: modelData

        anchors {
          left: true
          top: true
          bottom: true
        }

        QtObject {
          id: animState
          property real progress: root.visibleState ? 1.0 : 0.0
          Behavior on progress {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
          }
        }

        readonly property int barWidth: screen.width*.023
        readonly property int shadowRadius: 10
        readonly property int shadowXOffset: 5
        readonly property int shadowYOffset: 0
        readonly property int spacerHeight: barWidth*.167

        margins.left: -sidebar.implicitWidth * (1.0 - animState.progress)
        visible: root.visibleState || animState.progress > 0
        implicitWidth: barWidth + (shadowRadius*3) + shadowXOffset

        exclusiveZone: sidebar.barWidth
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "sidebar"
        color: "transparent"

        mask: Region { item: barBackground }

        Rectangle {
          id: barBackground
          width: sidebar.barWidth
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          color: "#1e1e2e"

          layer.enabled: true
          layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Qt.rgba(0, 0, 0, 0.75)
              shadowBlur: 1.0 
              shadowHorizontalOffset: sidebar.shadowXOffset 
              shadowVerticalOffset: sidebar.shadowYOffset
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebar.barWidth*.167
            spacing: 0

            // Top
            Workspaces { workspaceWidth: sidebar.barWidth*.7} 

            Item { Layout.fillHeight: true }

            // Middle
            FocusedWorkspaceClass { compWidth: sidebar.barWidth*.533 }

            Item { Layout.fillHeight: true }

            // Bottom
            AppTray { compWidth: sidebar.barWidth*.7 }
            Item { implicitHeight: sidebar.spacerHeight/2 }
            InfoTray { compWidth: sidebar.barWidth }
            Item { implicitHeight: sidebar.spacerHeight }
            ConnectionsTray { compWidth: sidebar.barWidth*.7 }
          }
        }
      }
    }
  }
}
