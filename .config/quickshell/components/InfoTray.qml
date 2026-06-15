pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

ColumnLayout {
  id: root

  property int compWidth: 0
  property int spacerHeight: compWidth*.167

  property string dayName: "MON"
  property string dayNumber: "01"

  property string hours: "00"
  property string minutes: "00"

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
  property int batteryLevel: mainBattery? Math.round(mainBattery.percentage) : 100
  property bool isCharging: !UPower.onBattery
  property string batteryGlyph: ""
  property string batteryColor: "#BADCBD"

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
    if (haveBattery) { return }
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

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      let date = new Date();
      let dayStr = date.toLocaleDateString(Qt.locale(), "ddd");
      root.dayName = dayStr.toUpperCase();
      root.dayNumber = String(date.getDate()).padStart(2, '0');
      root.hours = date.toLocaleTimeString(Qt.locale(), "hh");
      root.minutes = date.toLocaleTimeString(Qt.locale(), "mm");
    }
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

  Rectangle {
    implicitHeight: root.spacerHeight
  }

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

  Rectangle {
    implicitHeight: root.spacerHeight
  }

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

  Text {
    visible: root.haveBattery
    Layout.alignment: Qt.AlignHCenter
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.33
    text: root.batteryGlyph
    color: root.batteryColor
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
