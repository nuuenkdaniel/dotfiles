pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Bluetooth

ColumnLayout {
  id: root
  property bool active: false
  property bool bluetooth: false
  property var passwordNetwork: null
  property var attemptedNetwork: null
  onPasswordNetworkChanged: if (!passwordNetwork && password) password.text = ""
  property string errorMessage: ""
  property bool showUnnamedDevices: false
  property var nearbyOrder: []
  property var expandedNetwork: null
  readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
  readonly property var networks: {
    let result = []
    for (const device of wifiDevices) result = result.concat(device.networks.values)
    return result.sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength)
  }
  onNetworksChanged: {
    if (expandedNetwork && !networks.includes(expandedNetwork)) expandedNetwork = null
    clearUnavailableWifi()
  }
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: (adapter?.devices.values ?? []).slice().sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired))
  readonly property var savedDevices: devices.filter(d => d.paired || d.connected)
  readonly property var nearbyDevices: {
    const available = devices.filter(d => !d.paired && !d.connected && (showUnnamedDevices || hasDeviceName(d)))
    return nearbyOrder.map(address => available.find(d => d.address === address)).filter(d => !!d)
  }
  readonly property int unnamedCount: devices.filter(d => !d.paired && !d.connected && !hasDeviceName(d)).length

  function hasDeviceName(device) {
    // BlueZ aliases can be the address with dashes instead of colons.
    const addressPattern = /^(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i
    return [device.name, device.deviceName].some(name => !!name && !!name.trim() && !addressPattern.test(name.trim()))
  }

  function deviceLabel(device) {
    const addressPattern = /^(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i
    for (const name of [device.name, device.deviceName]) {
      if (name && name.trim() && !addressPattern.test(name.trim())) return name
    }
    return device.address || device.name || "Unnamed device"
  }

  function refreshNearby() {
    // Append discoveries instead of reshuffling rows on every BlueZ update.
    const next = nearbyOrder.filter(address => devices.some(device => device.address === address))
    for (const device of devices) {
      if (!next.includes(device.address)) next.push(device.address)
    }
    if (next.length !== nearbyOrder.length || next.some((address, index) => address !== nearbyOrder[index])) nearbyOrder = next
  }

  onDevicesChanged: refreshNearby()
  StableObjectModel {
    id: stableRows
    values: root.bluetooth ? (root.adapter?.enabled ? root.savedDevices.concat(root.nearbyDevices) : []) : (Networking.wifiEnabled ? root.networks : [])
  }
  spacing: 12
  onActiveChanged: {
    if (active && bluetooth) refreshNearby()
    if (!active) { cancelPassword(); attemptedNetwork = null; errorMessage = ""; expandedNetwork = null }
  }
  onBluetoothChanged: {
    if (active && bluetooth) refreshNearby()
    cancelPassword(); attemptedNetwork = null; errorMessage = ""
    expandedNetwork = null
  }

  Connections {
    target: Networking
    function onWifiEnabledChanged() { root.clearUnavailableWifi() }
    function onWifiHardwareEnabledChanged() { root.clearUnavailableWifi() }
  }

  function isPasswordNetwork(network) {
    return !!network && [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security)
  }
  function wifiAvailable(network) {
    return !!network && networks.includes(network) && Networking.wifiEnabled && Networking.wifiHardwareEnabled
  }
  function cancelPassword() {
    passwordNetwork = null
    password.text = ""
  }
  function clearUnavailableWifi() {
    const network = passwordNetwork || attemptedNetwork
    if (!network || wifiAvailable(network)) return
    cancelPassword()
    attemptedNetwork = null
    errorMessage = "The network is no longer available or Wi-Fi is off. Select an available network to try again."
  }
  function focusWifiPassword() {
    if (active && !bluetooth && passwordNetwork) password.forceActiveFocus()
  }
  function requestWifiConnection(network) {
    if (!active || bluetooth) return
    cancelPassword()
    attemptedNetwork = null
    errorMessage = ""
    if (!wifiAvailable(network)) {
      errorMessage = "The network is no longer available or Wi-Fi is off. Select an available network to try again."
      return
    }
    if (network.connected || network.stateChanging) return
    attemptedNetwork = network
    if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) network.connect()
    else if (isPasswordNetwork(network)) {
      passwordNetwork = network
      Qt.callLater(root.focusWifiPassword)
    } else {
      attemptedNetwork = null
      errorMessage = "This network requires enterprise or special authentication, such as a username or certificates. Configure it in your system network settings first."
    }
  }
  function wifiConnectionFailed(network, reason) {
    if (!active || bluetooth || network !== attemptedNetwork) return
    if (!wifiAvailable(network)) { clearUnavailableWifi(); return }
    errorMessage = reason === ConnectionFailReason.NoSecrets
      ? "The password was missing or incorrect. Enter it and try again."
      : "Connection failed: " + ConnectionFailReason.toString(reason)
    if (isPasswordNetwork(network) && [ConnectionFailReason.NoSecrets, ConnectionFailReason.WifiAuthTimeout].includes(reason)) {
      cancelPassword()
      passwordNetwork = network
      Qt.callLater(root.focusWifiPassword)
    }
  }
  function wifiConnected(network) {
    if (network !== attemptedNetwork || !network.connected) return
    cancelPassword()
    attemptedNetwork = null
    errorMessage = ""
  }

  Repeater {
    model: root.wifiDevices
    delegate: Item {
      required property var modelData
      visible: false
      Binding {
        target: modelData
        property: "scannerEnabled"
        value: true
        when: root.active && !root.bluetooth && Networking.wifiEnabled
        restoreMode: Binding.RestoreBindingOrValue
      }
    }
  }
  Binding {
    target: root.adapter
    property: "discovering"
    value: true
    when: root.active && root.bluetooth && !!root.adapter?.enabled
    restoreMode: Binding.RestoreBindingOrValue
  }

  Text {
    text: root.bluetooth ? "Bluetooth" : "Wi-Fi"
    color: "#cdd6f4"
    font.pixelSize: 24
    font.bold: true
  }
  RowLayout {
    Layout.fillWidth: true
    Text {
      Layout.fillWidth: true
      text: root.bluetooth ? root.adapter ? "Discover and connect your devices." : "No Bluetooth adapter found."
        : root.wifiDevices.length ? "Choose a wireless network." : "No Wi-Fi adapter found."
      color: "#bac2de"
      font.pixelSize: 13
      wrapMode: Text.Wrap
    }
    Switch {
      id: powerToggle
      checked: root.bluetooth ? !!root.adapter?.enabled : Networking.wifiEnabled
      enabled: root.bluetooth ? !!root.adapter : root.wifiDevices.length > 0 && Networking.wifiHardwareEnabled
      Accessible.name: root.bluetooth ? "Bluetooth power" : "Wi-Fi power"
      onToggled: {
        if (root.bluetooth) root.adapter.enabled = checked
        else Networking.wifiEnabled = checked
      }
      indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 22
        x: powerToggle.leftPadding
        y: (powerToggle.height - height) / 2
        radius: 11
        opacity: powerToggle.enabled ? 1 : .4
        color: powerToggle.checked ? "#cba6f7" : "#45475a"
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
          x: powerToggle.checked ? parent.width - width - 3 : 3
          y: 3
          width: 16
          height: 16
          radius: 8
          color: powerToggle.checked ? "#1e1e2e" : "#cdd6f4"
          Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
      }
    }
  }
  Text {
    Layout.fillWidth: true
    visible: text.length > 0
    text: root.errorMessage
    color: "#f38ba8"
    wrapMode: Text.Wrap
    font.pixelSize: 12
  }

  ActionButton {
    visible: root.bluetooth && !!root.adapter?.enabled
    text: root.showUnnamedDevices ? "Hide unnamed devices" : "Show unnamed devices (" + root.unnamedCount + ")"
    onClicked: root.showUnnamedDevices = !root.showUnnamedDevices
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: !!root.passwordNetwork && !root.bluetooth
    spacing: 6
    Text {
      Layout.fillWidth: true
      text: "Password for " + (root.passwordNetwork?.name ?? "")
      textFormat: Text.PlainText
      color: "#cba6f7"
      font.pixelSize: 13
      elide: Text.ElideRight
    }
    RowLayout {
      Layout.fillWidth: true
      TextField {
        id: password
        Layout.fillWidth: true
        echoMode: TextInput.Password
        color: "#cdd6f4"
        placeholderText: "Network password"
        placeholderTextColor: "#9399b2"
        Accessible.name: "Password for " + (root.passwordNetwork?.name || "Wi-Fi network")
        selectByMouse: true
        background: Rectangle { radius: 8; color: "#313244"; border.color: "#6b587f" }
        onAccepted: root.connectPassword()
      }
      ActionButton { text: "Connect"; enabled: password.text.length > 0 && root.wifiAvailable(root.passwordNetwork) && !root.passwordNetwork?.stateChanging; onClicked: root.connectPassword() }
      ActionButton { text: "Cancel"; onClicked: { root.cancelPassword(); root.attemptedNetwork = null; root.errorMessage = "" } }
    }
  }

  function connectPassword() {
    if (!active || bluetooth || !passwordNetwork || !password.text || passwordNetwork.stateChanging) return
    if (!wifiAvailable(passwordNetwork)) { clearUnavailableWifi(); return }
    const network = passwordNetwork
    const secret = password.text
    // Clear the input before invoking the backend, including synchronous errors.
    // Credentials are passed through the native API, never shell arguments/files.
    cancelPassword()
    attemptedNetwork = network
    errorMessage = ""
    network.connectWithPsk(secret)
  }

  Flickable {
    id: scroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    contentHeight: list.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    ColumnLayout {
      id: list
      width: scroll.width - (scroll.contentHeight > scroll.height ? 12 : 0)
      spacing: 5
      Text {
        Layout.fillWidth: true
        text: root.bluetooth ? root.adapter?.enabled ? "Saved devices" : "Bluetooth is off"
          : Networking.wifiEnabled ? "Available networks" : "Wi-Fi is off"
        color: "#cba6f7"
        font.pixelSize: 14
        font.bold: true
      }
      Text {
        visible: root.bluetooth && !!root.adapter?.enabled && root.savedDevices.length === 0
        text: "No saved devices yet."
        color: "#bac2de"
        font.pixelSize: 12
      }
      Repeater {
        model: stableRows.model
        delegate: Rectangle {
          id: entry
          required property var entryObject
          readonly property var modelData: entryObject
          required property int index
          readonly property bool startsNearby: root.bluetooth && index === root.savedDevices.length
          readonly property bool detailsExpanded: !root.bluetooth && root.expandedNetwork === modelData
          Layout.fillWidth: true
          implicitHeight: 62 + (startsNearby ? 34 : 0) + (detailsExpanded ? detailsLoader.implicitHeight + 16 : 0)
          activeFocusOnTab: !root.bluetooth
          Accessible.role: root.bluetooth ? Accessible.ListItem : Accessible.Button
          Accessible.name: root.bluetooth ? root.deviceLabel(modelData) : (detailsExpanded ? "Hide details for " : "Show details for ") + (modelData.name || "Hidden network")
          Keys.onReturnPressed: if (!root.bluetooth) root.expandedNetwork = detailsExpanded ? null : modelData
          Keys.onSpacePressed: if (!root.bluetooth) root.expandedNetwork = detailsExpanded ? null : modelData
          radius: 8
          color: "transparent"
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: entry.startsNearby ? 34 : 0
            height: entry.height - y
            radius: 8
            color: entryHover.hovered || entry.activeFocus ? "#3b3549" : entry.modelData.connected || entry.detailsExpanded ? "#292534" : "transparent"
            HoverHandler { id: entryHover }
          }
          // Below the header controls, so Connect/Disconnect never toggles details.
          MouseArea {
            x: 0; y: entry.startsNearby ? 34 : 0
            width: parent.width; height: 62
            enabled: !root.bluetooth
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandedNetwork = entry.detailsExpanded ? null : entry.modelData
          }
          Text {
            visible: entry.startsNearby
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 10
            text: "Nearby devices"
            color: "#cba6f7"
            font.pixelSize: 14
            font.bold: true
          }
          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: entry.startsNearby ? 42 : 8
            height: 46
            spacing: 10
            Text {
              text: {
                if (root.bluetooth) return "󰂯"
                const strength = entry.modelData.signalStrength
                if (strength <= .25) return "󰤟"
                if (strength <= .5) return "󰤢"
                if (strength <= .75) return "󰤥"
                return "󰤨"
              }
              font.family: "mononoki Nerd Font"
              font.pixelSize: 22
              color: "#cba6f7"
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3
              Text {
                Layout.fillWidth: true
                text: root.bluetooth ? root.deviceLabel(entry.modelData) : entry.modelData.name || "Hidden network"
                textFormat: Text.PlainText
                color: "#cdd6f4"
                font.pixelSize: 13
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                text: root.bluetooth
                  ? (entry.modelData.pairing ? "Pairing…" : entry.modelData.connected ? "Connected" : entry.modelData.paired ? "Paired" : "Not paired")
                    + (entry.modelData.batteryAvailable ? " · " + Math.round(entry.modelData.battery * 100) + "% battery" : "")
                  : entry.modelData.stateChanging ? "Connecting…" : entry.modelData.connected ? "Connected" : Math.round(entry.modelData.signalStrength * 100) + "% signal"
                color: "#bac2de"
                font.pixelSize: 11
              }
            }
            MaterialSymbol {
              visible: !root.bluetooth
              text: entry.detailsExpanded ? "expand_less" : "expand_more"
              iconSize: 18
              color: "#9399b2"
            }
            MaterialSymbol {
              visible: root.bluetooth && !!entry.modelData.batteryAvailable
              text: root.bluetooth && entry.modelData.batteryAvailable && entry.modelData.battery <= .2 ? "battery_alert" : "battery_full"
              iconSize: 17
              color: root.bluetooth && entry.modelData.batteryAvailable && entry.modelData.battery <= .2 ? "#f38ba8" : "#a6e3a1"
            }
            ActionButton {
              text: entry.modelData.connected ? "Disconnect" : root.bluetooth && !entry.modelData.paired ? "Pair" : "Connect"
              enabled: root.bluetooth ? !entry.modelData.pairing : !entry.modelData.stateChanging
              onClicked: {
                root.errorMessage = ""
                const device = entry.modelData
                if (device.connected) device.disconnect()
                else if (root.bluetooth) {
                  if (device.paired) device.connect()
                  else device.pair()
                } else root.requestWifiConnection(device)
              }
            }
          }
          Loader {
            id: detailsLoader
            x: 12
            y: 64 + (entry.startsNearby ? 34 : 0)
            width: entry.width - 24
            active: entry.detailsExpanded
            sourceComponent: WifiDetails {
              active: root.active && !root.bluetooth && entry.detailsExpanded
              network: entry.modelData
            }
          }
          Connections {
            target: root.bluetooth ? null : entry.modelData
            function onConnectionFailed(reason) { root.wifiConnectionFailed(entry.modelData, reason) }
            function onConnectedChanged() { root.wifiConnected(entry.modelData) }
          }
        }
      }
      Text {
        visible: root.bluetooth && !!root.adapter?.enabled && root.nearbyDevices.length === 0
        text: "Nearby devices"
        color: "#cba6f7"
        font.pixelSize: 14
        font.bold: true
        Layout.topMargin: 10
      }
      Text {
        Layout.fillWidth: true
        visible: root.bluetooth ? !!root.adapter?.enabled && root.nearbyDevices.length === 0 : Networking.wifiEnabled && root.networks.length === 0
        text: root.bluetooth ? "No matching nearby devices. Put your device in pairing mode."
          : "Searching… Make sure the device or network is available."
        color: "#bac2de"
        font.pixelSize: 13
        wrapMode: Text.Wrap
      }
    }
  }

  component ActionButton: SettingsButton {
    implicitHeight: 30
  }
}
