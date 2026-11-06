pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "ShellUtils.js" as Utils

Singleton {
    id: root
    readonly property string session: Utils.notificationSession(processStat.text(), bootId.text())
    readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/notifications"
    readonly property var notifications: server.trackedNotifications
    readonly property var entries: ready ? archive.entries : pending
    readonly property int unreadCount: entries.filter(entry => entry.timestamp > archive.lastReadTime).length
    property bool ready: false
    property var pending: []
    property string error: ""

    function snapshot(notification, replayed = false) {
        const entry = {
            key: root.session + ":" + notification.id,
            session: root.session, id: notification.id,
            timestamp: Date.now(), appName: notification.appName || "",
            appIcon: notification.appIcon || "", desktopEntry: notification.desktopEntry || "",
            summary: (notification.summary || "").slice(0, 500),
            body: (notification.body || "").slice(0, 8000),
            critical: notification.urgency === NotificationUrgency.Critical,
            replayed: replayed
        }
        if (!ready) pending = Utils.mergeHistory(pending, entry, 100)
        else archive.entries = Utils.mergeNotificationHistory(archive.entries, entry, 100)
    }

    function finishLoading() {
        let entries = Utils.cleanHistory(archive.entries)
        for (const entry of pending.slice().reverse()) entries = Utils.mergeNotificationHistory(entries, entry, 100)
        ready = true
        archive.entries = entries
        pending = []
        saveTimer.restart()
    }

    function liveNotification(entry) {
        if (entry.session !== root.session) return null
        return server.trackedNotifications.values.find(notification => notification.id === entry.id) ?? null
    }

    function activate(entry) {
        const notification = liveNotification(entry)
        if (!notification) return false
        const actions = notification.actions
        const action = actions.find(action => action.identifier === "default")
            ?? actions.find(action => ["show", "open", "view"].includes(action.identifier.toLowerCase()) || /^(show|open|view)(\s|$)/i.test(action.text.trim()))
        if (!action) return false
        action.invoke()
        return true
    }

    function remove(key) {
        const entry = root.entries.find(entry => entry.key === key)
        const notification = entry ? liveNotification(entry) : null
        if (notification) notification.dismiss()
        if (ready) archive.entries = archive.entries.filter(entry => entry.key !== key)
        else pending = pending.filter(entry => entry.key !== key)
    }
    function clear() { archive.entries = []; pending = []; archive.lastReadTime = Date.now() }
    function markRead() { archive.lastReadTime = Date.now() }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: false
        onNotification: notification => {
            notification.tracked = true
            root.snapshot(notification, notification.lastGeneration)
        }
    }

    FileView { id: processStat; path: "/proc/self/stat"; blockLoading: true; printErrors: false }
    FileView { id: bootId; path: "/proc/sys/kernel/random/boot_id"; blockLoading: true; printErrors: false }

    Instantiator {
        model: server.trackedNotifications
        delegate: Connections {
            required property var modelData
            target: modelData
            function onSummaryChanged() { root.snapshot(modelData) }
            function onBodyChanged() { root.snapshot(modelData) }
            function onAppNameChanged() { root.snapshot(modelData) }
            function onAppIconChanged() { root.snapshot(modelData) }
            function onDesktopEntryChanged() { root.snapshot(modelData) }
        }
    }

    Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", root.directory]
        onExited: (code, status) => {
            if (code === 0) historyFile.path = root.directory + "/history.json"
            else root.error = "Could not create notification history directory"
        }
    }
    Timer { id: saveTimer; interval: 200; onTriggered: if (root.ready) historyFile.writeAdapter() }
    FileView {
        id: historyFile
        printErrors: false
        atomicWrites: true
        onLoaded: root.finishLoading()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) root.finishLoading()
            else root.error = "Could not load notification history; incoming notifications remain available for this session"
        }
        onSaveFailed: error => root.error = "Could not save notification history"
        onAdapterUpdated: if (root.ready) saveTimer.restart()
        JsonAdapter {
            id: archive
            property list<var> entries: []
            property double lastReadTime: 0
        }
    }
}
