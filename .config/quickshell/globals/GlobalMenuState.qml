pragma Singleton
import QtQuick

QtObject {
    property bool isVisible: false
    property bool animatePosition: false
    property real targetY: 0
    property var menuModel: []
    property bool persist: false
    property int menuType: 0
    property string screenName: ""
    property int sidebarWidth: 55
    property var menuSource: null
    property int openRevision: 0
    function ownsScreen(name, defaultName) {
        return name === (screenName || defaultName)
    }
    onIsVisibleChanged: if (!isVisible) {
        animatePosition = false
        menuSource = null
        menuModel = []
    }

    function openAt(y, model, type, keepOpen, ownerName = "", ownerWidth = 55, source = null) {
        // Set the animation policy BEFORE changing geometry or content. Initial
        // surface/layout corrections snap; switches between open menus animate.
        animatePosition = isVisible && screenName === ownerName
        screenName = ownerName
        sidebarWidth = ownerWidth
        targetY = y
        persist = keepOpen
        menuType = type
        menuModel = model
        menuSource = source
        openRevision += 1
        isVisible = true
    }
}
