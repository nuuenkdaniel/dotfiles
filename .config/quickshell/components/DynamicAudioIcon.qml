pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Text {
  property int fontSize: 0
  property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
  property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
  property bool headphone: false
  property var activeAudioSink: Pipewire.defaultAudioSink
  property string sinkName: activeAudioSink?.name ?? ""
  property bool isHeadphone: sinkName.indexOf("Logitech_PRO_X") !== -1
  property string audioGlyph: ""

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

  Layout.alignment: Qt.AlignHCenter
  font.family: "mononoki Nerd Font"
  font.pixelSize: fontSize
  text: audioGlyph
  color: "#f5e0dc"
}
