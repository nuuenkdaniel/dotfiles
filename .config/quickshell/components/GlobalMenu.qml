pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../globals"

PanelWindow {
    id: root
    visible: GlobalMenuState.isVisible
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    property int sidebarWidth: 55
    readonly property bool ownsMenu: GlobalMenuState.ownsScreen(screen?.name ?? "", Quickshell.screens[0]?.name ?? "")
    readonly property real positioningHeight: height > 1 ? height : (screen?.height ?? 0)
    readonly property bool joinedToBar: visible && ownsMenu
    property var openMenus: []
    readonly property var currentMenu: openMenus.length ? openMenus[openMenus.length - 1] : null
    function clearNavigation() {
        const previous = openMenus
        openMenus = []
        for (let i = previous.length - 1; i >= 0; --i) previous[i].destroy()
    }
    function enterSubmenu(entry) {
        const opener = submenuFactory.createObject(root, {menu: entry})
        if (opener) openMenus = openMenus.concat([opener])
    }
    function goBack() {
        if (!openMenus.length) return
        const previous = currentMenu
        openMenus = openMenus.slice(0, -1)
        previous.destroy()
    }
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "shell-menu"
    WlrLayershell.keyboardFocus: visible && ownsMenu ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Keep the sidebar clickable for smooth menu switching; empty sidebar clicks
    // are caught by its own background. Every other output still catches clicks.
    mask: Region { x: root.sidebarWidth; y: 0; width: Math.max(1, root.width - x); height: root.height }
    Component.onDestruction: if (ownsMenu && GlobalMenuState.isVisible) GlobalMenuState.isVisible = false
    onScreenChanged: if (GlobalMenuState.isVisible && GlobalMenuState.screenName
        && !Quickshell.screens.some(output => output.name === GlobalMenuState.screenName)) GlobalMenuState.isVisible = false
    Connections {
        target: GlobalMenuState
        function onOpenRevisionChanged() { root.clearNavigation(); if (menu.item) menu.item.forceActiveFocus() }
        function onIsVisibleChanged() {
            if (!GlobalMenuState.isVisible) { popup.snap(); root.clearNavigation() }
        }
    }
    QsMenuOpener {
        id: trayMenu
        menu: root.visible && root.ownsMenu ? GlobalMenuState.menuSource?.menu ?? null : null
    }
    // Keep ancestor menus open while navigating deeper; some tray applications
    // discard dynamic children as soon as their parent receives a closed event.
    Component { id: submenuFactory; QsMenuOpener {} }
    SidebarMenuReveal {
        id: reveal
        opened: root.visible && root.ownsMenu && menu.status === Loader.Ready
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: GlobalMenuState.isVisible = false }
    // Clip the entrance and its shadow at the bar's edge, not over its icons.
    // A one-pixel overlap avoids a fractional-scale compositor seam.
    Item {
      x: root.sidebarWidth - 1
      width: Math.max(1, root.width - x)
      height: root.height
      clip: true
      SidebarMenuGeometry {
        id: popup
        visible: root.ownsMenu
        x: reveal.offset
        anchorY: GlobalMenuState.targetY
        availableHeight: root.positioningHeight
        targetWidth: menu.item?.implicitWidth ?? 240
        targetHeight: menu.item?.implicitHeight ?? 0
        // Fresh opens lay out immediately underneath the slide-out. Once open,
        // menu switches, submenus and live model changes share the same morph.
        animateChanges: root.visible && root.ownsMenu && (GlobalMenuState.animatePosition || reveal.progress === 1)
        opacity: reveal.progress
        SidebarMenuBackground {
            y: -shoulder
            width: parent.width
            panelHeight: popup.height
            reachesBottom: popup.y + popup.height >= root.positioningHeight - .5
            layer.enabled: popup.visible && root.visible
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1; shadowColor: "#bf000000" }
        }
        MouseArea { anchors.fill: parent }
        Loader {
            id: menu
            anchors.fill: parent
            active: root.visible && root.ownsMenu
            onLoaded: item.forceActiveFocus()
            sourceComponent: PopupMenuContent {
                menuModel: root.currentMenu ? root.currentMenu.children : GlobalMenuState.menuSource ? trayMenu.children : GlobalMenuState.menuModel
                maximumWidth: Math.max(1, root.width - GlobalMenuState.sidebarWidth - 12)
                maximumHeight: Math.max(1, root.positioningHeight - 12)
                canGoBack: root.openMenus.length > 0
                onBackRequested: root.goBack()
                onCloseRequested: GlobalMenuState.isVisible = false
                onEntryActivated: entry => {
                    if (entry.hasChildren) root.enterSubmenu(entry)
                    else {
                        entry.triggered()
                        if (!GlobalMenuState.persist) GlobalMenuState.isVisible = false
                    }
                }
            }
        }
      }
    }
}
