pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland

Item {
  id: root

  property int compWidth: 0
  Layout.alignment: Qt.AlignHCenter
  implicitWidth: compWidth

  implicitHeight: Math.max(oldTextNode.width, newTextNode.width)

  property var activeWin: ToplevelManager.activeToplevel
  property string appClassRaw: activeWin ? (activeWin.appId || activeWin.title || "Desktop") : "Desktop"
  property string formattedText: appClassRaw.charAt(0).toUpperCase() + appClassRaw.slice(1)

  property string currentText: "Desktop"
  property string nextText: ""

  Timer {
    id: titleDebounce
    interval: 50
    onTriggered: {
      if (root.formattedText !== root.currentText) {
        
        if (swapAnimation.running) {
          swapAnimation.complete(); 
        }

        root.nextText = root.formattedText;
        swapAnimation.restart();
      }
    }
  }

  onFormattedTextChanged: titleDebounce.restart()

  component AppText: Text {
    rotation: -90
    color: "#bac2de"
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth * 0.625
    font.bold: true
    font.letterSpacing: root.compWidth * 0.046875
    width: Math.min(implicitWidth, 250)
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
    anchors.centerIn: parent
  }

  AppText {
    id: oldTextNode
    text: root.currentText
  }

  AppText {
    id: newTextNode
    text: root.nextText
    opacity: 0
  }

  ParallelAnimation {
    id: swapAnimation

    NumberAnimation { target: oldTextNode; property: "anchors.verticalCenterOffset"; to: 50; duration: 200; easing.type: Easing.InQuad }
    NumberAnimation { target: oldTextNode; property: "opacity"; to: 0; duration: 200 }

    NumberAnimation { target: newTextNode; property: "anchors.verticalCenterOffset"; from: -50; to: 0; duration: 200; easing.type: Easing.OutQuad }
    NumberAnimation { target: newTextNode; property: "opacity"; from: 0; to: 1; duration: 200 }

    onFinished: {
      root.currentText = root.nextText;
      oldTextNode.anchors.verticalCenterOffset = 0;
      oldTextNode.opacity = 1;
      newTextNode.opacity = 0;
    }
  }
}
