pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components"
import "../globals"

Item {
  id: root

  property bool visibleState: true
  onVisibleStateChanged: if (!visibleState) GlobalMenuState.isVisible = false
  // Set false to hide the settings gear.
  property bool settingsGearPreview: true
  Dashboard {
    onSettingsRequested: name => {
      root.requestDashboardSettings(name)
    }
  }
  signal requestDashboardSettings(string screenName)
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

        readonly property int barWidth: Math.max(screen.width*.023, 55)
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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
              // The popup and bar share one silhouette while attached; the
              // bar's full-height shadow must not draw a divider over the join.
              shadowOpacity: sidebarMenu.joinedToBar ? 0 : 1
              shadowColor: Qt.rgba(0, 0, 0, 0.75)
              shadowBlur: 1.0 
              shadowHorizontalOffset: sidebar.shadowXOffset 
              shadowVerticalOffset: sidebar.shadowYOffset
          }

          GlobalMenu { id: sidebarMenu; screen: sidebar.screen; sidebarWidth: sidebar.barWidth }
          MouseArea { anchors.fill: parent; onClicked: GlobalMenuState.isVisible = false }

           SettingsMenu {
            id: settingsMenu
            screen: sidebar.screen
            sidebarWidth: sidebar.barWidth
           }
          Connections {
            target: root
            function onRequestDashboardSettings(screenName) {
              if (sidebar.screen.name !== screenName) return
              settingsMenu.activeTab = "Dashboard"
              settingsMenu.visible = true
            }
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebar.barWidth*.167
            spacing: 0

            // Top
            Rectangle {
              id: archButton
              activeFocusOnTab: true
              function activate() {
                GlobalMenuState.isVisible = false
                settingsMenu.visible = false
                DashboardState.toggle(sidebar.screen.name, sidebar.barWidth)
              }
              Keys.onReturnPressed: activate()
              Keys.onSpacePressed: activate()
              Accessible.onPressAction: activate()
              Layout.alignment: Qt.AlignHCenter
              Layout.preferredWidth: sidebar.barWidth * .7
              Layout.preferredHeight: Layout.preferredWidth
              Layout.bottomMargin: 3
              radius: width / 2
              color: DashboardState.opened && DashboardState.screenName === sidebar.screen.name ? "#40354f" : archMouse.containsMouse ? "#313244" : "transparent"
              Text { anchors.centerIn: parent; text: "󰣇"; font.family: "mononoki Nerd Font"; font.pixelSize: sidebar.barWidth * .43; color: "#cba6f7" }
              MouseArea {
                id: archMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: archButton.activate()
              }
              Accessible.role: Accessible.Button
              Accessible.name: "Toggle dashboard"
            }
            Workspaces { workspaceWidth: sidebar.barWidth*.7}

            Item { Layout.fillHeight: true }

            // Middle
            FocusedWorkspaceClass { compWidth: sidebar.barWidth*.533 }

            Item { Layout.fillHeight: true }

            // Bottom
            SidebarStatus {
              id: sidebarStatus
              compWidth: sidebar.barWidth * .7
              onDiagnosticsRequested: { settingsMenu.activeTab = "About"; settingsMenu.visible = true }
            }
            Item { visible: sidebarStatus.visible; implicitHeight: sidebar.spacerHeight / 2 }
            AppTray { compWidth: sidebar.barWidth*.7; screenName: sidebar.screen.name; sidebarWidth: sidebar.barWidth }
            Item { implicitHeight: sidebar.spacerHeight/2 }
            InfoTray { compWidth: sidebar.barWidth }
            Item { implicitHeight: sidebar.spacerHeight }
            ConnectionsTray {
              compWidth: sidebar.barWidth*.7
              screenName: sidebar.screen.name
              sidebarWidth: sidebar.barWidth
              onWifiRequested: network => { GlobalMenuState.isVisible = false; settingsMenu.openWifi(network) }
            }
            Item {
              id: gearSlot
              Layout.fillWidth: true
              Layout.preferredHeight: root.settingsGearPreview && gearHover.containsMouse ? sidebar.barWidth * .8 : 0
              Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
              }
            }
          }

          // A small bottom-edge hotspot grows with the revealed button,
          // keeping it visible while moving the pointer onto the gear.
          MouseArea {
            id: gearHover
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(10, gearSlot.height + sidebar.barWidth * .167)
            enabled: root.settingsGearPreview
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Toggle settings"
            Keys.onReturnPressed: { GlobalMenuState.isVisible = false; settingsMenu.visible = !settingsMenu.visible }
            Keys.onSpacePressed: { GlobalMenuState.isVisible = false; settingsMenu.visible = !settingsMenu.visible }
            hoverEnabled: true
            cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
            z: 10
            onClicked: { GlobalMenuState.isVisible = false; settingsMenu.visible = !settingsMenu.visible }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: sidebar.barWidth * .167
              width: sidebar.barWidth * .65
              height: width
              radius: width / 2
              color: gearHover.pressed ? "#58506d" : "#313244"
              opacity: root.settingsGearPreview && gearHover.containsMouse ? 1 : 0
              scale: gearHover.pressed ? .9 : 1
              Behavior on opacity { NumberAnimation { duration: 150 } }
              Behavior on scale { NumberAnimation { duration: 100 } }

              Text {
                anchors.centerIn: parent
                text: "󰒓"
                font.family: "mononoki Nerd Font"
                font.pixelSize: sidebar.barWidth * .39
                color: "#cba6f7"
              }
            }
          }
        }
      }
    }
  }
}
