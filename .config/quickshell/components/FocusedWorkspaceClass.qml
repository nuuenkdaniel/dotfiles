pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland

Item {
  id: root

  property int compWidth: 0
  Layout.alignment: Qt.AlignHCenter
  implicitWidth: compWidth
  implicitHeight: activeAppText.width

  Text {
    id: activeAppText
    anchors.centerIn: parent
    rotation: -90
    property var activeWin: ToplevelManager.activeToplevel
    property string appClass: activeWin ? (activeWin.appId || activeWin.title || "Desktop") : "Desktop"
    text: appClass.charAt(0).toUpperCase() + appClass.slice(1)
    color: "#bac2de"
    font.family: "mononoki Nerd Font"
    font.pixelSize: root.compWidth*.625
    font.bold: true
    font.letterSpacing: root.compWidth*.046875

    width: Math.min(implicitWidth, 250) 
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
  }
}

