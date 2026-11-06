pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "../globals/ShellUtils.js" as Utils
import "../globals/Theme.js" as Theme

Item {
  id: root
  required property Notification notification
  property int defaultTimeout: 10000
  property bool entered: false
  property bool closing: false
  property bool expired: false
  readonly property bool critical: notification.urgency === NotificationUrgency.Critical
  readonly property int timeout: critical || notification.expireTimeout === 0 ? 0
    : notification.expireTimeout > 0 ? notification.expireTimeout : defaultTimeout
  implicitHeight: card.implicitHeight

  function isNavigationAction(action) {
    return ["default", "open", "show", "view"].includes(action.identifier.toLowerCase())
      || /^(show|open|view)(\s|$)/i.test(action.text.trim())
  }

  readonly property var clickAction: {
    const actions = root.notification.actions
    for (const action of actions) {
      if (action.identifier === "default") return action
    }
    for (const action of actions) {
      if (root.isNavigationAction(action)) return action
    }
    return null
  }
  readonly property var secondaryActions: root.notification.actions.filter(action => !root.isNavigationAction(action))

  function close(asExpired) {
    if (closing) return;
    expired = asExpired;
    closing = true;
    finishClose.start();
  }

  function restartTimeout() {
    expiry.restart();
  }

  Component.onCompleted: entered = true
  onTimeoutChanged: restartTimeout()
  Connections {
    target: root.notification
    function onSummaryChanged() { root.restartTimeout(); }
    function onBodyChanged() { root.restartTimeout(); }
  }

  NotificationExpiry {
    id: expiry
    duration: root.timeout
    paused: hover.hovered
    active: !root.closing
    onExpired: root.close(true)
  }
  Timer {
    id: finishClose
    interval: 250
    onTriggered: {
      if (root.expired) root.notification.expire();
      else root.notification.dismiss();
    }
  }

  Rectangle {
    id: card
    width: parent.width
    implicitHeight: content.implicitHeight + 32
    x: root.entered && !root.closing ? 0 : width + 20
    opacity: root.entered && !root.closing ? 1 : 0
    radius: 15
    color: Theme.background
    border.width: 1
    border.color: root.critical ? Theme.danger : Theme.border
    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    HoverHandler { id: hover }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: root.clickAction ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: !root.closing
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton || !root.clickAction) root.close(false)
        else root.clickAction.invoke()
      }
    }

    RowLayout {
      id: content
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
      spacing: 12

      Rectangle {
        Layout.alignment: Qt.AlignTop
        implicitWidth: 42
        implicitHeight: 42
        radius: 12
        color: "#313244"

        Image {
          id: icon
          anchors.fill: parent
          anchors.margins: 5
          source: {
            const appIcon = root.notification.appIcon;
            if (appIcon) return Utils.notificationIcon(appIcon, name => Quickshell.iconPath(name, true));
            const entry = DesktopEntries.byId(root.notification.desktopEntry);
            return entry?.icon ? Quickshell.iconPath(entry.icon, true) : "";
          }
          fillMode: Image.PreserveAspectFit
          sourceSize.width: 40
          sourceSize.height: 40
        }
        Text {
          anchors.centerIn: parent
          visible: icon.status !== Image.Ready
          text: "󰂚"
          font.family: "mononoki Nerd Font"
          color: "#cba6f7"
          font.pixelSize: 24
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

          Text {
            Layout.fillWidth: true
            text: {
              const name = root.notification.appName || ""
              return name.toLowerCase() === "notify-send" ? "" : name
            }
            visible: text.length > 0
            textFormat: Text.PlainText
            color: "#cba6f7"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
          }
        Text {
          Layout.fillWidth: true
          visible: text.length > 0
          text: root.notification.summary
          textFormat: Text.PlainText
          color: "#cdd6f4"
          font.pixelSize: 14
          font.bold: true
          wrapMode: Text.Wrap
        }
        Text {
          Layout.fillWidth: true
          visible: text.length > 0
          text: root.notification.body
          textFormat: Text.PlainText
          color: "#bac2de"
          font.pixelSize: 13
          wrapMode: Text.Wrap
        }
        Flow {
          id: actionFlow
          Layout.fillWidth: true
          visible: root.secondaryActions.length > 0
          spacing: 6
          Repeater {
            model: root.secondaryActions
            delegate: Rectangle {
              id: actionButton
              required property var modelData
              width: Math.min(actionLabel.implicitWidth + 24, actionFlow.width)
              height: 30
              radius: 9
              color: actionMouse.containsMouse ? "#58506d" : "#313244"
              activeFocusOnTab: true
              Accessible.role: Accessible.Button
              Accessible.name: modelData.text || "Open"
              Keys.onReturnPressed: modelData.invoke()
              Keys.onSpacePressed: modelData.invoke()
              Text {
                id: actionLabel
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 16)
                text: actionButton.modelData.text || "Open"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: "#cba6f7"
                font.pixelSize: 12
              }
              MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: actionButton.modelData.invoke()
              }
            }
          }
        }
      }
    }
  }
}
