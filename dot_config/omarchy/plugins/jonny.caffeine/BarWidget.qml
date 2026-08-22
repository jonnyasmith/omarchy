import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Caffeine: a keep-awake button with an optional countdown.
//
// No polling anywhere. The on/off half is Omarchy's own stay-awake flag, read
// straight off the idle service that already owns it, so a toggle from the
// menu, the built-in indicator, or this widget on another monitor lands here
// with no lag. The deadline and lid-hold half is published by the `caffeine`
// script into one small file, watched here. The countdown then ticks locally
// off that deadline rather than asking a subprocess every second.
BarWidget {
  id: root
  moduleName: "jonny.caffeine"

  readonly property var idleService: bar?.shell?.firstPartyServiceFor("omarchy.idle")
  readonly property bool awake: idleService ? idleService.stayAwake === true : false

  // Epoch seconds. Zero means an indefinite session.
  property double deadline: 0
  property bool lidHeld: false
  property double now: Date.now() / 1000

  readonly property int remaining: awake && deadline > 0 ? Math.max(0, Math.round(deadline - now)) : -1
  readonly property bool holdingLid: awake && lidHeld

  // Beyond the BMP, so QML's four-digit \u escapes cannot express them.
  readonly property string coffeeGlyph: String.fromCodePoint(0xF0176)
  readonly property string lidGlyph: String.fromCodePoint(0xF04B3)

  // The shared WidgetButton paints `active` in the theme's urgent role, which
  // is a red — wrong signal for a keep-awake toggle that is working as asked.
  // Coffee brown instead, at roughly the same lightness so it still reads on
  // any bar background.
  readonly property color awakeColor: "#a1673f"

  readonly property string glyph: holdingLid ? lidGlyph : coffeeGlyph
  readonly property string label: remaining >= 0 ? glyph + " " + formatRemaining(remaining) : glyph

  readonly property string tooltip: {
    if (!awake) return "Caffeine off — click to stay awake"
    var base = remaining >= 0 ? "Awake for " + formatRemaining(remaining) : "Awake indefinitely"
    if (holdingLid) base += ", lid close held"
    return base + " — right-click for presets"
  }

  function formatRemaining(seconds) {
    if (seconds >= 3600) {
      var hours = Math.floor(seconds / 3600)
      var minutes = Math.floor((seconds % 3600) / 60)
      return hours + "h" + (minutes < 10 ? "0" : "") + minutes
    }
    if (seconds >= 60) return Math.floor(seconds / 60) + "m"
    return seconds + "s"
  }

  function applyState(payload) {
    var data
    try {
      data = JSON.parse(payload || "{}")
    } catch (e) {
      data = {}
    }
    root.deadline = data.deadline ? Number(data.deadline) : 0
    root.lidHeld = data.lid === true
    root.now = Date.now() / 1000
  }

  function act(args) {
    if (!bar) return
    bar.run("caffeine " + args)
  }

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/caffeine.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyState(text())
    onLoadFailed: root.applyState("")
  }

  // Local countdown. Only runs while there is something to count down.
  Timer {
    interval: 1000
    repeat: true
    running: root.awake && root.deadline > 0
    onTriggered: {
      root.now = Date.now() / 1000
      // This tick and the expiry timer are not in lockstep. Once the deadline
      // has passed, go and read the state the script actually left behind
      // rather than trusting the zero on screen.
      if (root.deadline - root.now <= 0) stateFile.reload()
    }
  }

  // An external `omarchy toggle idle stay-awake` leaves no deadline behind, so
  // re-read on every flip rather than carrying a stale one into the new session.
  onAwakeChanged: stateFile.reload()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    active: root.awake
    activeColor: root.awakeColor
    dimmed: !root.awake
    tooltipText: root.tooltip

    onPressed: function(pressedButton) {
      if (pressedButton === Qt.RightButton) root.act("menu")
      else if (pressedButton === Qt.MiddleButton) root.act("on")
      else root.act("toggle")
    }

    onWheelMoved: function(delta) {
      if (delta === 0) return
      root.act(delta > 0 ? "step up" : "step down")
    }
  }
}
