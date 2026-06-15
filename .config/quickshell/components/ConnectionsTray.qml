pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire

Rectangle {
  id: root
  Layout.alignment: Qt.AlignHCenter
  implicitHeight: infoLayout.implicitHeight + 20
  radius: 20
  color: "#44475A"

  property var activeAdapter: {
    let allDevices = Networking.devices.values;
    for (let i = 0; i < allDevices.length; i++) {
      if (allDevices[i].connected) {
        return allDevices[i];
      }
    }
    return null;
  }
  property bool isWifi: activeAdapter !== null && activeAdapter.type === DeviceType.Wifi
  property bool isEthernet: activeAdapter !== null && activeAdapter.type === DeviceType.Wired
  property var currentWifi: isWifi ? activeAdapter.activeNetwork : null
  property int wifiSignalPercentage: currentWifi ? currentWifi.signalStrength : 0
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

  onWifiSignalPercentageChanged: updateNetworkVisuals()
  onActiveAdapterChanged: updateNetworkVisuals()
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

  onActiveAudioSinkChanged: updateAudioVisuals()
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

  ColumnLayout {
    id: infoLayout
    anchors.centerIn: parent
    spacing: 8
    Text {
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: 20
      text: root.networkGlyph
      color: "#f5e0dc"
    }
    Text {
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: 20
      text: root.blueToothGlyph
      color: "#f5e0dc"
    }
    Text {
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: 20
      text: root.audioGlyph
      color: "#f5e0dc"
    }
  }
}
