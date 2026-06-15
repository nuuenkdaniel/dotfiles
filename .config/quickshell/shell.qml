//@ pragma UseQApplication
import QtQuick
import Quickshell

import qs.widgets
import qs.services
import qs.modules.osd

Scope {
  id: root

  StatusBar {}
  VolumeOSD {}
  PlayerControls {}
  // Test {}
}
