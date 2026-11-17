import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "components"

// Shell adapter: a bar button that opens a Mission Control style overlay. A
// translucent scrim covers the screen, and a centered, full-width, see-through card
// spreads every occupied workspace across it as a tiny screen, each window at its real
// place showing a capture of it. Clicking a window (or Enter on it) focuses it, which
// also switches to its workspace. Layout, ordering and validation live in Model.js;
// drawing in components/.
Panel {
  id: root
  moduleName: "io.github.namlet.which-workspace"
  ipcTarget: "io.github.namlet.which-workspace"

  // How much of the card's background shows through: enough to feel like it floats,
  // little enough that the tiles stay easy to read.
  readonly property real cardOpacity: 0.78

  // Re-evaluates whenever Hyprland's workspace or window models change, so the
  // overlay is live while open without any polling.
  readonly property var workspaces: Model.occupiedWorkspaces(Hyprland.workspaces.values.map(function(ws) {
    var m = ws.monitor
    var mIpc = m ? (m.lastIpcObject || {}) : {}
    return {
      id: ws.id,
      name: ws.name,
      shown: root.shownSpecialNames.indexOf(ws.name) !== -1,
      monitor: m ? { name: m.name, x: m.x, y: m.y, width: m.width, height: m.height, scale: m.scale, transform: mIpc.transform } : null,
      windows: ws.toplevels.values.map(function(t) {
        var ipc = t.lastIpcObject || {}
        var appId = (t.wayland && t.wayland.appId) || ipc["class"] || ""
        return {
          address: t.address || ipc.address,
          appId: appId,
          title: t.title || ipc.title || "",
          at: ipc.at,
          size: ipc.size,
          floating: ipc.floating === true,
          // Hyprland's own record of the window's monitor, for Model.canCapture.
          monitorId: ipc.monitor,
          mapped: ipc.mapped,
          icon: root.iconFor(appId),
          ref: t
        }
      })
    }
  }), root.monitorList)

  // Monitors as Hyprland reports them now. A window may be captured only while its
  // monitor is in this list (see Model.canCapture).
  readonly property var monitorList: Hyprland.monitors.values.map(function(m) {
    var ipc = m.lastIpcObject || {}
    return { id: m.id, disabled: ipc.disabled === true, width: m.width, height: m.height }
  })

  // Special workspaces down on some monitor right now (the scratchpad after its hotkey).
  readonly property var shownSpecialNames: Hyprland.monitors.values.map(function(m) {
    var special = (m.lastIpcObject || {}).specialWorkspace
    return special && special.name ? String(special.name) : ""
  }).filter(function(name) { return name !== "" })

  // Keyboard order follows the screen: the scratchpad (while down) above, then the rest.
  readonly property var windows: Model.flatWindows(Model.shownSpecial(root.workspaces).concat(Model.regular(root.workspaces)))
  property string cursorAddress: ""

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function focusWindow(win) {
    var expression = Model.focusExpression(win ? win.address : "")
    if (expression !== "") Hyprland.dispatch(expression)
    root.close()
  }

  function moveCursor(delta) {
    var addresses = root.windows.map(function(w) { return w.address })
    var next = Model.moveCursor(addresses.indexOf(root.cursorAddress), delta, addresses.length)
    root.cursorAddress = next >= 0 ? addresses[next] : ""
  }

  function activateCursor() {
    var index = root.windows.map(function(w) { return w.address }).indexOf(root.cursorAddress)
    if (index >= 0) root.focusWindow(root.windows[index])
  }

  function iconFor(appId) {
    var entry = appId ? DesktopEntries.heuristicLookup(appId) : null
    return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
  }

  onOpenedChanged: if (opened) {
    root.cursorAddress = ""
    // Geometry and class come from Hyprland's IPC snapshot; ask for a fresh one.
    Hyprland.refreshMonitors()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Quickshell keeps window geometry and monitors only in IPC snapshots, so refresh
  // them on the events that change them (no polling):
  // - A monitor coming or going leaves windows without one until Hyprland settles, and
  //   starting a capture then crashes Hyprland. Close at once, which stops every
  //   capture, and refresh so the next open sees the new state.
  // - The scratchpad hotkey changes a monitor's special workspace without a workspace
  //   switch, and may move the scratchpad window first.
  // - A new or moved window has no geometry until refreshed; without it, it is drawn
  //   stretched to the tile.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name.indexOf("monitoradded") === 0 || name.indexOf("monitorremoved") === 0) {
        root.close()
        Hyprland.refreshMonitors()
        Hyprland.refreshToplevels()
      } else if (name.indexOf("activespecial") === 0) {
        Hyprland.refreshMonitors()
        Hyprland.refreshToplevels()
      } else if (name === "openwindow" || name.indexOf("movewindow") === 0 || name === "changefloatingmode") {
        Hyprland.refreshToplevels()
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{F11D9}"
    tooltipText: root.opened ? "" : strings.t("bar.tooltip")
    onPressed: function(buttonCode) { root.toggle() }
  }

  // A still capture of one window, taken each time the overlay opens rather than
  // streamed, so an open overlay costs nothing while it sits there. The scratchpad is
  // the exception: it comes down while the overlay is open, mid-slide, so a single
  // capture catches a frame from its transition. Its windows stay live while it's down
  // and the overlay is open, and settle on what is really there.
  //
  // Drawn small, a capture sampled straight from its full-size texture aliases badly
  // (a 1920px window into a 200px tile skips most of its pixels). So the capture is
  // laid out at its own size, hidden, and shown through a mipmapped texture, which
  // the GPU averages down smoothly to whatever size the tile asks for.
  Component {
    id: liveThumbnail

    Thumbnail {
      id: thumb

      ScreencopyView {
        id: capture
        // Full resolution, capped so a huge window doesn't cost a huge texture.
        readonly property real cap: 2560
        readonly property real fit: sourceSize.width > 0 ? Math.min(1, cap / Math.max(sourceSize.width, sourceSize.height)) : 1
        width: Math.max(1, sourceSize.width * fit)
        height: Math.max(1, sourceSize.height * fit)
        // Only while the overlay is open, and only for a window Hyprland places on a
        // present monitor (Model.canCapture). Starting a capture of a window with no
        // monitor crashes Hyprland 0.56.2 in CScreenshareSession::init: it happens
        // around monitor sleep, wake and unplug. A window that can't be captured shows
        // just its icon. A ScreencopyView grabs a frame as soon as it has a source, and
        // the tiles exist even while the overlay is closed, so closing releases them.
        readonly property bool allowed: root.opened && thumb.win !== null && thumb.win.capturable === true
        captureSource: allowed && thumb.win.ref ? thumb.win.ref.wayland : null
        live: allowed && thumb.win.special === true

        Connections {
          target: root
          function onOpenedChanged() { if (root.opened && capture.captureSource) capture.captureFrame() }
        }
      }

      ShaderEffectSource {
        anchors.fill: parent
        sourceItem: capture
        hideSource: true
        mipmap: true
        smooth: true
        visible: capture.hasContent
      }
    }
  }

  OverlayWindow {
    id: overlay
    shown: root.opened
    WlrLayershell.namespace: "io.github.namlet.which-workspace"

    readonly property int screenMargin: Style.space(40)
    readonly property int borderWidth: Math.max(1, Style.space(2))
    readonly property int inset: Style.spacing.panelPadding + borderWidth

    // The theme's own scrim, as the dock's app grid uses: the desktop dims behind.
    Rectangle {
      anchors.fill: parent
      color: Commons.Color.menu.scrim
    }

    // A click anywhere off the card dismisses, like Mission Control.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      // Along the top of the screen, like Mission Control's row of spaces.
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: overlay.screenMargin
      width: parent.width - overlay.screenMargin * 2
      height: grid.implicitHeight + overlay.inset * 2
      radius: Style.cornerRadius
      color: Qt.alpha(Commons.Color.menu.background, root.cardOpacity)
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, overlay.borderWidth)
      padding: Style.spacing.panelPadding

      // Slides down from the top edge as it fades in, and back up as it goes.
      property real shown: root.opened ? 1 : 0
      Behavior on shown {
        id: showing
        NumberAnimation {
          duration: Style.duration(showing.targetValue > 0 ? 180 : 120)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      opacity: shown
      transform: Translate { y: -(1 - card.shown) * Style.space(24) }

      // Clicks on the card itself, between tiles, don't dismiss.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
      }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        anchors.margins: overlay.inset
        onMoveRequested: function(dx, dy) { root.moveCursor(dx + dy) }
        onActivateRequested: root.activateCursor()
        onCloseRequested: root.close()

        WorkspaceGrid {
          id: grid
          availableWidth: keyCatcher.width
          availableHeight: overlay.height - overlay.screenMargin * 2 - overlay.inset * 2
          maxTileWidth: Style.space(480)
          minTileWidth: Style.space(260)
          workspaces: root.workspaces
          cursorAddress: root.cursorAddress
          thumbnail: liveThumbnail
          emptyText: strings.t("panel.empty")
          foreground: Commons.Color.menu.text
          background: Commons.Color.menu.background
          accent: Commons.Color.accent
          fontFamily: Style.font.family
          fontSize: Style.font.body
          spacingSize: Style.space(18)
          enterDuration: Style.duration(180)
          exitDuration: Style.duration(120)
          onWindowActivated: function(win) { root.focusWindow(win) }
          onWindowHovered: function(win) { root.cursorAddress = win.address }
        }
      }
    }
  }
}
