import QtQuick
import QtTest
import "../components"
import "../Model.js" as Model

Item {
  id: root
  width: 700
  height: 500

  readonly property var monitor: ({ name: "M", x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 })

  WorkspaceGrid {
    id: grid
    availableWidth: 700
    availableHeight: 500
    maxTileWidth: 300
    minTileWidth: 150
    emptyText: "No open windows"
    thumbnail: Component { Thumbnail {} }
    enterDuration: 0
    exitDuration: 0
  }

  SignalSpy { id: activated; target: grid; signalName: "windowActivated" }

  function sample(scratchpadDown) {
    return Model.occupiedWorkspaces([
      { id: 1, name: "1", monitor: root.monitor, windows: [
        { address: "0x1", appId: "left", title: "", at: [0, 0], size: [960, 1080] },
        { address: "0x2", appId: "right", title: '<img src="https://example.invalid/t">', at: [960, 0], size: [960, 1080] } ] },
      { id: 3, name: "3", monitor: root.monitor, windows: [{ address: "0x3", appId: "x", title: "", at: [0, 0], size: [1920, 1080] }] },
      { id: -98, name: "special:s", shown: scratchpadDown === true, monitor: root.monitor, windows: [{ address: "0x9", appId: "s", title: "", at: [480, 270], size: [960, 540] }] }
    ])
  }

  function findAll(item, test, out) {
    out = out || []
    if (test(item)) out.push(item)
    for (let i = 0; i < item.children.length; i++) findAll(item.children[i], test, out)
    return out
  }

  function tiles() { return root.findAll(grid, function(i) { return i.workspace !== undefined && i.windowActivated !== undefined && i.visible }) }

  TestCase {
    name: "WorkspaceGrid"
    when: windowShown

    function init() {
      grid.workspaces = root.sample(false)
      activated.clear()
    }

    function test_one_tile_per_regular_workspace_and_no_scratchpad_while_hidden() {
      tryCompare(grid, "columns", 2)
      compare(root.tiles().length, 2)
      compare(root.tiles()[0].label, "1")
    }

    function test_scratchpad_tile_comes_down_on_top_unlabelled_and_goes_again() {
      grid.workspaces = root.sample(true)
      tryCompare(root.tiles(), "length", 3)
      var top = root.tiles().filter(function(t) { return t.workspace.special })[0]
      compare(top.label, "")
      // Let the Column and Flows place the new tile before comparing positions.
      waitForItemPolished(grid)
      wait(0)
      verify(top.mapToItem(grid, 0, 0).y < root.tiles().filter(function(t) { return !t.workspace.special })[0].mapToItem(grid, 0, 0).y)
      grid.workspaces = root.sample(false)
      tryCompare(root.tiles(), "length", 2)
    }

    function test_no_scratchpad_text_anywhere() {
      grid.workspaces = root.sample(true)
      var texts = root.findAll(grid, function(i) { return i.text !== undefined && /scratch/i.test(String(i.text)) && i.visible })
      compare(texts.length, 0)
    }

    function test_clicking_a_window_activates_it() {
      var tile = root.tiles()[0]
      // Fresh delegates from init(); let the Flow place them before clicking.
      waitForItemPolished(tile.parent)
      wait(0)
      // Right half of workspace 1's screen holds window 0x2.
      mouseClick(tile.screen, tile.screen.width * 0.75, tile.screen.height / 2)
      compare(activated.count, 1)
      compare(activated.signalArguments[0][0].address, "0x2")
    }

    function test_rows_and_scratchpad_are_centered() {
      grid.workspaces = root.sample(true)
      waitForItemPolished(grid)
      wait(0)
      var all = root.tiles()
      var top = all.filter(function(t) { return t.workspace.special })[0]
      var rowTiles = all.filter(function(t) { return !t.workspace.special })
      var mid = function(t) { return t.mapToItem(grid, 0, 0).x + t.width / 2 }
      fuzzyCompare(mid(top), grid.width / 2, 1)
      // The two numbered tiles share one row centered as a pair.
      var left = rowTiles[0].mapToItem(grid, 0, 0).x
      var right = rowTiles[1].mapToItem(grid, 0, 0).x + rowTiles[1].width
      fuzzyCompare((left + right) / 2, grid.width / 2, 1)
    }

    function test_tiles_fill_but_never_exceed_the_space() {
      compare(grid.columns, 2)
      verify(grid.tileWidth <= 300)
      verify(grid.implicitHeight <= 500)
    }

    function test_scratchpad_is_just_its_window_at_its_size() {
      grid.workspaces = root.sample(true)
      waitForItemPolished(grid)
      var top = root.tiles().filter(function(t) { return t.workspace.special })[0]
      verify(top.bare)
      compare(top.screen.border.width, 0)
      // Cropped to its one window, and as wide as that window is at the tiles' scale.
      compare(top.workspace.windows[0].rect.w, 1)
      fuzzyCompare(top.width, grid.scratchpadTileWidth * top.workspace.extent.w, 1)
    }

    function test_text_is_plain() {
      var texts = root.findAll(grid, function(i) { return i.textFormat !== undefined })
      verify(texts.length > 0)
      for (let i = 0; i < texts.length; i++) compare(texts[i].textFormat, Text.PlainText)
    }

    function test_empty_message_when_nothing_is_open() {
      grid.workspaces = []
      var empty = root.findAll(grid, function(i) { return i.text === "No open windows" })[0]
      verify(empty.visible)
    }
  }
}
