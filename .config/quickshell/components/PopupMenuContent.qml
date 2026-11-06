pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../globals/Theme.js" as Theme

FocusScope {
    id: root
    property var menuModel: []
    // QML QVariantList wrappers are array-like but not always Array.isArray().
    // Their values() iterator must not be mistaken for ObjectModel.values.
    readonly property var entries: menuModel && menuModel.values !== undefined && typeof menuModel.values !== "function"
        ? menuModel.values : menuModel ?? []
    property real maximumWidth: 320
    property real maximumHeight: 600
    property bool canGoBack: false
    property int currentIndex: -1
    property real measuredWidth: 200
    signal entryActivated(var entry)
    signal backRequested()
    signal closeRequested()
    implicitWidth: Math.min(maximumWidth, measuredWidth)
    implicitHeight: Math.min(maximumHeight, rows.implicitHeight + 20 + (canGoBack ? 36 : 0))
    onEntriesChanged: { currentIndex = -1; Qt.callLater(root.selectNext, 1); Qt.callLater(root.measureWidth) }
    Component.onCompleted: { Qt.callLater(root.selectNext, 1); Qt.callLater(root.measureWidth) }

    function measureWidth() {
        let preferred = 200
        for (let i = 0; i < items.count; ++i) {
            const row = items.itemAt(i)
            if (row) preferred = Math.max(preferred, row.implicitWidth + 20)
        }
        measuredWidth = preferred
    }

    function selectNext(step) {
        if (!items.count) return
        for (let offset = 1; offset <= items.count; ++offset) {
            const index = (currentIndex + step * offset + items.count) % items.count
            const item = items.itemAt(index)
            if (!item?.actionable) continue
            currentIndex = index
            scroll.contentY = Math.max(0, Math.min(scroll.contentY, item.y))
            if (item.y + item.height > scroll.contentY + scroll.height)
                scroll.contentY = item.y + item.height - scroll.height
            return
        }
    }
    function activateCurrent() {
        const item = items.itemAt(currentIndex)
        if (item?.actionable) entryActivated(item.modelData)
    }
    Keys.onDownPressed: selectNext(1)
    Keys.onUpPressed: selectNext(-1)
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onSpacePressed: activateCurrent()
    Keys.onRightPressed: { if (items.itemAt(currentIndex)?.modelData.hasChildren) activateCurrent() }
    Keys.onLeftPressed: if (canGoBack) backRequested()
    Keys.onEscapePressed: closeRequested()

    SettingsButton {
        visible: root.canGoBack
        x: 10; y: 6
        width: parent.width - 20
        text: "‹ Back"
        activeFocusOnTab: root.canGoBack
        onClicked: root.backRequested()
    }
    Flickable {
        id: scroll
        x: 10; y: root.canGoBack ? 42 : 10
        width: Math.max(1, parent.width - 20)
        height: Math.max(0, parent.height - y - 10)
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: rows
            width: scroll.width - (scroll.contentHeight > scroll.height ? 10 : 0)
            spacing: 4
            Repeater {
                id: items
                model: root.entries
                onItemAdded: Qt.callLater(root.measureWidth)
                onItemRemoved: Qt.callLater(root.measureWidth)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool separator: !!modelData.isSeparator
                    readonly property bool header: !!modelData.isHeader
                    readonly property bool toggle: !!modelData.isToggle
                    readonly property bool checkable: !!modelData.buttonType
                    readonly property bool nativeEntry: modelData.buttonType !== undefined
                    readonly property bool actionable: !separator && !header && modelData.enabled !== false
                        && (!!modelData.hasChildren || typeof modelData.triggered === "function")
                    width: rows.width
                    implicitWidth: separator ? 1 : caption.implicitWidth + 20 + (toggle ? 48 : 26)
                    height: separator ? 1 : toggle ? 36 : 30
                    radius: separator ? 0 : 6
                    color: separator ? "#45475a" : actionable && (mouse.containsMouse || root.currentIndex === index) ? Theme.surface : "transparent"
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: caption.text
                    Accessible.onPressAction: if (actionable) root.entryActivated(modelData)
                    Text {
                        id: caption
                        objectName: "menuCaption"
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: row.toggle ? 54 : 26
                        visible: !row.separator
                        verticalAlignment: Text.AlignVCenter
                        text: (row.checkable ? (row.modelData.checkState !== Qt.Unchecked ? "✓ " : "□ ") : "")
                            + (row.nativeEntry ? String(row.modelData.text || "").replace(/&&/g, "\u0000").replace(/&/g, "").replace(/\u0000/g, "&") : String(row.modelData.text || ""))
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: row.header || row.toggle ? Theme.accent : row.modelData.enabled === false ? Theme.muted : Theme.text
                        font.pixelSize: row.header || row.toggle ? 14 : 12
                        onImplicitWidthChanged: Qt.callLater(root.measureWidth)
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        visible: !!row.modelData.hasChildren
                        text: "›"; color: Theme.accent; font.pixelSize: 18
                    }
                    Rectangle {
                        visible: row.toggle
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 18; radius: 9
                        opacity: row.actionable ? 1 : .4
                        color: row.modelData.checked ? Theme.accent : "#45475a"
                        Rectangle {
                            x: row.modelData.checked ? parent.width - width - 2 : 2
                            y: 2; width: 14; height: 14; radius: 7
                            color: row.modelData.checked ? Theme.background : Theme.text
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        enabled: row.actionable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.currentIndex = row.index
                        onClicked: { root.forceActiveFocus(); root.entryActivated(row.modelData) }
                    }
                }
            }
        }
    }
}
