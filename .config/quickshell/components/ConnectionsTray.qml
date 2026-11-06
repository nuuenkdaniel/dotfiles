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
  property string screenName: ""
  property int sidebarWidth: 55
  signal wifiRequested(var network)
  readonly property bool ownsMenu: !GlobalMenuState.screenName || GlobalMenuState.screenName === screenName
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
    if (!activeAdapter || activeAdapter.type !== DeviceType.Wifi) { return null; }
    let networks = activeAdapter.networks.values;
    for (let i = 0; i < networks.length; i++) {
      if (networks[i].connected) { return networks[i]; }
    }
    return null;
  }
  property int wifiSignalPercentage: currentWifi ? currentWifi.signalStrength*100 : 0
  property string networkGlyph: isEthernet? "󰈀" : "󰤯" 

  readonly property var btAdapter: Bluetooth.defaultAdapter
  property bool isPowered: btAdapter?.enabled ?? false
  property var btDevs: isPowered ? btAdapter.devices.values : []
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

  readonly property var liveNetworkMenu: root.ownsMenu && GlobalMenuState.isVisible && GlobalMenuState.menuType === 1 ? root.connectionMenu() : []
  readonly property var liveBluetoothMenu: root.ownsMenu && GlobalMenuState.isVisible && GlobalMenuState.menuType === 2 ? root.bluetoothMenu() : []
  readonly property var liveAudioMenu: root.ownsMenu && GlobalMenuState.isVisible && GlobalMenuState.menuType === 3 ? root.audioSinksMenu() : []
  onLiveNetworkMenuChanged: publishMenu(1, liveNetworkMenu)
  onLiveBluetoothMenuChanged: publishMenu(2, liveBluetoothMenu)
  onLiveAudioMenuChanged: publishMenu(3, liveAudioMenu)

  function publishMenu(type, model) {
    if (root.ownsMenu && GlobalMenuState.isVisible && GlobalMenuState.menuType === type && isMenuChanged(GlobalMenuState.menuModel, model))
      GlobalMenuState.menuModel = model
  }

  function isMenuChanged(oldMenu, newMenu) {
    if (!oldMenu || !newMenu) return true;
    if (oldMenu.length !== newMenu.length) return true;
    for (let i = 0; i < oldMenu.length; i++) {
      for (const field of ["text", "enabled", "checked", "isToggle", "identity"]) {
        if (oldMenu[i][field] !== newMenu[i][field]) return true;
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
        let menuText = (dev.name || "Wired connection") + (dev.connected ? " · Connected" : " · Disconnected");
        networkMenu.push({
          isSeparator: false,
          text: menuText,
          enabled: false
        });
      }
    }

    const wifiDevices = allDevices.filter(dev => dev && dev.type === DeviceType.Wifi);
    networkMenu.push({ isSeparator: true });
    networkMenu.push({
      text: "Wi-Fi", isToggle: true, checked: Networking.wifiEnabled,
      enabled: wifiDevices.length > 0 && Networking.wifiHardwareEnabled,
      triggered: function() {
        if (wifiDevices.length && Networking.wifiHardwareEnabled)
          Networking.wifiEnabled = !Networking.wifiEnabled;
      }
    });
    if (!wifiDevices.length || !Networking.wifiHardwareEnabled || !Networking.wifiEnabled) {
      networkMenu.push({ text: !wifiDevices.length ? "No Wi-Fi adapter" : !Networking.wifiHardwareEnabled ? "Blocked by hardware switch" : "Wi-Fi is off", enabled: false });
      return networkMenu;
    }
    // Networks appear only while the radio is on; the switch always remains accessible.
    for (const dev of wifiDevices) {
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
            identity: networks[j],
            enabled: !networks[j].stateChanging,
            triggered: function() { 
              const network = networks[j];
              if (network.connected) network.disconnect();
              else if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) network.connect();
              else root.wifiRequested(network);
            }
          });
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
  Connections {
    target: Networking
    function onWifiEnabledChanged() { root.updateWifiScannerState(); root.refreshRadioMenu(1) }
    function onWifiHardwareEnabledChanged() { root.updateWifiScannerState(); root.refreshRadioMenu(1) }
  }
  Connections {
    target: root.btAdapter
    function onEnabledChanged() { root.refreshRadioMenu(2) }
  }
  onBtAdapterChanged: refreshRadioMenu(2)

  function refreshRadioMenu(type) {
    if (!root.ownsMenu || !GlobalMenuState.isVisible || GlobalMenuState.menuType !== type) return
    GlobalMenuState.menuModel = type === 1 ? root.connectionMenu() : root.bluetoothMenu()
  }

  function updateWifiScannerState() {
    let enableScan = GlobalMenuState.isVisible && GlobalMenuState.menuType === 1 && Networking.wifiEnabled && Networking.wifiHardwareEnabled;

    for (let i = 0; i < allDevices.length; i++) {
      const dev = allDevices[i];
      if (dev && dev.type === DeviceType.Wifi) {
        dev.scannerEnabled = enableScan;
      }
    }
  }
  onAllDevicesChanged: updateWifiScannerState()

  onIsPoweredChanged: updateBTVisuals()
  onIsConnectedChanged: updateBTVisuals()
  function updateBTVisuals() {
    if (isConnected) { blueToothGlyph = ""; }
    else if (isPowered) { blueToothGlyph = "󰂯"; }
    else { blueToothGlyph = "󰂲"; }
  }

  function bluetoothMenu() {
    let btMenu = [{
      text: "Bluetooth", isToggle: true, checked: root.isPowered, enabled: !!root.btAdapter,
      triggered: function() { if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled; }
    }];
    if (!root.btAdapter || !root.isPowered) {
      btMenu.push({text: root.btAdapter ? "Bluetooth is off" : "No Bluetooth adapter", enabled: false});
      return btMenu;
    }
    btMenu.push({isSeparator: true});
    for (let i = 0; i < btDevs.length; i++) {
      const dev = btDevs[i];
      if (!dev) { continue; }
      if (dev.paired) {
        let menuText = (dev.connected ? "✓ " : "   ") + (dev.name != "" ? dev.name : dev.deviceName)
        btMenu.push({
          isSeparator: false,
          text: menuText,
          identity: dev,
          triggered: function() {
            if (dev.connected) dev.disconnect();
            else dev.connect();
          }
        });
      }
    }
    if (!btDevs.some(dev => dev && dev.paired)) btMenu.push({text: "No paired devices", enabled: false});
    return btMenu;
  }

  onActiveAudioSinkChanged: {
    updateAudioVisuals()
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
          identity: node,
          triggered: function() {
            Pipewire.preferredDefaultAudioSink = node;
          },
        });
      }
    }

    return audioMenu
  }

  function openMenu(anchor, type) {
    const position = anchor.mapToItem(null, 0, 0)
    const model = type === 1 ? connectionMenu() : type === 2 ? bluetoothMenu() : audioSinksMenu()
    GlobalMenuState.openAt(position.y, model, type, true, root.screenName, root.sidebarWidth)
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
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: "Network menu"
      Accessible.onPressAction: root.openMenu(networkIcon, 1)
      Keys.onReturnPressed: root.openMenu(networkIcon, 1)
      Keys.onSpacePressed: root.openMenu(networkIcon, 1)
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true 
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          root.openMenu(networkIcon, 1);
        }
      }
    }
    Text {
      id: bluetoothIcon
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: "Bluetooth menu"
      Accessible.onPressAction: root.openMenu(bluetoothIcon, 2)
      Keys.onReturnPressed: root.openMenu(bluetoothIcon, 2)
      Keys.onSpacePressed: root.openMenu(bluetoothIcon, 2)
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
          root.openMenu(bluetoothIcon, 2);
        }
      }
    }
    DynamicAudioIcon {
      id: audioIcon
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: "Audio output menu"
      Accessible.onPressAction: root.openMenu(audioIcon, 3)
      Keys.onReturnPressed: root.openMenu(audioIcon, 3)
      Keys.onSpacePressed: root.openMenu(audioIcon, 3)
      fontSize: root.fontSize
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true 
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          root.openMenu(audioIcon, 3);
        }
      }
    }
  }
}
