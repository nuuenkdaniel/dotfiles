pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Item {
  id: root
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
        visible: true
        implicitWidth: screen.width * 0.034

        exclusionMode: ExclusionMode.Auto
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "sidebar"
        color: "transparent"

        Rectangle {
          id: barBackground
          anchors.fill: parent
          color: "#1e1e2e"
          border.color: "black" 
          border.width: sidebar.implicitWidth * 0.05

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0

            // Top
            // workspaces
            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 32
              implicitHeight: workspaceLayout.implicitHeight + 16
              color: "#313244"
              radius: 16 
              visible: Hyprland.workspaces.values.length > 1

              ColumnLayout {
                id: workspaceLayout
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                  model: Hyprland.workspaces


                  delegate: Rectangle {
                    required property var modelData

                    readonly property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id

                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: isActive ? 25 : 16
                    radius: 8
                    color: isActive ? "#cba6f7" : "#585b70"

                    Behavior on Layout.preferredHeight { 
                      NumberAnimation { duration: 250; easing.type: Easing.OutExpo } 
                    }
                    Behavior on color { 
                      ColorAnimation { duration: 200 } 
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        Hyprland.dispatch("workspace " + modelData.id)
                      }
                    }
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }

            // bottom
            // app tray
            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 32
              implicitHeight: trayLayout.implicitHeight > 0 ? trayLayout.implicitHeight + 16 : 0
              visible: trayLayout.implicitHeight > 0
              color: "transparent"
              radius: 16

              ColumnLayout {
                id: trayLayout
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                  model: SystemTray.items

                  delegate: Rectangle {
                    id: delegateRoot 
                    required property var modelData
                    property var trayData: modelData 
                    property var lastClearTime: 0

                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: trayMouse.containsMouse ? 32 : 24
                    radius: 12
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
                        lastClearTime = Date.now()
                        bubbleMenu.visible = false
                      }
                    }

                    QsMenuOpener {
                      id: menuOpener
                      menu: trayData.menu
                    }

                    PopupWindow {
                      id: bubbleMenu
                      implicitWidth: menuLayout.implicitWidth + 20
                      implicitHeight: menuLayout.implicitHeight + 20

                      anchor {
                        window: sidebar
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
                            lastClearTime = Date.now()
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
                                visible: !isSeparator
                                text: modelData.text ? modelData.text.replace(/&/g, "") : ""
                                color: "#cdd6f4" 
                                font.pixelSize: 12
                              }

                              MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: !isSeparator
                                cursorShape: isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor

                                onClicked: {
                                  if (!isSeparator) {
                                    modelData.triggered()
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
                      anchors.margins: 4 
                      source: modelData.icon
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

                          if (Date.now() - lastClearTime < 100) {
                            return
                          }

                          if (!bubbleMenu.visible) {
                            if (trayData.menu && typeof trayData.menu.update === "function") {
                              trayData.menu.update()
                            }
                            bubbleMenu.visible = true 
                          } else {
                            bubbleMenu.visible = false
                          }

                        } else if (mouse.button === Qt.LeftButton) {
                          trayData.activate(0, 0) 
                        }
                      }
                    }
                  }

                }
              }
            }
            Rectangle {
              implicitHeight: 5
            }
            ColumnLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: 0
              Text {
                visible: signalBar.haveBattery
                Layout.alignment: Qt.AlignHCenter
                font.family: "mononoki Nerd Font"
                font.pixelSize: 14
                text: signalBar.batteryGlyph
                color: signalBar.batteryColor
              }
              Text {
                visible: signalBar.haveBattery
                Layout.alignment: Qt.AlignHCenter
                font.family: "mononoki Nerd Font"
                font.pixelSize: 14
                text: signalBar.batteryLevel
                color: signalBar.batteryColor
              }
            }
            Rectangle {
              implicitHeight: 10
            }

            // wifi, bluetooth, battery tray
            Rectangle {
              id: signalBar
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 32
              implicitHeight: infoLayout.implicitHeight + 16
              radius: 16
              color: "#313244"
              property int wifiSignalPercentage: 0
              property string wifiGlyph: "󰤯"

              property string blueToothGlyph: "󰂲"

              Process {
                id: wifiCheck
                command: ["bash", "-c", "cat /proc/net/wireless | awk 'NR==3 {print $3}'"]
                stdout: StdioCollector {
                  onStreamFinished: signalBar.wifiSignalPercentage = `${this.text}`
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

              property bool haveBattery: false
              Process {
                id: batteryExistCheck
                command: ["bash", "-c", "ls /sys/class/power_supply/ | grep -iE 'battery|bm[0-9]'"]
                stdout: StdioCollector {
                  onStreamFinished: {
                    signalBar.haveBattery = this.text.trim() != ""
                    // console.log(this.text)
                  }
                }
              }

              Component.onCompleted: {
                batteryExistCheck.running = true
                signalBar.updateBatteryVisuals()
              }

              property int batteryLevel: 100
              property string batteryGlyph: ""
              property string batteryColor: "#BADCBD"
              Process {
                id: batteryCheck
                command: ["bash", "-c", "cat /sys/class/power_supply/BAT0/capacity"]
                stdout: StdioCollector {
                  onStreamFinished: signalBar.batteryLevel = this.text
                }
              }

              Timer {
                interval: 5000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                  wifiCheck.running = true
                  // console.log(signalBar.wifiSignalPercentage)
                  signalBar.updateWifiVisuals()
                  bluetoothCheck.running = true
                  // console.log(signalBar.bluetoothConnected)
                  signalBar.updateBTVisuals()
                  // console.log(signalBar.haveBattery)
                  signalBar.updateBatteryVisuals()
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

              function updateBatteryVisuals() {
                if (haveBattery) {
                  batteryCheck.running = true
                  if (batteryLevel <= 0) { batteryGlyph = ""; batteryColor = "#F32013"; }
                  else if (batteryLevel <= 25) { batteryGlyph = ""; batteryColor = "#FF9999"; }
                  else if (batteryLevel <= 50) { batteryGlyph = ""; batteryColor = "#FFDAB9"; }
                  else if (batteryLevel <= 75) { batteryGlyph = ""; batteryColor = "#E5E5BF"; }
                  else { batteryGlyph = ""; batteryColor = "#BADCBD"; } 
                }
              }

              ColumnLayout {
                id: infoLayout
                anchors.centerIn: parent
                spacing: 8
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  font.family: "mononoki Nerd Font"
                  font.pixelSize: 16
                  text: signalBar.wifiGlyph
                  color: "#f5e0dc"
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  font.family: "mononoki Nerd Font"
                  font.pixelSize: 18
                  text: signalBar.blueToothGlyph
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
