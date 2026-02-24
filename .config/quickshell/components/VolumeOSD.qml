import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
  id: root

  property bool visibleState: false
  property real volume: 0.0
  property bool muted: false

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        QtObject {
          id: animState
          property real progress: root.visibleState ? 1.0 : 0.0
          Behavior on progress {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
          }
        }

        visible: root.visibleState || animState.progress > 0

        anchors.bottom: true
        margins.bottom: -10 + (50 * animState.progress)

        implicitWidth: 250
        implicitHeight: 50

        Rectangle {
          anchors.fill: parent
          opacity: animState.progress
          radius: 12
          color: "#E61E1E2E"
          border.color: "#cba6f7"
          border.width: 2

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 15

            Text {
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              Layout.alignment: Qt.AlignVCenter
              Layout.bottomMargin: 1

              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignHCenter

              color: "#cdd6f4"
              font.pixelSize: 24
              font.family: "monospace"

              text: root.muted ? "󰖁" : "󰕾"
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              implicitHeight: 8
              radius: 10
              color: "#313244"

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                implicitWidth: parent.width * root.volume
                radius: parent.radius
                color: "#cba6f7"

                Behavior on implicitWidth {
                  NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }
              }
            }
          }
        }
      }
    }
  }
}
