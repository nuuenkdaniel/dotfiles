pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import "../globals"

ColumnLayout {
  id: root
  property bool active: false
  property bool preferencesOpen: true
  property bool processorOpen: false
  property bool automationOpen: false
  property bool chargingOpen: false
  property bool maintenanceOpen: false
  signal closeRequested()
  property bool chargingDirty: false
  property string draftMode: ""
  property int draftStart: 50
  property int draftStop: 90
  readonly property var power: PowerManagement.state
  readonly property var prefs: PowerManagement.prefs
  readonly property var battery: UPower.displayDevice
  readonly property bool saver: power.selectedMode === "saver"
  readonly property bool custom: power.selectedMode === "custom"
  readonly property bool available: !!power.profile
  readonly property bool locked: PowerManagement.busy || !!power.pendingDisplay
  readonly property var charge: power.charging ?? ({})
  readonly property var modeNames: ({ "Fast": "ExpressCharge", "Standard": "Standard", "Adaptive": "Adaptive", "Trickle": "AC use", "Custom": "Custom" })
  readonly property var chargingDescriptions: ({
    "Fast": "Prioritize faster charging when supported by the battery and charger.",
    "Standard": "Charge normally using Dell's standard charging policy.",
    "Adaptive": "Let Dell firmware adapt charging to your usage patterns.",
    "Trickle": "Favor battery longevity when the laptop is plugged in most of the time.",
    "Custom": "Choose when charging starts and stops. Keep at least 5% between the two values."
  })
  readonly property bool chargingHasChanges: draftMode !== (charge.mode ?? "")
    || (draftMode === "Custom" && (draftStart !== charge.start || draftStop !== charge.stop))
  readonly property int preferredHeight: Math.min(600, Math.max(440, page.implicitHeight + 100))
  spacing: 12

  function duration(seconds) {
    if (root.battery.state === UPowerDeviceState.FullyCharged) return "Fully charged"
    if (root.battery.state === UPowerDeviceState.PendingCharge) return "Charging paused"
    if (!seconds || seconds <= 0) return "Estimating time remaining…"
    const minutes = Math.round(seconds / 60)
    const hours = Math.floor(minutes / 60)
    return (hours ? hours + "h " : "") + minutes % 60 + "m " + (UPower.onBattery ? "remaining" : "until full")
  }

  function syncDrafts() {
    if (!chargingDirty) {
      draftMode = charge.mode ?? ""
      draftStart = charge.start ?? 50
      draftStop = charge.stop ?? 90
    }
  }

  onActiveChanged: {
    PowerManagement.visiblePanels += active ? 1 : -1
    DisplayState.visiblePanels += active ? 1 : -1
    if (active) { syncDrafts(); PowerManagement.run(["status"]) }
  }
  Component.onDestruction: if (active) { PowerManagement.visiblePanels -= 1; DisplayState.visiblePanels -= 1 }
  Connections {
    target: PowerManagement
    function onStateChanged() { root.syncDrafts() }
    function onActionFinished(action, success) {
      if (action === "charging" && success) {
        root.chargingDirty = false
        root.syncDrafts()
      }
    }
  }

  Text { text: "Battery"; color: "#cdd6f4"; font.pixelSize: 24; font.bold: true }

  Flickable {
    id: scroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    contentHeight: page.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
      id: page
      width: scroll.width - (scroll.contentHeight > scroll.height ? 12 : 0)
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 8
        spacing: 16
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text {
            text: root.battery.ready ? Math.round(root.battery.percentage * 100) + "%" : "—"
            color: "#cdd6f4"
            font.pixelSize: 36
            font.bold: true
          }
          Note {
            text: (UPower.onBattery ? "On battery · " : "Plugged in · ") + (root.battery.ready ? root.duration(UPower.onBattery ? root.battery.timeToEmpty : root.battery.timeToFull)
              + (root.battery.changeRate ? " · " + Math.abs(root.battery.changeRate).toFixed(1) + " W" : "") : ""
              )
          }
        }
        Item {
          implicitWidth: 58
          implicitHeight: 34
          readonly property color fillColor: root.battery.percentage <= .2 ? "#f38ba8" : root.saver ? "#a6e3a1" : "#cba6f7"
          Rectangle {
            id: batteryOutline
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 50; height: 30; radius: 6
            color: "transparent"
            border.width: 2
            border.color: "#6c6680"
            Rectangle {
              x: 5; y: 5
              width: Math.max(0, Math.min(1, root.battery.percentage)) * 40
              height: 20; radius: 3
              color: parent.parent.fillColor
              Behavior on width { NumberAnimation { duration: 200 } }
            }
          }
          Rectangle {
            anchors.left: batteryOutline.right
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 4; height: 12; radius: 2; color: "#6c6680"
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 70
        radius: 13
        color: "#181825"
        RowLayout {
          anchors.fill: parent
          anchors.margins: 4
          spacing: 4
        Repeater {
          model: [
            { label: "Performance", mode: "performance", icon: "speed" },
            { label: "Balanced", mode: "balanced", icon: "balance" },
            { label: "Power saving", mode: "saver", icon: "eco" },
            { label: "Custom", mode: "custom", icon: "tune" }
          ]
          delegate: Rectangle {
            id: modeButton
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            readonly property bool selected: root.available && root.power.selectedMode === modelData.mode
            enabled: root.available && !root.locked && (modelData.mode !== "performance" || (root.power.profiles ?? []).includes("performance"))
            radius: 10
            opacity: enabled ? 1 : .4
            color: selected ? "#40344f" : modeMouse.containsMouse ? "#2b2939" : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            ColumnLayout {
              anchors.centerIn: parent
              spacing: 4
              MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: modeButton.modelData.icon
                iconSize: 22
                color: modeButton.selected ? "#cba6f7" : "#9399b2"
                fill: modeButton.selected ? 1 : 0
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: modeButton.modelData.label
                font.pixelSize: 11
                font.bold: modeButton.selected
                color: modeButton.selected ? "#e0c5ff" : "#bac2de"
              }
            }
            MouseArea {
              id: modeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: PowerManagement.run(["mode", modeButton.modelData.mode])
            }
          }
        }
        }
      }
      Note {
        visible: root.available
        text: root.custom ? "Your saved configuration · Based on " + root.power.profile
          : root.saver ? "CPU boost off, a 60 Hz display, and lower brightness. Keyboard lighting stays under your control."
          : root.power.profile === "performance" ? "Prioritizes responsiveness and sustained performance."
          : "Everyday responsiveness, balanced with battery life."
      }
      RowLayout {
        visible: root.saver
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 14
        Repeater {
          model: [{icon: "eco", label: root.power.cpu?.boost ? "Boost on" : "Boost off"}, {icon: "brightness_6", label: "40% on entry"}, {icon: "refresh", label: String(root.power.monitor?.rate ?? "—") + " Hz"}]
          delegate: RowLayout {
            required property var modelData
            spacing: 5
            MaterialSymbol { text: modelData.icon; iconSize: 16; color: "#a6e3a1" }
            Text { text: modelData.label; color: "#bac2de"; font.pixelSize: 10 }
          }
        }
        Item { Layout.fillWidth: true }
      }
      Note {
        visible: !!root.power.manualOverride && (root.prefs.autoLow || root.prefs.autoUnplug || root.prefs.normalOnAc)
        text: "Manual override · Automatic switching resumes after plug/unplug."
        font.pixelSize: 11
        color: "#9399b2"
      }
      Note {
        visible: root.available && !(root.power.profiles ?? []).includes("performance")
        text: "Performance mode is not supported by the current driver."
      }
      Note {
        visible: !root.available || !root.power.helperInstalled || !root.power.boostPermissionInstalled
        text: !root.available
          ? "One-time setup required for power modes. Run in a terminal:\nbash ~/.config/quickshell/bin/setup-power.sh"
          : !root.power.helperInstalled ? "CPU and charging controls need the protected helper. Run:\nbash ~/.config/quickshell/bin/setup-power.sh"
          : "One-time setup update for passwordless boost toggles:\nbash ~/.config/quickshell/bin/setup-power.sh"
      }
      Action {
        visible: !root.available || !root.power.helperInstalled || !root.power.boostPermissionInstalled
        label: "Open setup terminal…"
        onClicked: {
          const script = decodeURIComponent(Qt.resolvedUrl("../bin/setup-power.sh").toString().replace("file://", ""))
          Quickshell.execDetached(["kitty", "--hold", "bash", script])
          root.closeRequested()
        }
      }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: errorLabel.implicitHeight + 20
        visible: PowerManagement.error.length > 0
        color: "#352632"
        radius: 8
        Text {
          id: errorLabel
          anchors.fill: parent
          anchors.margins: 10
          text: PowerManagement.error
          textFormat: Text.PlainText
          color: "#f38ba8"
          font.pixelSize: 12
          wrapMode: Text.Wrap
        }
      }
      RowLayout {
        visible: !!root.power.pendingDisplay
        Layout.fillWidth: true
        Note { text: "Keep 60 Hz? Reverts automatically after 15 seconds."; Layout.fillWidth: true }
        Action { label: "Keep"; enabled: !PowerManagement.busy; onClicked: PowerManagement.run(["confirm-display"]) }
        Action { label: "Revert"; enabled: !PowerManagement.busy; onClicked: PowerManagement.run(["revert-display"]) }
      }

      Section {
        visible: root.custom
        title: "Custom configuration"
        expanded: root.preferencesOpen
        onClicked: root.preferencesOpen = !root.preferencesOpen
      }
      ColumnLayout {
        visible: root.custom && root.preferencesOpen
        Layout.fillWidth: true
        spacing: 8
        Note { text: "Saved separately from the recommended preset. Choose a base profile and adjustments, then Apply Custom. Brightness and keyboard buttons below update immediately and are remembered." }
        RowLayout {
          Layout.fillWidth: true
          Note { text: "Start from" }
          ComboBox {
            model: root.power.profiles ?? ["balanced", "power-saver"]
            currentIndex: (root.power.profiles ?? ["balanced", "power-saver"]).indexOf(root.prefs.customBase ?? "balanced")
            enabled: !root.locked
            palette.button: "#313244"
            palette.buttonText: "#cba6f7"
            palette.base: "#1e1e2e"
            palette.text: "#cdd6f4"
            palette.highlight: "#40354f"
            onActivated: PowerManagement.preference("customBase", currentText)
          }
        }
        Toggle {
          label: "Limit screen brightness"
          checked: root.prefs.limitBrightness ?? false
          enabled: !!root.power.brightness && !root.locked
          onChanged: value => PowerManagement.preference("limitBrightness", value)
        }
        Adjustment {
          visible: root.prefs.limitBrightness ?? false
          label: "Brightness cap"
          value: root.prefs.brightnessCap ?? 40
          from: 5; to: 100
          enabled: !root.locked
          onCommitted: value => PowerManagement.preference("brightnessCap", value)
        }
        Toggle {
          label: "Reduce display to 60 Hz"
          checked: root.prefs.reduceRefresh ?? false
          enabled: !!root.power.monitor?.supports60 && !root.locked
          onChanged: value => PowerManagement.preference("reduceRefresh", value)
        }
        Toggle {
          label: "Turn off keyboard lighting"
          checked: root.prefs.keyboardOff ?? false
          enabled: root.power.keyboard?.current != null && !root.locked
          onChanged: value => PowerManagement.preference("keyboardOff", value)
        }
        Toggle {
          label: "Reduce blur, shadows and animations"
          checked: root.prefs.reduceEffects ?? false
          enabled: !root.locked
          onChanged: value => PowerManagement.preference("reduceEffects", value)
        }
        Action {
          label: "Apply Custom"
          enabled: !root.locked
          onClicked: PowerManagement.run(["apply-preset"])
        }
        Adjustment {
          label: "Screen brightness now"
          from: 1; to: 100
          value: root.power.brightness?.maximum ? Math.round(Math.max(0, PowerManagement.liveBrightness) / root.power.brightness.maximum * 100) : 0
          enabled: !!root.power.brightness && !root.locked
          onCommitted: value => PowerManagement.run(["brightness", String(value)])
        }
        RowLayout {
          Layout.fillWidth: true
          visible: root.power.keyboard?.maximum === 2
          Note { text: "Keyboard lighting now"; Layout.fillWidth: true }
          Repeater {
            model: ["Off", "Low", "High"]
            delegate: Action {
              required property string modelData
              required property int index
              label: modelData
              selected: root.power.keyboard?.current === index
              enabled: !root.locked
              onClicked: PowerManagement.run(["keyboard", String(index)])
            }
          }
        }
      }

      Section { visible: root.custom; title: "Custom processor limits"; expanded: root.processorOpen; onClicked: root.processorOpen = !root.processorOpen }
      ColumnLayout {
        visible: root.custom && root.processorOpen
        Layout.fillWidth: true
        spacing: 8
        Note { text: "Energy preference: " + (root.power.cpu?.preference ?? "Unavailable") + ". The profile daemon manages this automatically." }
        Note { text: "Optional limits apply with Custom and are restored when switching modes. Performance-limit changes require authorization; boost-only changes use the local-session permission." }
        Toggle {
          label: "Override CPU limits in Custom"
          checked: root.prefs.customCpuEnabled ?? false
          enabled: !!root.power.helperInstalled && !root.locked
          onChanged: value => PowerManagement.preference("customCpuEnabled", value)
        }
        Toggle {
          visible: root.prefs.customCpuEnabled ?? false
          label: "Allow CPU boost"
          checked: root.prefs.customBoost ?? true
          enabled: !!root.power.helperInstalled && root.power.cpu?.limit != null && !root.locked
          onChanged: value => PowerManagement.preference("customBoost", value)
        }
        Adjustment {
          visible: root.prefs.customCpuEnabled ?? false
          label: "Maximum CPU performance"
          from: Math.max(20, root.power.cpu?.minimum ?? 20); to: 100
          value: root.prefs.customLimit ?? 100
          enabled: !!root.power.helperInstalled && root.power.cpu?.limit != null && !root.locked
          onCommitted: value => PowerManagement.preference("customLimit", value)
        }
        Note { text: "This limits the permitted performance level, not CPU usage or power in watts. Profile changes may also affect effective limits." }
        Action {
          label: "Apply Custom"
          enabled: !root.locked
          onClicked: PowerManagement.run(["apply-preset"])
        }
      }

      Section {
        title: "Automatic switching"
        icon: "schedule"
        detail: root.prefs.autoLow || root.prefs.autoUnplug || root.prefs.normalOnAc ? "Enabled" : "Off"
        expanded: root.automationOpen
        onClicked: root.automationOpen = !root.automationOpen
      }
      ColumnLayout {
        visible: root.automationOpen
        Layout.fillWidth: true
        spacing: 8
        Toggle {
          label: "Enable below battery level"
          checked: root.prefs.autoLow ?? false
          enabled: root.available && !root.locked
          onChanged: value => PowerManagement.preference("autoLow", value)
        }
        Adjustment {
          visible: root.prefs.autoLow ?? false
          label: "Battery level"
          from: 5; to: 50
          value: root.prefs.lowThreshold ?? 20
          enabled: !root.locked
          onCommitted: value => PowerManagement.preference("lowThreshold", value)
        }
        Toggle {
          label: "Use Power saving when unplugged"
          checked: root.prefs.autoUnplug ?? false
          enabled: root.available && !root.locked
          onChanged: value => PowerManagement.preference("autoUnplug", value)
        }
        Toggle {
          label: "Return to Balanced when plugged in"
          checked: root.prefs.normalOnAc ?? false
          enabled: root.available && !root.locked
          onChanged: value => PowerManagement.preference("normalOnAc", value)
        }
        Note { text: "Rules react to UPower battery and charger updates; no background polling timer. Manual mode selection pauses them until the next plug/unplug. Low-battery mode has a 5% recovery margin." }
        Note { text: "Boost toggles are automatic after installing the boost-only permission. Custom CPU-limit changes still require authorization; background rules never open password prompts." }
      }

      Section {
        title: "Charging & battery health"
        icon: "battery_charging_full"
        detail: root.charge.mode === "Fast" ? "ExpressCharge" : root.charge.mode ?? ""
        expanded: root.chargingOpen
        onClicked: root.chargingOpen = !root.chargingOpen
      }
      ColumnLayout {
        visible: root.chargingOpen
        Layout.fillWidth: true
        spacing: 12
        RowLayout {
          Layout.fillWidth: true
          Note { text: "Active · " + (root.modeNames[root.charge.mode] ?? root.charge.mode ?? "Unavailable") }
          Text {
            visible: root.chargingHasChanges
            text: "Unsaved changes"
            color: "#f9e2af"
            font.pixelSize: 11
          }
        }
        Flow {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: ["Standard", "Adaptive", "Fast", "Trickle", "Custom"].filter(mode => (root.charge.modes ?? []).includes(mode))
            delegate: Action {
              required property string modelData
              label: root.modeNames[modelData] ?? modelData
              selected: root.draftMode === modelData
              enabled: !!root.power.helperInstalled && !root.locked
              onClicked: {
                if (root.draftMode !== modelData) {
                  root.draftMode = modelData
                  root.chargingDirty = true
                }
              }
            }
          }
        }
        Note { text: root.chargingDescriptions[root.draftMode] ?? "No supported charging controls were reported." }
        Adjustment {
          visible: root.draftMode === "Custom"
          label: "Start charging below"
          from: 50; to: 95
          value: root.draftStart
          enabled: root.draftMode === "Custom" && root.power.helperInstalled && !root.locked
          onCommitted: value => { root.draftStart = value; root.chargingDirty = true }
        }
        Adjustment {
          visible: root.draftMode === "Custom"
          label: "Stop charging at"
          from: 55; to: 100
          value: root.draftStop
          enabled: root.draftMode === "Custom" && root.power.helperInstalled && !root.locked
          onCommitted: value => { root.draftStop = value; root.chargingDirty = true }
        }
        Note {
          visible: root.draftMode === "Custom" && root.draftStop - root.draftStart < 5
          text: "Stop must be at least 5% above start."
          color: "#f38ba8"
        }
        RowLayout {
          visible: root.chargingHasChanges || root.chargingDirty
          Action {
            label: "Apply changes…"
            enabled: root.chargingHasChanges && !!root.power.helperInstalled && !root.locked && (root.draftMode !== "Custom" || root.draftStop - root.draftStart >= 5)
            onClicked: {
              PowerManagement.run(["charging", root.draftMode, String(root.draftStart), String(root.draftStop)])
            }
          }
          Action {
            label: "Discard"
            enabled: root.chargingDirty && !root.locked
            onClicked: { root.chargingDirty = false; root.syncDrafts() }
          }
        }
        Note {
          visible: root.draftMode === "Custom"
          text: "Lower charge limits can help longevity, but leave less charge available when unplugged."
          font.pixelSize: 11
        }
        Note {
          text: "Battery health: " + (root.battery.healthSupported ? Math.round(root.battery.healthPercentage) + "%" : "Not reported")
            + " · Cycles: " + (root.charge.cycles ?? "Not reported")
        }
      }
      Section {
        title: "Maintenance"
        icon: "settings_backup_restore"
        expanded: root.maintenanceOpen
        onClicked: root.maintenanceOpen = !root.maintenanceOpen
      }
      ColumnLayout {
        visible: root.maintenanceOpen
        Layout.fillWidth: true
        spacing: 8
        Note { text: "Restore your saved baseline and remove this Battery feature. Other shell features stay intact." }
        Action {
          label: "Cleanup / uninstall…"
          enabled: !root.locked
          onClicked: {
            const script = decodeURIComponent(Qt.resolvedUrl("../bin/uninstall-power.sh").toString().replace("file://", ""))
            Quickshell.execDetached(["kitty", "--hold", "bash", script])
            root.closeRequested()
          }
        }
      }
    }
  }

  component Note: Text {
    Layout.fillWidth: true
    color: "#bac2de"
    font.pixelSize: 12
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
  }

  component Action: Rectangle {
    id: button
    property string label
    property bool selected: false
    signal clicked()
    implicitWidth: caption.implicitWidth + 22
    implicitHeight: 34
    radius: 9
    opacity: enabled ? 1 : .45
    color: selected ? "#49395f" : mouse.containsMouse ? "#454052" : "#313244"
    Text { id: caption; anchors.centerIn: parent; text: button.label; color: "#cba6f7"; font.pixelSize: 12; font.bold: button.selected }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
  }

  component Section: Item {
    id: section
    property string title
    property string icon: ""
    property string detail: ""
    property bool expanded: false
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 42
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#313244" }
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 3
      radius: 8
      color: "#292635"
      opacity: sectionMouse.containsMouse ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6
      anchors.rightMargin: 6
      spacing: 10
      MaterialSymbol { visible: section.icon.length > 0; text: section.icon; iconSize: 19; color: "#9399b2" }
      Text { Layout.fillWidth: true; text: section.title; color: "#cdd6f4"; font.pixelSize: 13; font.bold: section.expanded }
      Text { visible: section.detail.length > 0; text: section.detail; color: "#9399b2"; font.pixelSize: 11 }
      MaterialSymbol {
        text: "expand_more"
        iconSize: 20
        color: "#9399b2"
        rotation: section.expanded ? 0 : -90
        Behavior on rotation { NumberAnimation { duration: 150 } }
      }
    }
    MouseArea { id: sectionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: section.clicked() }
  }

  component Toggle: RowLayout {
    id: control
    property string label
    property bool checked: false
    signal changed(bool value)
    Layout.fillWidth: true
    implicitHeight: 32
    opacity: enabled ? 1 : .45
    Note { text: control.label }
    Switch {
      id: toggle
      checked: control.checked
      Accessible.name: control.label
      onToggled: control.changed(checked)
      indicator: Rectangle {
        implicitWidth: 38; implicitHeight: 21
        x: toggle.leftPadding; y: (toggle.height - height) / 2
        radius: 11
        color: toggle.checked ? "#cba6f7" : "#45475a"
        Rectangle {
          x: toggle.checked ? 20 : 3; y: 3
          width: 15; height: 15; radius: 8
          color: toggle.checked ? "#1e1e2e" : "#cdd6f4"
          Behavior on x { NumberAnimation { duration: 120 } }
        }
      }
    }
  }

  component Adjustment: ColumnLayout {
    id: adjustment
    property string label
    property real value: 0
    property real from: 0
    property real to: 100
    signal committed(int value)
    Layout.fillWidth: true
    spacing: 2
    opacity: enabled ? 1 : .45
    RowLayout {
      Layout.fillWidth: true
      Note { text: adjustment.label }
      Text { text: Math.round(slider.value) + "%"; color: "#cba6f7"; font.pixelSize: 12 }
    }
    Slider {
      id: slider
      property bool dragging: false
      property real pendingValue: 0
      Layout.fillWidth: true
      implicitHeight: 24
      from: adjustment.from
      to: adjustment.to
      stepSize: 1
      Binding {
        target: slider
        property: "value"
        value: adjustment.value
        when: !slider.pressed && !slider.dragging
        restoreMode: Binding.RestoreNone
      }
      Accessible.name: adjustment.label
      onMoved: {
        pendingValue = value
        if (!pressed) adjustment.committed(Math.round(value))
      }
      onPressedChanged: {
        if (pressed) {
          dragging = true
          pendingValue = value
        } else if (dragging) {
          // Commit the dragged value before re-enabling the external binding.
          adjustment.committed(Math.round(pendingValue))
          dragging = false
        }
      }
      background: Rectangle {
        x: slider.leftPadding; y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth; height: 5; radius: 3; color: "#45475a"
        Rectangle { width: parent.width * slider.visualPosition; height: parent.height; radius: 3; color: "#cba6f7" }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: 13; height: 13; radius: 7
        color: slider.pressed || slider.hovered ? "#e2c5ff" : "#cba6f7"
      }
    }
  }
}
