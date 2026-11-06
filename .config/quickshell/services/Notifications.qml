pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../components"
import "../globals"

Scope {
  id: root
  property int defaultTimeout: 10000

  readonly property var warningService: BatteryMonitor

  PanelWindow {
    id: window
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; right: true }
    margins { top: 16; right: 16 }
    implicitWidth: Math.min(400, (screen?.width ?? 432) - 32)
    implicitHeight: Math.min(stack.implicitHeight + 16, (screen?.height ?? 800) - 32)
    visible: NotificationCenter.notifications.values.length > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    mask: Region { item: stack }

    Flickable {
      anchors.fill: parent
      contentHeight: stack.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: stack
        width: parent.width
        spacing: 12

        Repeater {
          model: NotificationCenter.notifications
          delegate: NotificationPopup {
            required property var modelData
            notification: modelData
            width: stack.width
            defaultTimeout: root.defaultTimeout
          }
        }
      }
    }
  }
}
