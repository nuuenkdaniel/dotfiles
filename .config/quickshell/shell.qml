import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

import "./components"

Scope {
  id: root

  // shared reactive state for the OSD
  property bool shouldShowOsd: false

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  Connections {
    target: Pipewire.defaultAudioSink?.audio
    function onVolumeChanged() {
      root.shouldShowOsd = true
      hideTimer.restart()
    }
    function onMutedChanged() {
      root.shouldShowOsd = true
      hideTimer.restart()
    }
  }

  Timer {
    id: hideTimer
    interval: 2000
    onTriggered: root.shouldShowOsd = false
  }

  VolumeOSD {
    visibleState: root.shouldShowOsd
    volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
  }
}
