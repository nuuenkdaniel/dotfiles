pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../globals"

Item {
  id: root
  property bool visibleState: false
  readonly property real brightness: DisplayState.brightness
  readonly property bool initialized: DisplayState.ready
  property int hoveredWindows: 0
  onVisibleStateChanged: DisplayState.osdVisible = visibleState
  Component.onDestruction: DisplayState.osdVisible = false

  function adjust(value) {
    DisplayState.setFraction(value)
    root.visibleState = true
    hideTimer.restart()
  }


  function display() {
    root.visibleState = true
    hideTimer.restart()
    DisplayState.refresh()
  }

  IpcHandler {
    target: "brightness"
    function display(): void { root.display() }
  }

  Connections { target: DisplayState; function onLevelChanged() { root.display() } }

  Timer {
    id: hideTimer
    interval: 2000
    onTriggered: {
      if (root.hoveredWindows > 0) restart()
      else root.visibleState = false
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
        WlrLayershell.namespace: "brightness-osd"
        color: "transparent"
        anchors.top: true
        margins.top: -50 + (62 * animState.progress)
        implicitWidth: 250
        implicitHeight: 50
        visible: root.visibleState || animState.progress > 0

        QtObject {
          id: animState
          property real progress: root.visibleState ? 1.0 : 0.0
          Behavior on progress {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
          }
        }

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

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 15

            Text {
              Layout.preferredWidth: 30
              Layout.preferredHeight: 30
              Layout.alignment: Qt.AlignVCenter
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignHCenter
              text: "󰃠"
              font.family: "mononoki Nerd Font"
              font.pixelSize: 25
              color: "#cdd6f4"
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
                width: parent.width * root.brightness
                radius: parent.radius
                color: "#cba6f7"
                Behavior on width {
                  NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }
              }
              MouseArea {
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12
                cursorShape: Qt.PointingHandCursor
                enabled: root.initialized
                onPressed: mouse => root.adjust(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) root.adjust(mouse.x / width) }
              }
            }
          }
        }
      }
    }
  }
}
