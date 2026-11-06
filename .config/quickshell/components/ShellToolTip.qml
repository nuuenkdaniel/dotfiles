pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import "../globals/Theme.js" as Theme

Basic.ToolTip {
    id: root
    width: Math.min(320, implicitWidth)
    padding: 10
    horizontalPadding: 12
    margins: 8
    delay: 400
    timeout: -1
    font.pixelSize: 12
    background: ToolTipSurface {}
    contentItem: Text {
        text: root.text
        font: root.font
        color: Theme.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 } }
}
