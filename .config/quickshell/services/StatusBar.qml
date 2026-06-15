pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
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

        property int barWidth: screen.width*.023
        property int shadowRadius: 10
        property int shadowXOffset: 5
        property int shadowYOffset: 5
        property int spacerHeight: barWidth*.167

        margins.left: -50 + (50*animState.progress)
        visible: root.visibleState || animState.progress > 0
        implicitWidth: barWidth + (shadowRadius*3) + shadowXOffset

        exclusiveZone: sidebar.barWidth
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "sidebar"
        color: "transparent"

        Rectangle {
          id: barBackground
          // anchors.fill: parent
          width: sidebar.barWidth
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          color: "#1e1e2e"
          // border.color: "black" 
          // border.width: sidebar.implicitWidth * 0.05

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
            // app tray
            AppTray { compWidth: sidebar.barWidth*.7 }
            Rectangle { implicitHeight: sidebar.spacerHeight/2 }
            InfoTray { compWidth: sidebar.barWidth }
            Rectangle { implicitHeight: sidebar.spacerHeight }

            // wifi, bluetooth, battery tray
            Rectangle {
              id: signalBar
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 40
              implicitHeight: infoLayout.implicitHeight + 20
              radius: 20
              color: "#44475A"

              property int wifiSignalPercentage: 0
              property string wifiGlyph: "󰤯"

              property string blueToothGlyph: "󰂲"

              Process {
                id: wifiCheck
                command: ["bash", "-c", "cat /proc/net/wireless | awk 'NR==3 {print $3}'"]
                stdout: StdioCollector {
                  onStreamFinished: signalBar.wifiSignalPercentage = Number(this.text)
                }
              }

              property bool bluetoothConnected: false
              Process {
                id: bluetoothCheck
                command: ["bash", "-c", "bluetoothctl show | grep Powered | awk '{print $2}'"]
                stdout: StdioCollector {
                  onStreamFinished: signalBar.bluetoothConnected = `${this.text.trim()}` == 'yes'
                }
              }

              property bool deviceConnected: false
              Process {
                id: deviceCheck
                command: ["bash", "-c", "bluetoothctl devices Connected"]
                stdout: StdioCollector {
                  onStreamFinished: signalBar.deviceConnected = this.text.trim() != ""
                }
              }

              Component.onCompleted: {
                signalBar.updateAudioVisuals()
              }

              property int audioLevel: 0

              Timer {
                interval: 5000; running: true; repeat: true; triggeredOnStart: false
                onTriggered: {
                  wifiCheck.running = true
                  bluetoothCheck.running = true
                  // console.log(signalBar.wifiSignalPercentage)
                  signalBar.updateWifiVisuals()
                  // console.log(signalBar.bluetoothConnected)
                  signalBar.updateBTVisuals()
                  // console.log(signalBar.haveBattery)
                }
              }

              function updateWifiVisuals() {
                let p = 2*(-1*wifiSignalPercentage + 100);
                if (p <= 0) { wifiGlyph = "󰤯"; }
                else if (p <= 25) { wifiGlyph = "󰤟"; }
                else if (p <= 50) { wifiGlyph = "󰤢"; }
                else if (p <= 75) { wifiGlyph = "󰤥"; }
                else { wifiGlyph = "󰤨"; }
              }

              function updateBTVisuals() {
                if (bluetoothConnected) {
                  deviceCheck.running = true
                  // console.log(deviceConnected)
                  if (deviceConnected) { blueToothGlyph = ""; }
                  else { blueToothGlyph = "󰂯"; }
                }
                else { blueToothGlyph = "󰂲"; }
                // console.log(blueToothGlyph)
              }

              Connections {
                target: Pipewire.defaultAudioSink?.audio || null
                function onVolumeChanged() {
                  signalBar.updateAudioVisuals()
                }
                function onMutedChanged() {
                  signalBar.updateAudioVisuals()
                }
              }

              property var activeAudioSink: Pipewire.defaultAudioSink
              onActiveAudioSinkChanged: {
                signalBar.updateAudioVisuals()
              }

              property bool headphone: false
              property string audioGlyph: ""

              property string sinkName: activeAudioSink?.name ?? ""

              property bool isHeadphone: sinkName.indexOf("Logitech_PRO_X") !== -1
              property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0

              property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
              function updateAudioVisuals() {
                if (!isHeadphone) {
                  if (!muted) {
                    if (volume <= .33) { audioGlyph = ""; }
                    else if (volume <= .66) { audioGlyph = ""; }
                    else { audioGlyph = ""; } 
                  }
                  else { audioGlyph = ""; }
                }
                else { audioGlyph = "󰋎"; }
              }

              ColumnLayout {
                id: infoLayout
                anchors.centerIn: parent
                spacing: 8
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  font.family: "mononoki Nerd Font"
                  font.pixelSize: 20
                  text: signalBar.wifiGlyph
                  color: "#f5e0dc"
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  font.family: "mononoki Nerd Font"
                  font.pixelSize: 20
                  text: signalBar.blueToothGlyph
                  color: "#f5e0dc"
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  font.family: "mononoki Nerd Font"
                  font.pixelSize: 20
                  text: signalBar.audioGlyph
                  color: "#f5e0dc"
                }
              }
            }
          }
        }
      }
    }
  }
}
