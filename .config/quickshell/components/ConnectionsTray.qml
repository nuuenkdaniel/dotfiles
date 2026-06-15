pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire

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
    for (let i = 0; i < allDevices.length; i++) {
      if (allDevices[i].connected) {
        return allDevices[i];
      }
    }
    return null;
  }
  property bool isWifi: activeAdapter? activeAdapter.type === DeviceType.Wifi : false
  property bool isEthernet: activeAdapter? activeAdapter.type === DeviceType.Wired : false
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
  onIsWifiChanged: updateNetworkVisuals()
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
    Text {
      Layout.alignment: Qt.AlignHCenter
      font.family: "mononoki Nerd Font"
      font.pixelSize: root.fontSize
      text: root.audioGlyph
      color: "#f5e0dc"
    }
  }
}
