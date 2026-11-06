pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../globals"
import "../components"

PanelWindow {
    id: root
    signal settingsRequested(string screenName)
    screen: Quickshell.screens.find(s => s.name === DashboardState.screenName) ?? Quickshell.screens[0]
    onScreenChanged: if (DashboardState.opened && screen?.name !== DashboardState.screenName) DashboardState.opened = false
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-dashboard"
    WlrLayershell.keyboardFocus: DashboardState.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: transition.presented
    readonly property real availableWidth: Math.max(1, width - DashboardState.sidebarWidth)
    readonly property real panelWidth: Math.min(820, Math.max(1, availableWidth - 64))
    property real panelHeight: Math.min(DashboardState.tab === 0 ? 432 : 264, Math.max(140, height - 48))
    Behavior on panelHeight { NumberAnimation { duration: DashboardState.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
    readonly property real panelLeft: DashboardState.sidebarWidth + (availableWidth - panelWidth) / 2
    readonly property real progress: transition.progress
    onVisibleChanged: if (visible) content.forceActiveFocus()
    Connections {
        target: DashboardState
        function onScreenNameChanged() { transition.reset() }
        function onOpenedChanged() {
            if (DashboardState.opened) { GlobalMenuState.isVisible = false; content.forceActiveFocus() }
        }
    }
    DashboardTransition { id: transition; opened: DashboardState.opened; reducedMotion: DashboardState.reducedMotion }
    // Let the real sidebar (including its Arch button) receive its own clicks.
    mask: Region { x: DashboardState.sidebarWidth; y: 0; width: root.availableWidth; height: root.height }
    MouseArea { anchors.fill: parent; enabled: DashboardState.opened; onClicked: DashboardState.opened = false }
    DashboardBackground {
        anchors.fill: parent
        panelLeft: root.panelLeft
        panelWidth: root.panelWidth
        panelHeight: root.panelHeight * Math.max(0, root.progress)
        stripHeight: 6 * Math.min(1, Math.max(0, root.progress))
        opacity: Math.min(1, Math.max(0, root.progress * 3))
        layer.enabled: root.visible
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: .5; shadowVerticalOffset: 3; shadowOpacity: .35; blurMax: 12 }
    }
    Item {
        id: content
        x: root.panelLeft
        y: 6
        width: root.panelWidth
        height: root.panelHeight * Math.max(0, root.progress)
        clip: true
        focus: DashboardState.opened
        Keys.onEscapePressed: DashboardState.opened = false
        MouseArea { anchors.fill: parent }
        Loader {
            active: root.visible
            x: 18
            y: root.panelHeight * (root.progress - 1) + 12
            width: Math.max(1, root.panelWidth - 36)
            height: root.panelHeight - 30
            opacity: Math.min(1, Math.max(0, root.progress))
            sourceComponent: DashboardContent {
                active: DashboardState.opened
            }
        }
    }
    IpcHandler {
        target: "dashboard"
        function toggle(): void {
            const monitor = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || ""
            const output = Quickshell.screens.find(s => s.name === monitor)
            DashboardState.toggle(monitor, Math.max((output?.width || 1920) * .023, 55))
        }
        function close(): void { DashboardState.opened = false }
        function tab(index: int): void {
            if (index >= 0 && index <= 1) DashboardState.tab = index
        }
        function settings(): void {
            DashboardState.opened = false
            root.settingsRequested(DashboardState.screenName || root.screen?.name || "")
        }
    }
}
