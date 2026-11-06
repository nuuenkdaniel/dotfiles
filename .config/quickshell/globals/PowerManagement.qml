pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
  id: root
  property var state: ({})
  property string error: ""
  property var queue: []
  property var currentAction: []
  property string output: ""
  property bool executing: false
  signal actionFinished(string action, bool success)
  property int visiblePanels: 0
  readonly property int liveBrightness: DisplayState.ready ? DisplayState.current : state.brightness?.current ?? -1
  readonly property bool busy: (executing && !["status", "tick", "reconcile"].includes(currentAction[0]))
    || queue.some(action => !["status", "tick", "reconcile"].includes(action[0]))
  readonly property bool authorizing: executing && (
    ["cpu", "charging"].includes(currentAction[0])
    || (["mode", "apply-preset"].includes(currentAction[0])
      && (state.customCpuActive || currentAction[1] === "saver" || ((currentAction[1] === "custom" || currentAction[0] === "apply-preset") && prefs.customCpuEnabled))))
  // Display-only permission caches must never decide whether an authentication
  // dialog could appear. Conservatively release overlay focus for these actions.
  readonly property string script: decodeURIComponent(Qt.resolvedUrl("../bin/power.py").toString().replace("file://", ""))
  readonly property var prefs: state.prefs ?? ({})
  readonly property bool automationEnabled: !!(prefs.autoLow || prefs.autoUnplug || prefs.normalOnAc)
  property bool pendingAutomation: false
  property bool pendingReconcile: false
  onAutomationEnabledChanged: {
    if (automationEnabled) Qt.callLater(root.evaluateAutomation)
    else pendingAutomation = false
  }

  function evaluateAutomation() {
    if (!automationEnabled) return
    if (executing || queue.length > 0) { pendingAutomation = true; return }
    pendingAutomation = false
    root.run(["tick"])
  }
  function reconcileProfile() {
    pendingReconcile = true
    flushBackground()
  }
  function flushBackground() {
    if (executing || queue.length > 0) return
    if (pendingReconcile) { pendingReconcile = false; run(["reconcile"]) }
    else if (pendingAutomation && automationEnabled) evaluateAutomation()
  }
  Connections {
    target: PowerProfiles
    function onProfileChanged() { root.reconcileProfile() }
  }
  Connections {
    target: UPower
    function onOnBatteryChanged() { root.evaluateAutomation() }
  }
  Connections {
    target: UPower.displayDevice
    function onPercentageChanged() { root.evaluateAutomation() }
    function onReadyChanged() { root.evaluateAutomation() }
  }

  function run(args) {
    if (["status", "tick", "reconcile"].includes(args[0]) && (executing || queue.length > 0)) return
    queue = queue.concat([args])
    next()
  }

  function next() {
    if (executing || worker.running || queue.length === 0) return
    currentAction = queue[0]
    queue = queue.slice(1)
    output = ""
    worker.command = ["python3", root.script].concat(currentAction)
    executing = true
    worker.running = true
  }

  function preference(key, value) {
    run(["preference", key, JSON.stringify(value)])
  }

  Component.onCompleted: run(["status"])

  Timer {
    interval: 2000
    running: root.visiblePanels > 0
    repeat: true
    onTriggered: root.run(["status"])
  }

  Process {
    id: worker
    stdout: StdioCollector { onStreamFinished: root.output = text }
    stderr: StdioCollector { id: errors }
    onExited: (code, status) => root.finishRequest(code, errors.text)
    // Quickshell emits runningChanged, but not exited, on FailedToStart.
    onRunningChanged: if (!running && root.executing) Qt.callLater(root.checkWorker)
  }
  function checkWorker() {
    if (executing && !worker.running) finishRequest(-1, "Could not start the power service (python3)")
  }
  function finishRequest(code, message) {
      if (!root.executing) return
      const completedAction = root.currentAction[0] ?? ""
      let success = false
      try {
        if (code !== 0) throw new Error(message || "Power service could not complete the request")
        const result = JSON.parse(root.output)
        root.state = result
        if (result.error) root.error = result.error
        else if (!["status", "tick", "reconcile"].includes(root.currentAction[0])) root.error = ""
        success = !result.error
      } catch (exception) {
        root.error = String(exception)
      }
      root.actionFinished(completedAction, success)
      root.executing = false
      if (completedAction === "preference" && success && root.automationEnabled) root.pendingAutomation = true
      // Drain explicit user actions before processing deferred background events.
      Qt.callLater(root.drainQueue)
  }
  function drainQueue() {
    next()
    flushBackground()
  }
}
