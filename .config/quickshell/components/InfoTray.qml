pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell // BATTERY INDICATOR IMPORT
import Quickshell
import "./"
import "../globals"

ColumnLayout {
  id: root

  property int compWidth: 0
  property int spacerHeight: compWidth*.167

  readonly property string dayName: Qt.formatDate(ShellClock.now, "ddd").toUpperCase()
  readonly property string dayNumber: Qt.formatDate(ShellClock.now, "dd")
  readonly property date calendarDate: ShellClock.now

  readonly property string hours: Qt.formatDateTime(ShellClock.now, "hh")
  readonly property string minutes: Qt.formatDateTime(ShellClock.now, "mm")

  property var mouseDevice: {
    let allDevices = UPower.devices.values;
    for (let i = 0; i < allDevices.length; i++) {
      if (allDevices[i].type === UPowerDeviceType.Mouse) {
        // console.log(allDevices[i].percentage)
        return allDevices[i];
      }
    }
    return null;
  }
  property bool haveMouseBattery: mouseDevice !== null
  property int mouseBatteryLevel: mouseDevice? mouseDevice.percentage*100 : 0
  property string mouseBatteryColor: "#BADCBD"

  property var mainBattery: UPower.displayDevice
  property bool haveBattery: mainBattery? mainBattery.isLaptopBattery : false
  property int batteryLevel: mainBattery? Math.round(mainBattery.percentage*100) : 100
  property bool isCharging: !UPower.onBattery
  property string batteryGlyph: ""
  property string batteryColor: "#BADCBD"
  // BEGIN BATTERY INDICATOR STATE
  readonly property bool powerSaving: PowerProfiles.profile === PowerProfile.PowerSaver
  // END BATTERY INDICATOR STATE

  onMouseBatteryLevelChanged: updateMouseBatteryVisuals()
  onHaveMouseBatteryChanged: updateMouseBatteryVisuals()
  function updateMouseBatteryVisuals() {
    if (!haveMouseBattery) return;

    if (mouseBatteryLevel <= 10) { 
      mouseBatteryColor = "#F32013"; 
    } else if (mouseBatteryLevel <= 25) { 
      mouseBatteryColor = "#FF9999"; 
    } else if (mouseBatteryLevel <= 50) { 
      mouseBatteryColor = "#FFDAB9"; 
    } else if (mouseBatteryLevel <= 75) { 
      mouseBatteryColor = "#E5E5BF"; 
    } else { 
      mouseBatteryColor = "#BADCBD"; 
    } 
  }

  onBatteryLevelChanged: updateBatteryVisuals()
  onIsChargingChanged: updateBatteryVisuals()
  function updateBatteryVisuals() {
    if (!haveBattery) { return }
    if (isCharging) {
      if (batteryLevel <= 0) { batteryGlyph = "󰢟"; batteryColor = "#BADCBD"; }
      else if (batteryLevel <= 25) { batteryGlyph = "󰂆"; batteryColor = "#BADCBD"; }
      else if (batteryLevel <= 50) { batteryGlyph = "󰢝"; batteryColor = "#BADCBD"; }
      else if (batteryLevel <= 75) { batteryGlyph = "󰢞"; batteryColor = "#BADCBD"; }
      else { batteryGlyph = "󰂅"; batteryColor = "#BADCBD"; } 
    } else {
      if (batteryLevel <= 0) { batteryGlyph = ""; batteryColor = "#F32013"; }
      else if (batteryLevel <= 25) { batteryGlyph = ""; batteryColor = "#FF9999"; }
      else if (batteryLevel <= 50) { batteryGlyph = ""; batteryColor = "#FFDAB9"; }
      else if (batteryLevel <= 75) { batteryGlyph = ""; batteryColor = "#E5E5BF"; }
      else { batteryGlyph = ""; batteryColor = "#BADCBD"; } 
    }
  }

  Layout.alignment: Qt.AlignHCenter
  spacing: 0

  Component.onCompleted: {
    root.updateBatteryVisuals()
    root.updateMouseBatteryVisuals()
  }

  ColumnLayout {
    id: dateIndicator
    Layout.alignment: Qt.AlignHCenter
    spacing: 0
    HoverHandler { id: dateHover }
    CalendarToolTip {
      anchorItem: dateIndicator
      hovered: dateHover.hovered
      date: root.calendarDate
    }
  Text {
    Layout.alignment: Qt.AlignHCenter
    horizontalAlignment: Text.AlignHCenter
    Layout.leftMargin: 2
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.3
    font.bold: true
    color: "#89b4fa"
    text: root.dayName
  }
  Text {
    Layout.alignment: Qt.AlignHCenter
    horizontalAlignment: Text.AlignHCenter
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.33
    font.bold: true
    color: "#cdd6f4"
    text: root.dayNumber
  }
  }

  Item { implicitHeight: root.spacerHeight }

  Text {
    Layout.alignment: Qt.AlignHCenter
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.33
    font.bold: true
    color: "#cba6f7"
    text: root.hours
  }
  Text {
    Layout.alignment: Qt.AlignHCenter
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.33
    font.bold: true
    color: "#cdd6f4"
    text: root.minutes
  }

  Item { implicitHeight: root.spacerHeight }

  Text {
    visible: root.haveMouseBattery
    Layout.alignment: Qt.AlignHCenter
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.33
    text: "󰍽"
    color: root.mouseBatteryColor
  }
  Text {
    visible: root.haveMouseBattery
    Layout.alignment: Qt.AlignHCenter
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.33
    text: root.mouseBatteryLevel
    color: root.mouseBatteryColor
  }

  Item {
    id: batteryIndicator
    visible: root.haveBattery
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: batterySymbol.implicitWidth // BATTERY INDICATOR WIDTH
    implicitHeight: batterySymbol.implicitHeight
    Text {
      id: batterySymbol
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: root.compWidth*.33
      text: root.batteryGlyph
      color: root.batteryColor
    }
    // BEGIN BATTERY INDICATOR LEAF
    Rectangle {
      id: leaf
      anchors.right: batterySymbol.right
      anchors.rightMargin: -5
      anchors.top: batterySymbol.top
      anchors.topMargin: -3
      width: Math.max(13, root.compWidth * .24)
      height: width
      radius: width / 2
      color: "#1e1e2e"
      border.width: 1
      border.color: "#39463d"
      opacity: root.powerSaving ? 1 : 0
      visible: opacity > 0
      scale: root.powerSaving ? 1 : .8
      Behavior on opacity { NumberAnimation { duration: 150 } }
      Behavior on scale { NumberAnimation { duration: 150 } }
      MaterialSymbol {
        anchors.centerIn: parent
        text: "eco"
        iconSize: leaf.width * .75
        fill: 1
        color: "#a6e3a1"
      }
    }
    property bool tooltipReady: false
    HoverHandler {
      id: batteryHover
      onHoveredChanged: {
        if (hovered) tooltipDelay.restart()
        else {
          tooltipDelay.stop()
          batteryIndicator.tooltipReady = false
        }
      }
    }
    Timer {
      id: tooltipDelay
      interval: 300
      onTriggered: batteryIndicator.tooltipReady = true
    }
    PopupWindow {
      anchor.item: batteryIndicator
      anchor.rect.x: batteryIndicator.width + 12
      anchor.rect.y: (batteryIndicator.height - implicitHeight) / 2
      visible: root.powerSaving && batteryIndicator.tooltipReady && batteryHover.hovered
      implicitWidth: 174
      implicitHeight: 58
      color: "transparent"
      mask: Region {}

      ToolTipSurface {
        anchors.fill: parent

        RowLayout {
          anchors.fill: parent
          anchors.margins: 11
          spacing: 10
          Rectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: "#29372e"
            MaterialSymbol {
              anchors.centerIn: parent
              text: "eco"
              iconSize: 21
              fill: 1
              color: "#a6e3a1"
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
              text: "Power saving"
              color: "#cdd6f4"
              font.pixelSize: 13
              font.bold: true
            }
            Text {
              text: "Enabled"
              color: "#a6e3a1"
              font.pixelSize: 11
            }
          }
        }
      }
    }
    // END BATTERY INDICATOR LEAF
  }
  Text {
    visible: root.haveBattery
    Layout.alignment: Qt.AlignHCenter
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.33
    text: root.batteryLevel
    color: root.batteryColor
  }
}
