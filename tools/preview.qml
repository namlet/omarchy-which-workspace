pragma ComponentBehavior: Bound

import QtQuick
import "../components"
import "../Model.js" as Model

// Mockup of the popup with made-up windows, run through the real Model.js and
// components. Thumbnails are stand-ins: the shell shows live window captures.
//   make preview              opens a window
//   make preview PNG=out.png  saves a picture instead
Rectangle {
  id: root

  readonly property string pngPath: {
    const args = Qt.application.arguments
    const i = args.indexOf("--png")
    return i !== -1 && i + 1 < args.length ? args[i + 1] : ""
  }

  // Tokyo Night, the theme this was drawn against.
  readonly property color fg: "#a9b1d6"
  readonly property color bg: "#1a1b26"
  readonly property color accent: "#7aa2f7"
  readonly property string font: "JetBrainsMono Nerd Font"
  readonly property string icons: "file:///usr/share/icons/hicolor/"

  // One 1920x1080 monitor, 26px bar, Omarchy's gaps.
  readonly property var monitor: ({ name: "HDMI-A-1", x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 })
  function win(address, appId, title, x, y, w, h, icon, floating) {
    return { address: address, appId: appId, title: title, at: [x, y], size: [w, h], floating: floating === true,
             icon: icon ? root.icons + icon : "" }
  }
  function workspacesWith(scratchpadDown) { return Model.occupiedWorkspaces([
    { id: 1, name: "1", monitor: monitor, windows: [
      win("a1", "chromium", "Pull requests · GitHub", 10, 36, 945, 1034, "128x128/apps/chromium.png"),
      win("a2", "foot", "~/Projects/omarchy-which-workspace", 965, 36, 945, 512, "scalable/apps/foot.svg"),
      win("a3", "btop", "btop", 965, 558, 945, 512, "scalable/apps/btop.svg") ] },
    { id: 2, name: "2", monitor: monitor, windows: [
      win("b1", "foot", "nvim BarWidget.qml", 10, 36, 1900, 1034, "scalable/apps/foot.svg") ] },
    { id: 3, name: "3", monitor: monitor, windows: [
      win("c1", "org.gnome.Nautilus", "Downloads", 10, 36, 630, 1034, "scalable/apps/org.gnome.Nautilus.svg"),
      win("c2", "omawrite", "Notes", 650, 36, 1260, 1034, "scalable/apps/omawrite.svg") ] },
    { id: 5, name: "5", monitor: monitor, windows: [
      win("d1", "chromium", "YouTube", 10, 36, 1900, 1034, "128x128/apps/chromium.png"),
      win("d2", "mpv", "talk.mkv", 560, 300, 800, 450, "scalable/apps/mpv.svg", true) ] },
    { id: -98, name: "special:scratchpad", shown: scratchpadDown, monitor: monitor, windows: [
      win("e1", "foot", "scratch", 360, 200, 1200, 680, "scalable/apps/foot.svg", true),
      win("e2", "btop", "btop", 460, 260, 1000, 560, "scalable/apps/btop.svg", true) ] }
  ]) }

  width: row.width + 48
  height: row.height + 48
  color: "#0f0f17"

  Row {
    id: row
    x: 24
    y: 24
    spacing: 32

    Repeater {
      model: [
        { caption: "Opened, scratchpad hidden", down: false, cursor: "" },
        { caption: "Scratchpad down (hotkey), pointer over Chromium", down: true, cursor: "0xa1" }
      ]

      Column {
        id: pane
        required property var modelData
        spacing: 8

        Text { text: pane.modelData.caption; color: "#565f89"; font.family: root.font; font.pixelSize: 13 }

        // The whole 1920x1080 screen, drawn at half size.
        Item {
          width: 960
          height: 540
          clip: true

          Item {
            id: screen
            width: 1920
            height: 1080
            scale: 0.5
            transformOrigin: Item.TopLeft

            // Wallpaper, with the bar along the bottom as on this machine.
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0; color: "#2b2f4a" }
                GradientStop { position: 1; color: "#6b3f6e" }
              }
            }
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 26
              color: root.bg
              Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                spacing: 14
                Text { text: "\u{F08C7}"; color: root.fg; font.family: root.font; font.pixelSize: 13 }
                Repeater {
                  model: ["1", "2", "3", "4", "5"]
                  Text { required property string modelData; text: modelData; color: root.fg; opacity: modelData === "4" ? 0.5 : 1; font.family: root.font; font.pixelSize: 12 }
                }
                Text { text: "\u{F11D9}"; color: root.accent; font.family: root.font; font.pixelSize: 13 }
              }
            }

            // The overlay: the theme's scrim (background at 50%), then the card.
            Rectangle { anchors.fill: parent; color: Qt.alpha(root.bg, 0.5) }

            Rectangle {
              id: card
              readonly property int margin: 40
              readonly property int inset: 20
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              anchors.topMargin: margin
              width: parent.width - margin * 2
              height: grid.implicitHeight + inset * 2
              radius: 8
              color: Qt.alpha(root.bg, 0.78)
              border.width: 2
              border.color: root.accent

              WorkspaceGrid {
                id: grid
                x: card.inset
                y: card.inset
                availableWidth: card.width - card.inset * 2
                availableHeight: screen.height - card.margin * 2 - card.inset * 2
                maxTileWidth: 480
                workspaces: root.workspacesWith(pane.modelData.down)
                cursorAddress: pane.modelData.cursor
                emptyText: "No open windows"
                foreground: root.fg
                background: root.bg
                accent: root.accent
                fontFamily: root.font
                fontSize: 14
                spacingSize: 18
                enterDuration: 0
                exitDuration: 0
                thumbnail: fakeApp
              }
            }
          }
        }
      }
    }
  }

  // Stand-ins for live captures: enough of each app's look to read the layout.
  Component {
    id: fakeApp

    Thumbnail {
      id: app
      readonly property string kind: win ? win.appId : ""

      Rectangle {
        anchors.fill: parent
        color: app.kind === "chromium" || app.kind === "omawrite" ? "#f4f4f6" : app.kind === "mpv" ? "#000000" : "#16161e"
      }
      // Browser: tab strip and a page.
      Column {
        visible: app.kind === "chromium"
        anchors.fill: parent
        spacing: 3
        Rectangle { width: parent.width; height: 6; color: "#dcdce4" }
        Rectangle { x: 6; width: parent.width * 0.5; height: 5; radius: 2; color: "#24292f" }
        Repeater { model: 9; Rectangle { required property int index; x: 6; width: (parent.width - 12) * (index % 3 === 2 ? 0.6 : 0.9); height: 2; color: "#c8c8d0" } }
      }
      // Terminal: prompt lines.
      Column {
        visible: app.kind === "foot"
        x: 4; y: 4
        spacing: 3
        Repeater {
          model: 8
          Row {
            id: line
            required property int index
            spacing: 3
            Rectangle { width: 5; height: 2; color: "#9ece6a" }
            Rectangle { width: (app.width - 20) * [0.5, 0.8, 0.3, 0.65, 0.4, 0.7, 0.2, 0.55][line.index]; height: 2; color: line.index % 3 === 0 ? root.accent : "#565f89" }
          }
        }
      }
      // btop: meters.
      Row {
        visible: app.kind === "btop"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        x: 4
        spacing: 2
        Repeater {
          model: 16
          Rectangle { required property int index; anchors.bottom: parent.bottom; width: (app.width - 40) / 16; height: (app.height - 12) * (0.2 + 0.7 * Math.abs(Math.sin(index * 1.7))); color: index % 4 === 0 ? "#f7768e" : index % 2 === 0 ? "#e0af68" : "#9ece6a" }
        }
      }
      // File manager: sidebar and folders.
      Rectangle { visible: app.kind === "org.gnome.Nautilus"; width: parent.width * 0.28; height: parent.height; color: "#1f2335" }
      Grid {
        visible: app.kind === "org.gnome.Nautilus"
        x: app.width * 0.32; y: 6
        columns: 3; spacing: 4
        Repeater { model: 9; Rectangle { width: 9; height: 7; radius: 1; color: root.accent } }
      }
      // Writer: a page of text.
      Column {
        visible: app.kind === "omawrite"
        x: app.width * 0.18; y: 6
        spacing: 3
        Rectangle { width: app.width * 0.4; height: 4; color: "#24292f" }
        Repeater { model: 12; Rectangle { required property int index; width: app.width * (index % 4 === 3 ? 0.4 : 0.64); height: 2; color: "#9aa0b4" } }
      }
      // Video: a frame.
      Rectangle {
        visible: app.kind === "mpv"
        anchors.fill: parent
        anchors.margins: 2
        gradient: Gradient {
          GradientStop { position: 0; color: "#bb9af7" }
          GradientStop { position: 1; color: "#2ac3de" }
        }
      }
    }
  }

  Timer {
    running: root.pngPath !== ""
    interval: 500
    onTriggered: root.grabToImage(function(result) {
      result.saveToFile(root.pngPath)
      Qt.quit()
    })
  }
}
