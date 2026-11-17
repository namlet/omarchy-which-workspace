const { test } = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

const win = (address, appId, title) => ({ address, appId, title })

test("only occupied workspaces are listed, by number, specials last", () => {
  const result = Model.occupiedWorkspaces([
    { id: 3, name: "3", windows: [win("0xa", "firefox", "Docs")] },
    { id: 1, name: "1", windows: [] },
    { id: -98, name: "special:scratch", windows: [win("0xb", "kitty", "notes")] },
    { id: 2, name: "2", windows: [win("0xc", "Alacritty", "~")] }
  ])
  assert.deepEqual(result.map((ws) => ws.id), [2, 3, -98])
})

test("addresses are normalized to 0x form and anything else is dropped", () => {
  assert.equal(Model.normalizeAddress("55D1ab"), "0x55d1ab")
  assert.equal(Model.normalizeAddress("0x55d1ab"), "0x55d1ab")
  assert.equal(Model.normalizeAddress('0x1" }) os.execute("rm'), "")
  assert.equal(Model.normalizeAddress(""), "")
  assert.equal(Model.normalizeAddress(undefined), "")
})

test("a workspace whose only windows have bad addresses is not occupied", () => {
  const result = Model.occupiedWorkspaces([{ id: 4, name: "4", windows: [win("not-hex", "x", "y")] }])
  assert.deepEqual(result, [])
})

test("the focus expression targets the window by address", () => {
  assert.equal(Model.focusExpression("abc"), 'hl.dsp.focus({ window = "address:0xabc" })')
  assert.equal(Model.focusExpression("zzz"), "")
})

test("untrusted text is collapsed and bounded", () => {
  assert.equal(Model.cleanText("  a\n\tb  "), "a b")
  const long = Model.cleanText("x".repeat(500))
  assert.equal(long.length, Model.MAX_TEXT)
  assert.ok(long.endsWith("…"))
})

test("markup-shaped titles pass through as plain text, never interpreted here", () => {
  const [ws] = Model.occupiedWorkspaces([
    { id: 1, name: "1", windows: [win("0x1", "", '<img src="https://example.invalid/t">')] }
  ])
  assert.equal(Model.windowLabel(ws.windows[0]), '<img src="https://example.invalid/t">')
})

test("labels match the bar: per-monitor slots 1-9 then 0, monitor only when needed", () => {
  assert.equal(Model.workspaceLabel({ id: 1, name: "1", special: false }), "1")
  assert.equal(Model.workspaceLabel({ id: 10, name: "10", special: false }), "0")
  assert.equal(Model.workspaceLabel({ id: 13, name: "13", special: false }), "3")
  assert.equal(Model.workspaceLabel({ id: 13, name: "13", special: false, monitorName: "DP-1" }, true), "3 · DP-1")
  assert.equal(Model.workspaceLabel({ id: -98, name: "special:scratch", special: true }), "scratch")
  assert.equal(Model.spansMonitors([{ monitorName: "A" }, { monitorName: "A" }]), false)
  assert.equal(Model.spansMonitors([{ monitorName: "A" }, { monitorName: "B" }]), true)
})

test("app id preferred over title for a window's name", () => {
  assert.equal(Model.windowLabel({ appId: "firefox", title: "Docs" }), "firefox")
  assert.equal(Model.windowLabel({ appId: "", title: "Docs" }), "Docs")
})

test("cursor starts at an end and stops at the edges", () => {
  assert.equal(Model.moveCursor(-1, 1, 3), 0)
  assert.equal(Model.moveCursor(-1, -1, 3), 2)
  assert.equal(Model.moveCursor(2, 1, 3), 2)
  assert.equal(Model.moveCursor(0, -1, 3), 0)
  assert.equal(Model.moveCursor(0, 1, 0), -1)
})

test("flat window order follows workspace order", () => {
  const list = Model.occupiedWorkspaces([
    { id: 2, name: "2", windows: [win("0x2", "b", "")] },
    { id: 1, name: "1", windows: [win("0x1", "a", ""), win("0x3", "c", "")] }
  ])
  assert.deepEqual(Model.flatWindows(list).map((w) => w.address), ["0x1", "0x3", "0x2"])
})

const monitor = { name: "HDMI-A-1", x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 }
const placed = (address, at, size, floating) => ({ address, appId: "a", title: "", at, size, floating })

test("windows are placed as fractions of their monitor", () => {
  const [ws] = Model.occupiedWorkspaces([{ id: 1, name: "1", monitor, windows: [
    placed("0x1", [0, 0], [960, 1080]), placed("0x2", [960, 540], [960, 540]) ] }])
  assert.deepEqual(ws.windows[0].rect, { x: 0, y: 0, w: 0.5, h: 1 })
  assert.deepEqual(ws.windows[1].rect, { x: 0.5, y: 0.5, w: 0.5, h: 0.5 })
  assert.equal(ws.aspect, 16 / 9)
})

test("geometry respects monitor offset, scale and rotation", () => {
  const right = { name: "DP-1", x: 1920, y: 0, width: 2560, height: 1440, scale: 2, transform: 1 }
  assert.deepEqual(Model.logicalSize(right), { x: 1920, y: 0, w: 720, h: 1280 })
  const [rect] = Model.layoutWindows([placed("0x1", [1920, 640], [720, 640])], right)
  assert.deepEqual(rect, { x: 0, y: 0.5, w: 1, h: 0.5 })
})

test("windows hanging off the monitor are clipped to the tile", () => {
  const [rect] = Model.layoutWindows([placed("0x1", [-480, 0], [960, 1080])], monitor)
  assert.deepEqual(rect, { x: 0, y: 0, w: 0.25, h: 1 })
})

test("without usable geometry, windows share the tile side by side", () => {
  const rects = Model.layoutWindows([placed("0x1", undefined, undefined), placed("0x2", [0, 0], [10, 10])], monitor)
  assert.deepEqual(rects, [{ x: 0, y: 0, w: 0.5, h: 1 }, { x: 0.5, y: 0, w: 0.5, h: 1 }])
  assert.deepEqual(Model.layoutWindows([placed("0x1", [0, 0], [10, 10])], null), [{ x: 0, y: 0, w: 1, h: 1 }])
})

test("floating windows are drawn last, on top", () => {
  const [ws] = Model.occupiedWorkspaces([{ id: 1, name: "1", monitor, windows: [
    placed("0x1", [500, 300], [400, 300], true), placed("0x2", [0, 0], [1920, 1080]) ] }])
  assert.deepEqual(ws.windows.map((w) => w.address), ["0x2", "0x1"])
})

test("specials split from regular workspaces, and only shown ones count; window count", () => {
  const list = Model.occupiedWorkspaces([
    { id: -98, name: "special:s", shown: true, monitor, windows: [placed("0x9", [0, 0], [10, 10])] },
    { id: -97, name: "special:hidden", shown: false, monitor, windows: [placed("0x8", [0, 0], [10, 10])] },
    { id: 2, name: "2", shown: true, monitor, windows: [placed("0x1", [0, 0], [10, 10]), placed("0x2", [0, 0], [10, 10])] }
  ])
  assert.deepEqual(Model.regular(list).map((w) => w.id), [2])
  assert.deepEqual(Model.shownSpecial(list).map((w) => w.id), [-98])
  assert.equal(list.find((w) => w.id === 2).shown, false, "only special workspaces are shown or hidden")
  assert.equal(Model.windowCount(list), 4)
})

test("windows know whether they are on a special workspace", () => {
  const list = Model.occupiedWorkspaces([
    { id: -98, name: "special:s", monitor, windows: [placed("0x9", [0, 0], [10, 10])] },
    { id: 1, name: "1", monitor, windows: [placed("0x1", [0, 0], [10, 10])] }
  ])
  assert.deepEqual(Model.flatWindows(list).map((w) => w.special), [false, true])
})

test("the live toplevel reference passes through untouched", () => {
  const ref = { any: "object" }
  const [ws] = Model.occupiedWorkspaces([{ id: 1, name: "1", monitor, windows: [{ address: "0x1", ref }] }])
  assert.equal(ws.windows[0].ref, ref)
})

test("tiles: four workspaces spread across one row", () => {
  // 1800 wide: 4 x 436 fits one row, above the 260 minimum.
  assert.deepEqual(Model.fitTiles(4, 1800, 900, 18, 16 / 9, 20, 480, 260), { columns: 4, tileWidth: 436 })
  // One workspace never grows past the cap.
  assert.deepEqual(Model.fitTiles(1, 1800, 900, 18, 16 / 9, 20, 480, 260), { columns: 1, tileWidth: 480 })
})

test("tiles: a second row only once one row would drop below the minimum", () => {
  // 9 in one row of 1800 would be ~184 wide; 6 per row (2 rows) is the first at >= 260.
  const fit = Model.fitTiles(9, 1800, 900, 18, 16 / 9, 20, 480, 260)
  assert.equal(fit.columns, 6)
  assert.ok(fit.tileWidth >= 260)
  // Never taller than the space: rows * (caption + screen) + gaps <= height.
  const rows = Math.ceil(9 / fit.columns)
  assert.ok(rows * (20 + fit.tileWidth / (16 / 9)) + (rows - 1) * 18 <= 900)
})

test("tiles: when nothing reaches the minimum, the biggest layout wins", () => {
  // A small space: no layout reaches 260, so the largest tiles are used.
  const fit = Model.fitTiles(6, 600, 400, 10, 16 / 9, 20, 480, 260)
  for (let c = 1; c <= 6; c++) {
    const rows = Math.ceil(6 / c)
    const w = Math.floor(Math.min((600 - (c - 1) * 10) / c, ((400 - (rows - 1) * 10) / rows - 20) * 16 / 9, 480))
    assert.ok(fit.tileWidth >= w)
  }
})

test("tiles: degenerate input stays sane", () => {
  assert.deepEqual(Model.fitTiles(0, 1800, 900, 18, 16 / 9, 20, 480, 260), { columns: 1, tileWidth: 480 })
  assert.deepEqual(Model.fitTiles(3, 0, 900, 18, 16 / 9, 20, 480, 260), { columns: 1, tileWidth: 0 })
})

test("rows are chunked in order", () => {
  assert.deepEqual(Model.chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]])
  assert.deepEqual(Model.chunk([], 3), [])
})

test("the scratchpad crops to its windows: shape, extent and rects inside the box", () => {
  const [ws] = Model.occupiedWorkspaces([{ id: -98, name: "special:s", shown: true, monitor, windows: [
    placed("0x1", [480, 270], [960, 540], true) ] }])
  const cropped = Model.windowBounds(ws)
  assert.deepEqual(cropped.extent, { w: 0.5, h: 0.5 })
  assert.equal(cropped.aspect, 16 / 9)
  assert.deepEqual(cropped.windows[0].rect, { x: 0, y: 0, w: 1, h: 1 })
  // The original is left alone.
  assert.deepEqual(ws.windows[0].rect, { x: 0.25, y: 0.25, w: 0.5, h: 0.5 })
})

test("two scratchpad windows share one box in their real arrangement", () => {
  const [ws] = Model.occupiedWorkspaces([{ id: -98, name: "special:s", shown: true, monitor, windows: [
    placed("0x1", [0, 0], [960, 540], true), placed("0x2", [960, 540], [960, 540], true) ] }])
  const cropped = Model.windowBounds(ws)
  assert.deepEqual(cropped.extent, { w: 1, h: 1 })
  assert.deepEqual(cropped.windows.map((w) => w.rect), [{ x: 0, y: 0, w: 0.5, h: 0.5 }, { x: 0.5, y: 0.5, w: 0.5, h: 0.5 }])
})

const monitors = [{ id: 0, width: 1920, height: 1080 }, { id: 1, width: 2560, height: 1440, disabled: false }]

test("capture only a mapped window on a present, enabled monitor", () => {
  assert.equal(Model.canCapture(0, true, monitors), true)
  assert.equal(Model.canCapture(1, true, monitors), true)
  assert.equal(Model.canCapture("0", true, monitors), true)
})

test("never capture a window with no monitor: that crashes Hyprland 0.56.2", () => {
  assert.equal(Model.canCapture(-1, true, monitors), false)
  assert.equal(Model.canCapture(undefined, true, monitors), false)
  assert.equal(Model.canCapture(null, true, monitors), false)
  assert.equal(Model.canCapture("", true, monitors), false)
  assert.equal(Model.canCapture(1.5, true, monitors), false)
  assert.equal(Model.canCapture("0; rm", true, monitors), false)
})

test("never capture on a monitor that is gone, disabled or has no size", () => {
  assert.equal(Model.canCapture(2, true, monitors), false)
  assert.equal(Model.canCapture(0, true, []), false)
  assert.equal(Model.canCapture(0, true, undefined), false)
  assert.equal(Model.canCapture(0, true, [{ id: 0, width: 1920, height: 1080, disabled: true }]), false)
  assert.equal(Model.canCapture(0, true, [{ id: 0, width: 0, height: 0 }]), false)
  assert.equal(Model.canCapture(0, true, [{ id: 0 }]), false)
})

test("never capture an unmapped window, or one whose state is unknown", () => {
  assert.equal(Model.canCapture(0, false, monitors), false)
  assert.equal(Model.canCapture(0, undefined, monitors), false)
})

test("windows carry capturable from their monitor; no monitor list means none", () => {
  const ws = (monitorId, mapped) => [{ id: 1, name: "1", windows: [Object.assign(win("0xa", "foot", "~"), { monitorId, mapped })] }]
  assert.equal(Model.occupiedWorkspaces(ws(0, true), monitors)[0].windows[0].capturable, true)
  assert.equal(Model.occupiedWorkspaces(ws(-1, true), monitors)[0].windows[0].capturable, false)
  assert.equal(Model.occupiedWorkspaces(ws(0, true))[0].windows[0].capturable, false)
})

test("the scratchpad crop keeps each window's capturable flag", () => {
  const wsList = Model.occupiedWorkspaces([{ id: -98, name: "special:scratchpad", shown: true,
    monitor: { name: "M", x: 0, y: 0, width: 1920, height: 1080, scale: 1 },
    windows: [Object.assign(win("0xa", "foot", "~"), { at: [12, 12], size: [1896, 356], monitorId: 0, mapped: true }),
      Object.assign(win("0xb", "foot", "~"), { at: [12, 400], size: [600, 300], monitorId: -1, mapped: true })] }], monitors)
  const cropped = Model.windowBounds(wsList[0])
  assert.deepEqual(cropped.windows.map((w) => w.capturable), [true, false])
})
