pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../globals"

Rectangle {
  id: root

  property int compWidth: 0
  readonly property int fontSize: compWidth/2

  Layout.alignment: Qt.AlignHCenter
  implicitWidth: compWidth
  implicitHeight: infoLayout.implicitHeight + 20
  radius: 20
  color: "#44475A"

  property var allDevices: Networking.devices.values
  property var activeAdapter: {
    let finalDevice = null;
    for (let i = 0; i < allDevices.length; i++) {
      const currDevice = allDevices[i]
      if (currDevice.connected) {
        if (currDevice.type === DeviceType.Wired) { return currDevice; }
        else if (currDevice.type === DeviceType.Wifi) { finalDevice = currDevice; }
      }
    }
    if (finalDevice && finalDevice.type === DeviceType.Wifi) { return finalDevice; }
    return null;
  }
  property bool isEthernet: activeAdapter ? activeAdapter.type === DeviceType.Wired : false
  property bool isWifi: activeAdapter ? activeAdapter.type === DeviceType.Wifi : false
  property var currentWifi: {
    if (!activeAdapter) { return null; }
    let networks = activeAdapter.networks.values;
    for (let i = 0; i < networks.length; i++) {
      if (networks[i].connected) { return networks[i]; }
    }
    return null;
  }
  property int wifiSignalPercentage: currentWifi ? currentWifi.signalStrength*100 : 0
  property string networkGlyph: isEthernet? "󰈀" : "󰤯" 

  property bool isPowered: Bluetooth.defaultAdapter.state === BluetoothAdapterState.Enabled
  property var btDevs: isPowered ? Bluetooth.defaultAdapter.devices.values : null
  property bool isConnected: {
    if (btDevs) {
      for (let i = 0; i < btDevs.length; i++) {
        if (btDevs[i].connected) { return true; }
      }
    }
    return false
  }
  property string blueToothGlyph: "󰂲"

  property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
  property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
  property bool headphone: false
  property var activeAudioSink: Pipewire.defaultAudioSink
  property string sinkName: activeAudioSink?.name ?? ""
  property bool isHeadphone: sinkName.indexOf("Logitech_PRO_X") !== -1
  property string audioGlyph: ""
  property var pwNodes: Pipewire.nodes

  onWifiSignalPercentageChanged: updateNetworkVisuals()
  onActiveAdapterChanged: updateNetworkVisuals()
  onIsWifiChanged: updateNetworkVisuals()
  onCurrentWifiChanged: updateNetworkVisuals()
  onIsEthernetChanged: updateNetworkVisuals()
  function updateNetworkVisuals() {
    if (!activeAdapter) {
      networkGlyph = "󰤯";
      return;
    }
    if (isEthernet) {
      networkGlyph = "󰈀";
      return;
    }
    if (isWifi) {
      if (wifiSignalPercentage <= 25) { networkGlyph = "󰤟"; }
      else if (wifiSignalPercentage <= 50) { networkGlyph = "󰤢"; }
      else if (wifiSignalPercentage <= 75) { networkGlyph = "󰤥"; }
      else { networkGlyph = "󰤨"; }
    }
  }

  Timer {
    running: (GlobalMenuState.isVisible && GlobalMenuState.menuType === 1)
    interval: 1500
    repeat: true
    onTriggered: {
      let newMenu = root.connectionMenu()
      if (root.isMenuChanged(GlobalMenuState.menuModel, newMenu)) {
        GlobalMenuState.menuModel = root.connectionMenu()
      }
    }
  }

  function isMenuChanged(oldMenu, newMenu) {
    if (!oldMenu || !newMenu) return true;
    if (oldMenu.length !== newMenu.length) return true;
    for (let i = 0; i < oldMenu.length; i++) {
      if (oldMenu[i].text !== newMenu[i].text) {
        return true; 
      }
    }
    return false; 
  }

  function connectionMenu() {
    let networkMenu = [];

    // Handle all wired network cards first
    networkMenu.push({
      isHeader: true,
      isSeparator: false,
      text: "Wired"
    });
    for (let i = 0; i < allDevices.length; i++) {
      const dev = allDevices[i];
      if (!dev) { continue; }
      if (dev.type === DeviceType.Wired) {
        let menuText = "Wired Connection" + (i+1);
        networkMenu.push({
          isSeparator: false,
          text: menuText,
          triggered: function() { return; }
        });
      }
    }

    // Handle Wifi
    for (let i = 0; i < allDevices.length; i++) {
      const dev = allDevices[i];
      if (!dev) { continue; }
      if (dev.type === DeviceType.Wifi) {
        networkMenu.push({
          isHeader: false,
          isSeparator: true,
        });
        networkMenu.push({
          isHeader: true,
          isSeparator: false,
          text: "Wi-Fi"
        });
        let networks = dev.networks.values
        for (let j = 0; j < networks.length; j++) {
          let signalStrength = networks[j].signalStrength;
          let signalGlyph = "󰤟  ";
          let connected = networks[j].connected
          if (signalStrength <= .25) { signalGlyph = "󰤟  "; }
          else if (signalStrength <= .5) { signalGlyph = "󰤢  "; }
          else if (signalStrength <= .75) { signalGlyph = "󰤥  "; }
          else { signalGlyph = "󰤨  "; }

          let menuText = signalGlyph + networks[j].name + (networks[j].connected ? "   ✓" : "")
          networkMenu.push({
            isSeparator: false,
            text: menuText,
            triggered: function() { 
              networks[j].connect();
            }
          });
        }
      }
    }
    return networkMenu
  }

  Connections {
    target: GlobalMenuState

    function onIsVisibleChanged() {
      root.updateWifiScannerState();
    }

    function onMenuTypeChanged() {
      root.updateWifiScannerState();
    }
  }

  function updateWifiScannerState() {
    let enableScan = (GlobalMenuState.isVisible && GlobalMenuState.menuType === 1);

    for (let i = 0; i < allDevices.length; i++) {
      const dev = allDevices[i];
      if (dev && dev.type === DeviceType.Wifi) {
        dev.scannerEnabled = enableScan;
      }
    }
  }

  onIsPoweredChanged: updateBTVisuals()
  onIsConnectedChanged: updateBTVisuals()
  function updateBTVisuals() {
    if (isConnected) { blueToothGlyph = ""; }
    else if (isPowered) { blueToothGlyph = "󰂯"; }
    else { blueToothGlyph = "󰂲"; }
  }

  Timer {
    running: (GlobalMenuState.isVisible && GlobalMenuState.menuType === 2)
    interval: 1000
    repeat: true
    onTriggered: {
      let newMenu = root.bluetoothMenu()
      if (root.isMenuChanged(GlobalMenuState.menuModel, newMenu)) {
        GlobalMenuState.menuModel = root.bluetoothMenu()
      }
    }
  }

  function bluetoothMenu() {
    let btMenu = [];
    for (let i = 0; i < btDevs.length; i++) {
      const dev = btDevs[i];
      if (!dev) { continue; }
      if (dev.paired) {
        let menuText = (dev.connected ? "✓ " : "   ") + (dev.name != "" ? dev.name : dev.deviceName)
        btMenu.push({
          isSeparator: false,
          text: menuText,
          triggered: function() {
            dev.connected = !dev.connected
          }
        });
      }
    }
    return btMenu;
  }

  onActiveAudioSinkChanged: {
    updateAudioVisuals()
    if (GlobalMenuState.isVisible && GlobalMenuState.menuType === 3) {
      GlobalMenuState.menuModel = root.audioSinksMenu();
    }
  }
  onVolumeChanged: updateAudioVisuals()
  onMutedChanged: updateAudioVisuals()
  function updateAudioVisuals() {
    if (!isHeadphone) {
      if (!muted) {
        if (volume <= 0) { audioGlyph = ""; }
        else if (volume <= .5) { audioGlyph = ""; }
        else { audioGlyph = ""; } 
      }
      else { audioGlyph = ""; }
    }
    else { audioGlyph = "󰋎"; }
  }

  function audioSinksMenu() {
    let audioMenu = [];

    for (let i = 0; i < pwNodes.values.length; i++) {
      const node = pwNodes.values[i];
      if (!node) { continue; }
      if (node.isSink && !node.isStream) {
        let isActive = (Pipewire.defaultAudioSink === node);
        let menuText = (isActive ? "✓ " : "   ") + (node.description !== "" ? node.description : node.name);
        audioMenu.push({
          isSeparator: false,
          text: menuText,
          triggered: function() {
            Pipewire.preferredDefaultAudioSink = node;
          },
        });
      }
    }

    return audioMenu
  }

  ColumnLayout {
    id: infoLayout
    anchors.centerIn: parent
    spacing: root.compWidth*.133
    Text {
      id: networkIcon
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: root.fontSize
      text: root.networkGlyph
      color: "#f5e0dc"
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true 
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          let pos = networkIcon.mapToItem(null, 0, 0);
          GlobalMenuState.targetY = pos.y;
          if (!GlobalMenuState.isVisible) {
            Qt.callLater(() => {
              GlobalMenuState.menuModel = root.connectionMenu();
              GlobalMenuState.persist = true;
              GlobalMenuState.isVisible = true;
              GlobalMenuState.menuType = 1
            });
          }
          else {
            GlobalMenuState.targetY = pos.y;
            GlobalMenuState.persist = true;
            GlobalMenuState.menuModel = root.connectionMenu();
            GlobalMenuState.menuType = 1
          }
        }
      }
    }
    Text {
      id: bluetoothIcon
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: root.fontSize
      text: root.blueToothGlyph
      color: "#f5e0dc"
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true 
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          let pos = bluetoothIcon.mapToItem(null, 0, 0);
          GlobalMenuState.targetY = pos.y;
          if (!GlobalMenuState.isVisible) {
            Qt.callLater(() => {
              GlobalMenuState.menuModel = root.bluetoothMenu();
              GlobalMenuState.persist = true;
              GlobalMenuState.isVisible = true;
              GlobalMenuState.menuType = 2
            });
          }
          else {
            GlobalMenuState.targetY = pos.y;
            GlobalMenuState.persist = true;
            GlobalMenuState.menuModel = root.bluetoothMenu();
            GlobalMenuState.menuType = 2
          }
        }
      }
    }
    DynamicAudioIcon {
      id: audioIcon
      fontSize: root.fontSize
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true 
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          let pos = audioIcon.mapToItem(null, 0, 0);
          GlobalMenuState.targetY = pos.y;
          if (!GlobalMenuState.isVisible) {
            Qt.callLater(() => {
              GlobalMenuState.menuModel = root.audioSinksMenu();
              GlobalMenuState.persist = true;
              GlobalMenuState.isVisible = true;
              GlobalMenuState.menuType = 3
            });
          }
          else {
            GlobalMenuState.targetY = pos.y;
            GlobalMenuState.persist = true;
            GlobalMenuState.menuModel = root.audioSinksMenu();
            GlobalMenuState.menuType = 3
          }
        }
      }
    }
  }
}
