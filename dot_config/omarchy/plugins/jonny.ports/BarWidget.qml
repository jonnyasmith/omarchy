import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Dev ports: the local servers that are actually listening, labelled by the
// project they were started from, one click from opening in the browser.
//
// `ports.sh` owns every bit of the awkwardness — parsing `ss`, reading labels
// out of /proc, collapsing the separate IPv4 and IPv6 binds of one server,
// and naming container ports without waking a sleeping Docker daemon. This
// file only draws what the script prints.
//
// The scan is not free, so it does not run when nobody is looking: slow ticks
// while collapsed, faster while the popup is open, and one immediate scan on
// open so the list is never stale in front of you.
BarWidget {
  id: root
  moduleName: "jonny.ports"

  readonly property int minPort: setting("minPort", 3000)
  readonly property int maxPort: setting("maxPort", 9999)
  readonly property int idleInterval: setting("interval", 10) * 1000
  readonly property int openInterval: setting("openInterval", 2) * 1000

  // Ports whose dev server speaks TLS. `ss` reports a socket, never a scheme,
  // so nothing but the user can know that :5001 wants https.
  readonly property var httpsPorts: setting("httpsPorts", [])

  property var rows: []
  property bool popupOpen: false

  // open/close/opened is the shape Bar.findPanelWidget looks for, so the popup
  // can be bound to a key through `omarchy-shell shell toggle jonny.ports`.
  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }

  // Beyond the BMP, so QML's four-digit \u escapes cannot express it.
  readonly property string glyph: String.fromCodePoint(0xF048D)

  // fa-external-link, inside the BMP and present in JetBrainsMono Nerd Font.
  readonly property string tabGlyph: "\uf08e"

  readonly property string tooltip: {
    if (rows.length === 0) return "No dev servers listening"
    var names = []
    for (var i = 0; i < rows.length && i < 4; i++) names.push(rows[i].label + " :" + rows[i].port)
    if (rows.length > 4) names.push("+" + (rows.length - 4) + " more")
    return names.join("\n")
  }

  function urlFor(port) {
    // Always localhost, never the address `ss` reported: Vite binds [::1] only,
    // so a literal 127.0.0.1 URL built from the port would be a dead link.
    var scheme = httpsPorts.indexOf(Number(port)) >= 0 ? "https" : "http"
    return scheme + "://localhost:" + port
  }

  // The row itself: a dedicated window with no tab strip or address bar, which
  // is what `--app=` gets you, and what most dev servers want to be.
  function openPort(port) {
    if (!bar) return
    // shellQuote lives on the Commons Util singleton, not on the bar — the bar
    // README lists it under `bar.` but no such method exists, and calling it
    // there throws out of the click handler without a trace.
    bar.run("omarchy-launch-or-focus-webapp "
      + Util.shellQuote("localhost:" + port) + " " + Util.shellQuote(urlFor(port)))
  }

  // The per-row button: an ordinary tab in whatever xdg-settings calls the
  // default browser, for when you want devtools, the URL bar, or your session.
  function openTab(port) {
    if (!bar) return
    bar.run("omarchy-launch-browser " + Util.shellQuote(urlFor(port)))
  }

  function publish(text) {
    var parsed = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (lines[i] === "") continue
      var parts = lines[i].split("\t")
      if (parts.length < 2) continue
      parsed.push({ port: parts[0], label: parts[1], detail: parts.length > 2 ? parts[2] : "" })
    }
    root.rows = parsed
  }

  function refresh() {
    if (!scan.running) scan.running = true
  }

  Process {
    id: scan
    command: [String(Qt.resolvedUrl("ports.sh")).replace("file://", ""),
              String(root.minPort), String(root.maxPort)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.publish(text)
    }
  }

  Timer {
    interval: root.popupOpen ? root.openInterval : root.idleInterval
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // A stale list is worse than a slow one, so never show the popup without a
  // fresh scan behind it.
  onPopupOpenChanged: if (popupOpen) refresh()

  visible: rows.length > 0
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? root.glyph : root.glyph + " " + root.rows.length
    active: root.popupOpen
    tooltipText: root.popupOpen ? "" : root.tooltip

    onPressed: function(pressedButton) {
      if (pressedButton === Qt.MiddleButton) root.refresh()
      else root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(list.implicitHeight)

    Column {
      id: list
      anchors.fill: parent
      spacing: Style.space(4)

      Repeater {
        model: root.rows

        BorderSurface {
          id: row
          required property var modelData

          // Hovering the button leaves the row area, so the row would otherwise
          // drop its highlight the moment you aim at the thing inside it.
          readonly property bool highlighted: rowArea.containsMouse || tabArea.containsMouse

          width: list.width
          height: inner.implicitHeight + Style.space(10)
          radius: Style.spacing.labelGap
          color: highlighted ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
          borderSpec: highlighted ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

          // Declared first, so the tab button -- a later sibling -- is above it
          // and takes its own clicks. Reversed, the full-row area eats them.
          MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.openPort(row.modelData.port)
              root.popupOpen = false
            }
          }

          Column {
            id: inner
            anchors.left: parent.left
            anchors.right: tabButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: row.borderLeft + Style.space(8)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(1)

            Row {
              spacing: Style.space(6)
              width: parent.width

              Text {
                text: row.modelData.label
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
                width: parent.width - portLabel.implicitWidth - Style.space(6)
              }

              Text {
                id: portLabel
                text: ":" + row.modelData.port
                color: Qt.darker(root.bar.foreground, 1.3)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            Text {
              text: row.modelData.detail
              color: Qt.darker(root.bar.foreground, 1.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }
          }

          Item {
            id: tabButton
            anchors.right: parent.right
            anchors.rightMargin: row.borderRight + Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(24)
            height: width

            Text {
              anchors.centerIn: parent
              text: root.tabGlyph
              color: tabArea.containsMouse ? Color.accent : Qt.darker(root.bar.foreground, 1.5)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: tabArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.openTab(row.modelData.port)
                root.popupOpen = false
              }
            }
          }
        }
      }
    }
  }
}
