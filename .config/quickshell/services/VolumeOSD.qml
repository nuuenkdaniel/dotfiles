pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

import "../components"

Item {
  id: root

  property bool visibleState: false
  property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
  property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  Timer {
    id: hideTimer
    interval: 2000
    onTriggered: root.visibleState = false
  }

  Connections {
    target: Pipewire.defaultAudioSink?.audio || null
    function onVolumeChanged() {
      root.visibleState = true
      hideTimer.restart()
    }
    function onMutedChanged() {
      root.visibleState = true
      hideTimer.restart()
    }
  }

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

            DynamicAudioIcon {
              Layout.preferredWidth: 30
              Layout.preferredHeight: 30
              Layout.alignment: Qt.AlignVCenter
              Layout.bottomMargin: 1

              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignHCenter

              color: "#cdd6f4"
              font.family: "monospace"

              fontSize: 20
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
