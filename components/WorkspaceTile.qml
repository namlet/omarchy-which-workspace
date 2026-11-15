pragma ComponentBehavior: Bound

import QtQuick

// One workspace drawn as a tiny screen: its label above, and each window at its real
// place, scaled down, showing whatever `thumbnail` draws for it (a live capture in the
// shell, a stand-in in the preview and tests). Plain QtQuick, no qs.* or Quickshell,
// so it loads headless.
Item {
  id: tile

  required property var workspace
  property string label: ""
  property string cursorAddress: ""
  // Builds a Thumbnail for each window.
  property Component thumbnail: null
  // Just the windows: no screen fill or border behind them (the scratchpad).
  property bool bare: false

  property color foreground: "#a9b1d6"
  property color background: "#1a1b26"
  property color accent: "#7aa2f7"
  property string fontFamily: "monospace"
  property real fontSize: 12
  property real radius: 6
  // Gap between neighbouring windows inside the tile, like Hyprland's gaps_in.
  property real gap: 2

  signal windowActivated(var win)
  signal windowHovered(var win)

  // App icon badge, growing with the tile so it stays readable on big tiles.
  readonly property int iconBox: Math.round(Math.max(18, Math.min(34, width * 0.075)))
  readonly property real aspect: workspace && workspace.aspect > 0 ? workspace.aspect : 16 / 9
  readonly property alias screen: screen

  implicitWidth: 200
  // No label, no caption line: the screen starts at the top.
  readonly property real captionSpace: label !== "" ? caption.height + 4 : 0
  implicitHeight: captionSpace + width / aspect

  Text {
    id: caption
    visible: tile.label !== ""
    width: parent.width
    textFormat: Text.PlainText
    text: tile.label
    color: tile.foreground
    opacity: 0.7
    font.family: tile.fontFamily
    font.pixelSize: tile.fontSize
    elide: Text.ElideRight
  }

  Rectangle {
    id: screen
    y: tile.captionSpace
    width: parent.width
    height: width / tile.aspect
    radius: tile.radius
    color: tile.bare ? "transparent" : Qt.darker(tile.background, 1.25)
    border.width: tile.bare ? 0 : 1
    border.color: Qt.alpha(tile.foreground, 0.18)
    clip: true

    Repeater {
      model: tile.workspace ? tile.workspace.windows : []

      Item {
        id: cell
        required property var modelData
        readonly property bool current: tile.cursorAddress !== "" && tile.cursorAddress === modelData.address
        readonly property bool hovered: mouse.containsMouse

        x: modelData.rect.x * screen.width + tile.gap
        y: modelData.rect.y * screen.height + tile.gap
        width: Math.max(4, modelData.rect.w * screen.width - 2 * tile.gap)
        height: Math.max(4, modelData.rect.h * screen.height - 2 * tile.gap)

        Rectangle {
          id: frame
          anchors.fill: parent
          radius: Math.max(2, tile.radius - 2)
          color: tile.background
          clip: true

          // `thumbnail` builds a Thumbnail, which is handed its window here.
          Loader {
            anchors.fill: parent
            sourceComponent: tile.thumbnail
            onLoaded: {
              const thumb = item as Thumbnail
              if (thumb) thumb.win = Qt.binding(function() { return cell.modelData })
            }
          }
        }

        // App icon, bottom-left, so a window too small to read is still recognisable.
        Rectangle {
          visible: cell.modelData.icon !== "" && cell.width > tile.iconBox * 1.6 && cell.height > tile.iconBox * 1.2
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.margins: Math.round(tile.iconBox / 6)
          width: tile.iconBox
          height: tile.iconBox
          radius: Math.round(tile.iconBox / 4.5)
          color: Qt.alpha(tile.background, 0.85)

          Image {
            anchors.centerIn: parent
            width: Math.round(tile.iconBox * 0.78)
            height: width
            source: cell.modelData.icon
            sourceSize.width: 64
            sourceSize.height: 64
            asynchronous: true
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: frame.radius
          color: cell.current || cell.hovered ? Qt.alpha(tile.accent, 0.12) : "transparent"
          border.width: cell.current || cell.hovered ? 2 : 1
          border.color: cell.current || cell.hovered ? tile.accent : Qt.alpha(tile.foreground, 0.25)
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: tile.windowHovered(cell.modelData)
          onClicked: tile.windowActivated(cell.modelData)
        }
      }
    }
  }
}
