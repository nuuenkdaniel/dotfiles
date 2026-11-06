pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../globals" // BATTERY FEATURE IMPORT
import "../globals"

PanelWindow {
  id: root
  visible: false
  color: "transparent"
  property int sidebarWidth: 55
  property string activeTab: "Audio"
  property var pendingWifiNetwork: null
  function openWifi(network) {
    pendingWifiNetwork = network
    activeTab = "Wi-Fi"
    visible = true
    Qt.callLater(root.deliverWifiRequest)
  }
  function deliverWifiRequest() {
    if (!visible || activeTab !== "Wi-Fi") { pendingWifiNetwork = null; return }
    if (!pendingWifiNetwork || !connectivityPage.item) return
    const network = pendingWifiNetwork
    pendingWifiNetwork = null
    connectivityPage.item.requestWifiConnection(network)
  }
  onActiveTabChanged: if (activeTab !== "Wi-Fi") pendingWifiNetwork = null
  readonly property var baseTabs: ["Wi-Fi", "Bluetooth", "Audio", "Display", "Dashboard", "Notifications", "About"]
  readonly property var tabIcons: ({ "Wi-Fi": "󰤨", "Bluetooth": "󰂯", "Audio": "󰕾", "Display": "󰃠", "Dashboard": "󰕮", "Notifications": "󰂚", "About": "󰋽" })
  onVisibleChanged: {
    if (visible) { DashboardState.opened = false; GlobalMenuState.isVisible = false }
    else pendingWifiNetwork = null
  }
  Connections {
    target: DashboardState
    function onOpenedChanged() { if (DashboardState.opened) root.visible = false }
  }
  property bool resumeAfterAuthorization: false // BATTERY FEATURE PROPERTY
  readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)
  readonly property var inputs: Pipewire.nodes.values.filter(node => node.audio && !node.isSink && !node.isStream)

  PwObjectTracker {
    objects: root.visible && root.activeTab === "Audio" ? root.outputs.concat(root.inputs) : []
  }

  // BEGIN BATTERY AUTHORIZATION
  Connections {
    target: PowerManagement
    function onAuthorizingChanged() {
      if (PowerManagement.authorizing && root.visible) {
        // A layer-shell overlay must not cover the system authentication dialog.
        root.resumeAfterAuthorization = true
        root.visible = false
      } else if (!PowerManagement.authorizing && root.resumeAfterAuthorization) {
        root.resumeAfterAuthorization = false
        root.visible = true
      }
    }
  }
  // END BATTERY AUTHORIZATION

  anchors { left: true; right: true; top: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "shell-settings"
  WlrLayershell.keyboardFocus: visible && !PowerManagement.authorizing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None // BATTERY FEATURE FOCUS

  MouseArea {
    anchors.fill: parent
    onClicked: root.visible = false
  }

  Rectangle {
    id: panel
    anchors.centerIn: parent
    width: Math.min(760, root.width - 24)
    height: Math.min(root.activeTab === "Battery" ? Math.max(520, batteryPage.item?.preferredHeight ?? 440) : 600, root.height - 24) // BATTERY FEATURE HEIGHT
    radius: 18
    color: "#1e1e2e"
    border.width: 1
    border.color: "#6b587f"
    focus: root.visible
    Keys.onEscapePressed: root.visible = false

    // Consume panel clicks so only clicks outside dismiss the menu.
    MouseArea { anchors.fill: parent }

    RowLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 24

      Rectangle {
        Layout.preferredWidth: Math.min(180, panel.width * .27)
        Layout.fillHeight: true
        radius: 12
        color: "transparent"

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 6

          Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 18
            text: "Settings"
            color: "#cdd6f4"
            font.pixelSize: 21
            font.bold: true
            elide: Text.ElideRight
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: navigation.implicitHeight
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            ColumnLayout {
              id: navigation
              width: parent.width
              spacing: 6
          Repeater {
            model: root.baseTabs.slice(0, 3).concat(["Battery"], root.baseTabs.slice(3)) // BATTERY FEATURE TABS
            delegate: Rectangle {
             id: tab
            required property string modelData
            Layout.fillWidth: true
            implicitHeight: 44
             radius: 10
             activeFocusOnTab: true
             Accessible.role: Accessible.Button
             Accessible.name: modelData
             Keys.onReturnPressed: root.activeTab = modelData
             Keys.onSpacePressed: root.activeTab = modelData
            color: tabHover.hovered ? "#494057" : root.activeTab === modelData ? "#302a3d" : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
            Rectangle {
              visible: root.activeTab === tab.modelData
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: 3
              height: 22
              radius: 1.5
              color: "#cba6f7"
            }
            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 10
              Text {
                text: tab.modelData === "Battery" ? "󰁹" : root.tabIcons[tab.modelData] // BATTERY FEATURE ICON
                font.family: "mononoki Nerd Font"
                font.pixelSize: 20
                color: "#cba6f7"
              }
              Text {
                Layout.fillWidth: true
                text: tab.modelData
                color: "#cba6f7"
                font.pixelSize: 14
                font.bold: true
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = tab.modelData
            }
           }
          }
            }
          }
        }
      }

      ColumnLayout {
        visible: root.activeTab === "Audio"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: 12
        Layout.rightMargin: 8
        Layout.bottomMargin: 8
        spacing: 16

      Text {
        text: "Audio"
        color: "#cdd6f4"
        font.pixelSize: 24
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        text: "Choose your default speakers and microphone."
        color: "#bac2de"
        font.pixelSize: 13
        wrapMode: Text.Wrap
      }

      Flickable {
        id: deviceScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: deviceList.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
          id: deviceList
          width: deviceScroll.width - (deviceScroll.contentHeight > deviceScroll.height ? 12 : 0)
          spacing: 5

          Text {
            text: "Output devices"
            color: "#cba6f7"
            font.pixelSize: 14
            font.bold: true
          }
          Repeater {
            model: root.outputs
            delegate: DeviceRow {
              required property var modelData
              node: modelData
              selected: Pipewire.defaultAudioSink === node
              onChosen: Pipewire.preferredDefaultAudioSink = node
            }
          }
          Text {
            visible: root.outputs.length === 0
            text: Pipewire.ready ? "No output devices available" : "Connecting to PipeWire…"
            color: "#bac2de"
            font.pixelSize: 13
          }
          Item { implicitHeight: 10 }
          Text {
            text: "Input devices"
            color: "#cba6f7"
            font.pixelSize: 14
            font.bold: true
          }
          Repeater {
            model: root.inputs
            delegate: DeviceRow {
              required property var modelData
              node: modelData
              selected: Pipewire.defaultAudioSource === node
              onChosen: Pipewire.preferredDefaultAudioSource = node
            }
          }
          Text {
            visible: root.inputs.length === 0
            text: Pipewire.ready ? "No input devices available" : "Connecting to PipeWire…"
            color: "#bac2de"
            font.pixelSize: 13
          }
        }
      }
    }
      LazySettingsPage {
        id: connectivityPage
        onLoaded: Qt.callLater(root.deliverWifiRequest)
        selected: root.activeTab === "Wi-Fi" || root.activeTab === "Bluetooth"
        panelActive: root.visible
        sourceComponent: ConnectivitySettings {
          active: connectivityPage.pageActive
          bluetooth: root.activeTab === "Bluetooth"
        }
      }
      LazySettingsPage {
        id: displayPage
        selected: root.activeTab === "Display"
        panelActive: root.visible
        sourceComponent: DisplaySettings { active: displayPage.pageActive }
      }
      LazySettingsPage {
        id: notificationPage
        selected: root.activeTab === "Notifications"
        panelActive: root.visible
        sourceComponent: NotificationHistory { active: notificationPage.pageActive; onCloseRequested: root.visible = false }
      }
      LazySettingsPage {
        id: dashboardPage
        selected: root.activeTab === "Dashboard"
        panelActive: root.visible
        sourceComponent: DashboardSettings { active: dashboardPage.pageActive }
      }
      LazySettingsPage {
        id: aboutPage
        selected: root.activeTab === "About"
        panelActive: root.visible
        sourceComponent: AboutSettings { active: aboutPage.pageActive; onCloseRequested: root.visible = false }
      }
      // BEGIN BATTERY PAGE
      LazySettingsPage {
        id: batteryPage
        selected: root.activeTab === "Battery"
        panelActive: root.visible
        sourceComponent: BatterySettings { active: batteryPage.pageActive; onCloseRequested: root.visible = false }
      }
      // END BATTERY PAGE
    }
  }

  component DeviceRow: Rectangle {
    id: row
    required property var node
    property bool selected: false
    signal chosen()
    Layout.fillWidth: true
    implicitHeight: 64
    radius: 8
    color: rowHover.hovered ? "#3b3549" : selected ? "#292534" : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }
    HoverHandler { id: rowHover }

    // Behind the controls: empty space selects the device, while sliders
    // and mute buttons retain their own pointer handling.
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: row.chosen()
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 6
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 3

      Item {
        Layout.fillWidth: true
        implicitHeight: 22
        RowLayout {
          anchors.fill: parent
          spacing: 8
      Text {
        text: row.node.isSink ? "󰓃" : "󰍬"
        font.family: "mononoki Nerd Font"
        font.pixelSize: 19
        color: row.selected ? "#cba6f7" : "#bac2de"
      }
        Text {
          Layout.fillWidth: true
          text: {
            const description = row.node.description || row.node.nickname || row.node.name
            return description.replace(/^Core Ultra Processors \(Series \d+\) HD Audio\s*/i, "Built-in · ")
              .replace(/\s*\(Stereo\)\s*$/i, "")
          }
          textFormat: Text.PlainText
          color: "#cdd6f4"
          font.pixelSize: 13
          elide: Text.ElideRight
        }
        }
        MouseArea {
          id: nameMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: row.chosen()
          ShellToolTip {
            visible: nameMouse.containsMouse
            delay: 700
            text: row.node.description || row.node.name
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          implicitWidth: 28
          implicitHeight: 26
          radius: 7
          color: muteMouse.containsMouse ? "#58506d" : "#313244"
          Text {
            anchors.centerIn: parent
            text: row.node.isSink
              ? (row.node.audio?.muted ? "󰖁" : "󰕾")
              : (row.node.audio?.muted ? "󰍭" : "󰍬")
            font.family: "mononoki Nerd Font"
            font.pixelSize: 17
            color: row.node.audio?.muted ? "#f38ba8" : "#cba6f7"
          }
          MouseArea {
            id: muteMouse
            anchors.fill: parent
            enabled: row.node.ready
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.node.audio.muted = !row.node.audio.muted
          }
        }

        Slider {
          id: volumeSlider
          Layout.fillWidth: true
          Layout.preferredHeight: 26
          from: 0
          to: 1
          enabled: row.node.ready
          value: row.node.audio?.volume ?? 0
          onMoved: row.node.audio.volume = value
          background: Rectangle {
            x: volumeSlider.leftPadding
            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
            width: volumeSlider.availableWidth
            height: 5
            radius: 2.5
            color: "#45475a"
            Rectangle {
              width: volumeSlider.visualPosition * parent.width
              height: parent.height
              radius: parent.radius
              color: "#cba6f7"
            }
          }
          handle: Rectangle {
            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
            width: volumeSlider.pressed ? 16 : 13
            height: width
            radius: width / 2
            color: volumeSlider.hovered || volumeSlider.pressed ? "#e2c5ff" : "#cba6f7"
          }
        }

        Text {
          Layout.preferredWidth: 36
          horizontalAlignment: Text.AlignRight
          text: Math.round((row.node.audio?.volume ?? 0) * 100) + "%"
          color: "#bac2de"
          font.pixelSize: 11
        }
      }
    }
  }
}
