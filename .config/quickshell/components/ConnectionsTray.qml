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
    let networks = activeAdapter.networks.values;
    for (let i = 0; i < networks.length; i++) {
      if (networks[i].connected) { return networks[i]; }
    }
    return null;
  }
  property int wifiSignalPercentage: currentWifi ? currentWifi.signalStrength*100 : 0
  property string networkGlyph: isEthernet? "󰈀" : "󰤯" 

  property bool isPowered: Bluetooth.defaultAdapter.state === BluetoothAdapterState.Enabled
  property bool isConnected: isPowered && Bluetooth.defaultAdapter.devices.length !== undefined
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

  onIsPoweredChanged: updateBTVisuals()
  onIsConnectedChanged: updateBTVisuals()
  function updateBTVisuals() {
    if (isConnected) { blueToothGlyph = ""; }
    else if (isPowered) { blueToothGlyph = "󰂯"; }
    else { blueToothGlyph = "󰂲"; }
  }

  onActiveAudioSinkChanged: {
    updateAudioVisuals()
    if (GlobalMenuState.isVisible) {
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
          update: {
            text: menuText
          }
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
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: root.fontSize
      text: root.networkGlyph
      color: "#f5e0dc"
    }
    Text {
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: root.fontSize
      text: root.blueToothGlyph
      color: "#f5e0dc"
    }
    DynamicAudioIcon {
      id: audioIcon
      fontSize: root.fontSize
      MouseArea {
        id: trayMouse
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
            });
          }
          else {
            GlobalMenuState.targetY = pos.y;
            GlobalMenuState.persist = true;
            GlobalMenuState.menuModel = root.audioSinksMenu();
          }
        }
      }
    }
  }
}
