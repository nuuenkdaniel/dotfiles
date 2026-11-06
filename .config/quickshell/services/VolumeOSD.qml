pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

import "../components"

Item {
  id: root

  property bool visibleState: false
  property int hoveredWindows: 0
  property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
  property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

  function show() {
    root.visibleState = true
    hideTimer.restart()
  }

  IpcHandler {
    target: "volume"
    function display(): void { root.show() }
  }

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  Timer {
    id: hideTimer
    interval: 2000
    onTriggered: {
      if (root.hoveredWindows > 0) restart()
      else root.visibleState = false
    }
  }

  Connections {
    target: Pipewire.defaultAudioSink?.audio || null
    function onVolumeChanged() {
      root.show()
    }
    function onMutedChanged() {
      root.show()
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

        anchors.right: true
        margins.right: -56 + (68 * animState.progress)

        implicitWidth: 56
        implicitHeight: 200

        Rectangle {
          anchors.fill: parent
          opacity: animState.progress
          radius: 12
          color: "#E61E1E2E"
          border.color: "#cba6f7"
          border.width: 2

          HoverHandler {
            Component.onDestruction: if (hovered) root.hoveredWindows -= 1
            onHoveredChanged: {
              root.hoveredWindows += hovered ? 1 : -1
              hideTimer.restart()
            }
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 15
            anchors.bottomMargin: 15
            spacing: 12

            // Text {
            //   Layout.preferredWidth: 24
            //   Layout.preferredHeight: 24
            //   Layout.alignment: Qt.AlignVCenter
            //   Layout.bottomMargin: 1
            //
            //   verticalAlignment: Text.AlignVCenter
            //   horizontalAlignment: Text.AlignHCenter
            //
            //   color: "#cdd6f4"
            //   font.pixelSize: 24
            //   font.family: "monospace"
            //
            //   text: root.muted ? "󰖁" : "󰕾"
            // }
            Rectangle {
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 8
              radius: width / 2
              color: "#313244"

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: parent.height * Math.max(0, Math.min(1, root.volume))
                radius: parent.radius
                color: "#cba6f7"

                Behavior on height {
                  NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }
              }
              MouseArea {
                anchors.fill: parent
                anchors.leftMargin: -14
                anchors.rightMargin: -14
                cursorShape: Qt.PointingHandCursor
                enabled: !!Pipewire.defaultAudioSink?.audio
                function adjust(y) {
                  Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, 1 - y / height))
                  root.show()
                }
                onPressed: mouse => adjust(mouse.y)
                onPositionChanged: mouse => { if (pressed) adjust(mouse.y) }
              }
            }
            Item {
              Layout.preferredWidth: 30
              Layout.preferredHeight: 30
              Layout.alignment: Qt.AlignHCenter
              MaterialSymbol {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                color: "#cdd6f4"
                iconSize: 25
                fill: 1
                text: root.muted ? "volume_off" : root.volume <= 0 ? "volume_mute" : root.volume <= .5 ? "volume_down" : "volume_up"
              }
            }
          }
        }
      }
    }
  }
}
