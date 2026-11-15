pragma ComponentBehavior: Bound

import QtQuick
import "../Model.js" as Model

// The overlay's content, Mission Control style: the occupied workspaces spread across
// the available width as large tiles, each row centered, and above them, centered, the
// scratchpad while it is down on screen. It slides down when its hotkey brings it in,
// and the tiles below give it room. Plain QtQuick; text arrives already translated so
// this loads headless.
Column {
  id: grid

  property var workspaces: []
  property string cursorAddress: ""
  property Component thumbnail: null
  property string emptyText: ""

  // The space to fill.
  property real availableWidth: 1200
  property real availableHeight: 700
  property real maxTileWidth: 480
  // Below this a row is too cramped and the tiles wrap to another row.
  property real minTileWidth: 260

  property color foreground: "#a9b1d6"
  property color background: "#1a1b26"
  property color accent: "#7aa2f7"
  property string fontFamily: "monospace"
  property real fontSize: 12
  property real spacingSize: 16
  // Style.duration(180) and Style.duration(120) in the shell: in quicker than out,
  // and 0 when the user has turned animations off.
  property int enterDuration: 180
  property int exitDuration: 120

  signal windowActivated(var win)
  signal windowHovered(var win)

  readonly property var regular: Model.regular(workspaces)
  readonly property var shownSpecial: Model.shownSpecial(workspaces)
  readonly property bool withMonitor: Model.spansMonitors(regular)
  readonly property real aspect: regular.length > 0 ? regular[0].aspect : 16 / 9
  // Caption line above each numbered tile (WorkspaceTile's text plus its gap).
  readonly property real captionHeight: Math.ceil(fontSize * 1.4) + 4

  readonly property bool scratchpadDown: shownSpecial.length > 0
  // The scratchpad is drawn as just its windows, cropped to them, at the scale the
  // workspace tiles have (a whole screen scratchpadTileWidth wide), so its window
  // shows at its real size beside theirs. Capped so it takes at most 40% of the height.
  readonly property var scratchpadCropped: shownSpecial.map(function(ws) { return Model.windowBounds(ws) })
  readonly property real scratchpadExtentH: scratchpadCropped.length > 0
    ? Math.max.apply(null, scratchpadCropped.map(function(ws) { return ws.extent.h })) : 0
  readonly property var unshiftedFit: Model.fitTiles(regular.length, availableWidth, availableHeight,
    spacingSize, aspect, captionHeight, maxTileWidth, minTileWidth)
  readonly property real scratchpadTileWidth: Math.floor(Math.min(unshiftedFit.tileWidth,
    scratchpadExtentH > 0 ? availableHeight * 0.4 * aspect / scratchpadExtentH : unshiftedFit.tileWidth))
  readonly property real scratchpadSpace: scratchpadDown
    ? scratchpadExtentH * scratchpadTileWidth / aspect + spacingSize : 0

  readonly property var fit: Model.fitTiles(regular.length, availableWidth, availableHeight - scratchpadSpace,
    spacingSize, aspect, captionHeight, maxTileWidth, minTileWidth)
  readonly property int columns: fit.columns
  // Animated, so the tiles shrink to make room as the scratchpad comes down.
  property real tileWidth: fit.tileWidth
  Behavior on tileWidth {
    NumberAnimation {
      duration: grid.scratchpadDown ? grid.enterDuration : grid.exitDuration
      easing.type: Easing.OutCubic
    }
  }

  // What the scratchpad area draws. Kept after the scratchpad goes, so its tile is
  // still there to slide away rather than vanishing first.
  property var scratchpadTiles: []
  onScratchpadCroppedChanged: if (scratchpadCropped.length > 0) scratchpadTiles = scratchpadCropped
  Component.onCompleted: scratchpadTiles = scratchpadCropped

  spacing: spacingSize
  width: availableWidth

  Item {
    id: scratchpad
    width: grid.width
    height: grid.scratchpadDown ? scratchpadRow.implicitHeight : 0
    visible: height > 0
    clip: true

    Behavior on height {
      NumberAnimation {
        duration: grid.scratchpadDown ? grid.enterDuration : grid.exitDuration
        easing.type: Easing.OutCubic
      }
    }

    // Hangs from the bottom edge, so a growing area reveals it top-first: it comes down.
    Row {
      id: scratchpadRow
      anchors.horizontalCenter: parent.horizontalCenter
      y: scratchpad.height - implicitHeight
      spacing: grid.spacingSize
      opacity: grid.scratchpadDown ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: grid.scratchpadDown ? grid.enterDuration : grid.exitDuration
          easing.type: Easing.OutCubic
        }
      }

      Repeater {
        model: grid.scratchpadTiles

        WorkspaceTile {
          required property var modelData
          workspace: modelData
          width: grid.scratchpadTileWidth * modelData.extent.w
          // Its place says what it is, and it shows only its windows.
          label: ""
          bare: true
          cursorAddress: grid.cursorAddress
          thumbnail: grid.thumbnail
          foreground: grid.foreground
          background: grid.background
          accent: grid.accent
          fontFamily: grid.fontFamily
          fontSize: grid.fontSize
          onWindowActivated: function(win) { grid.windowActivated(win) }
          onWindowHovered: function(win) { grid.windowHovered(win) }
        }
      }
    }
  }

  Text {
    visible: grid.regular.length === 0 && !scratchpad.visible
    width: grid.width
    textFormat: Text.PlainText
    text: grid.emptyText
    color: grid.foreground
    opacity: 0.55
    font.family: grid.fontFamily
    font.pixelSize: grid.fontSize
    horizontalAlignment: Text.AlignHCenter
  }

  // Each row centered on its own, so a short last row sits in the middle.
  Repeater {
    model: Model.chunk(grid.regular, grid.columns)

    Item {
      id: rowSlot
      required property var modelData
      width: grid.width
      height: tileRow.implicitHeight

      Row {
        id: tileRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: grid.spacingSize

        Repeater {
          model: rowSlot.modelData

          WorkspaceTile {
            required property var modelData
            workspace: modelData
            width: grid.tileWidth
            label: Model.workspaceLabel(modelData, grid.withMonitor)
            cursorAddress: grid.cursorAddress
            thumbnail: grid.thumbnail
            foreground: grid.foreground
            background: grid.background
            accent: grid.accent
            fontFamily: grid.fontFamily
            fontSize: grid.fontSize
            onWindowActivated: function(win) { grid.windowActivated(win) }
            onWindowHovered: function(win) { grid.windowHovered(win) }
          }
        }
      }
    }
  }
}
