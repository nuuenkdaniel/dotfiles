pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking

PanelWindow {
  visible: true
  implicitWidth: 0
  implicitHeight: 0

  property var allDevices: Networking.devices.values
  property var wifiDev: {
    for (let i = 0; i < allDevices.length; i++) {
      let dev = allDevices[i];
      if (dev.type === DeviceType.Wifi) {
        // console.log(dev.scannerEnabled);
        // console.log(dev.networks.values);
        // console.log(dev.scannerEnabled);
        return dev
      }
    }
  }

  property var rando: {
    let networks = wifiDev.networks.values
    for (let i = 0; i < networks.length; i++) {
      // console.log(networks[i].connected)
    }
  }

  Timer {
    running: true
    interval: 2000
    repeat: true
    onTriggered: {
      for (let i = 0; i < allDevices.length; i++) {
        let dev = allDevices[i];
        if (dev.type === DeviceType.Wifi) {
          // console.log(dev.scannerEnabled);
        }
      }
    }
  }

}
