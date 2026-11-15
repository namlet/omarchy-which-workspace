// Pure logic for the workspace switcher: no QML, no Quickshell, so Node can test it.
// BarWidget.qml turns Hyprland's live objects into the plain shapes taken here.

const MAX_TEXT = 120
// Hyprland numbers workspaces in a block of ten per monitor (1-10, 11-20, ...), and
// the bar shows each by its place in its block. See omarchy.workspaces.
const SLOTS = 10

// Window titles and classes come from whatever app opened the window: treat them as
// untrusted. Collapse whitespace and bound the length before anything displays them.
function cleanText(value) {
  const text = String(value === undefined || value === null ? "" : value).replace(/\s+/g, " ").trim()
  return text.length > MAX_TEXT ? text.slice(0, MAX_TEXT - 1) + "…" : text
}

// Hyprland addresses arrive as "0x55d1…" from IPC and as bare hex from Quickshell's
// events. Anything else is refused, so no other text ever reaches a dispatch.
function normalizeAddress(address) {
  const text = String(address || "").trim().toLowerCase()
  const hex = text.indexOf("0x") === 0 ? text.slice(2) : text
  return /^[0-9a-f]{1,16}$/.test(hex) ? "0x" + hex : ""
}

// Focusing a window by address also switches to its workspace (and monitor).
function focusExpression(address) {
  const normalized = normalizeAddress(address)
  return normalized ? 'hl.dsp.focus({ window = "address:' + normalized + '" })' : ""
}

function finite(value) {
  const n = Number(value)
  return isFinite(n) ? n : NaN
}

// The monitor's size in the logical coordinates window geometry uses: pixels over
// scale, with width and height swapped when it is rotated a quarter turn.
function logicalSize(monitor) {
  if (!monitor) return null
  const scale = finite(monitor.scale) > 0 ? finite(monitor.scale) : 1
  let w = finite(monitor.width) / scale
  let h = finite(monitor.height) / scale
  if (finite(monitor.transform) % 2 === 1) { const t = w; w = h; h = t }
  return w > 0 && h > 0 ? { x: finite(monitor.x) || 0, y: finite(monitor.y) || 0, w: w, h: h } : null
}

function clamp01(value) {
  return Math.max(0, Math.min(1, value))
}

// Each window's place on its monitor as fractions (0-1) of the monitor, so a tile of
// any size can draw it. Without usable geometry for every window, they share the tile
// side by side instead, which is how a fresh dwindle workspace looks anyway.
function layoutWindows(windows, monitor) {
  const screen = logicalSize(monitor)
  const placed = windows.map(function(win) {
    const at = win.at || [], size = win.size || []
    if (!screen || !(finite(size[0]) > 0) || !(finite(size[1]) > 0) || !isFinite(finite(at[0])) || !isFinite(finite(at[1]))) return null
    const left = (finite(at[0]) - screen.x) / screen.w
    const top = (finite(at[1]) - screen.y) / screen.h
    const x = clamp01(left), y = clamp01(top)
    return { x: x, y: y, w: clamp01(left + finite(size[0]) / screen.w) - x, h: clamp01(top + finite(size[1]) / screen.h) - y }
  })
  const usable = placed.every(function(rect) { return rect && rect.w > 0 && rect.h > 0 })
  return windows.map(function(win, i) {
    return usable ? placed[i] : { x: i / windows.length, y: 0, w: 1 / windows.length, h: 1 }
  })
}

// workspaces: [{ id, name, monitor: { name, x, y, width, height, scale, transform },
//   shown, windows: [{ address, appId, title, at: [x, y], size: [w, h], floating, icon, ref }] }]
// `shown` says whether a special workspace is on screen right now (Hyprland hides the
// scratchpad until its hotkey brings it down). `ref` is passed through untouched (the
// live toplevel, for its thumbnail).
// Returns the occupied ones only, by number; special (scratchpad) workspaces, whose
// ids are negative, come after them by name. Floating windows are drawn last, on top.
function occupiedWorkspaces(workspaces) {
  const list = (workspaces || [])
    .map(function(ws) {
      const monitor = ws.monitor || null
      const windows = (ws.windows || [])
        .map(function(win) {
          return {
            address: normalizeAddress(win.address),
            appId: cleanText(win.appId),
            title: cleanText(win.title),
            floating: win.floating === true,
            // Whether it lives on a special (scratchpad) workspace.
            special: Number(ws.id) < 0,
            icon: String(win.icon || ""),
            at: win.at,
            size: win.size,
            ref: win.ref
          }
        })
        .filter(function(win) { return win.address !== "" })
      windows.sort(function(a, b) { return (a.floating ? 1 : 0) - (b.floating ? 1 : 0) })
      const rects = layoutWindows(windows, monitor)
      windows.forEach(function(win, i) {
        win.rect = rects[i]
        delete win.at
        delete win.size
      })
      const screen = logicalSize(monitor)
      return {
        id: Number(ws.id),
        name: cleanText(ws.name),
        special: Number(ws.id) < 0,
        shown: Number(ws.id) < 0 && ws.shown === true,
        monitorName: cleanText(monitor && monitor.name),
        aspect: screen ? screen.w / screen.h : 16 / 9,
        windows: windows
      }
    })
    .filter(function(ws) { return ws.windows.length > 0 })

  list.sort(function(a, b) {
    if (a.special !== b.special) return a.special ? 1 : -1
    if (a.special) return a.name < b.name ? -1 : a.name > b.name ? 1 : 0
    return a.id - b.id
  })
  return list
}

// A workspace cropped to just its windows: rects re-measured inside their bounding box,
// `aspect` the box's own shape, and `extent` the box as a fraction of the monitor.
// Used for the scratchpad, drawn as its windows at their size with no screen behind.
function windowBounds(ws) {
  const wins = ws.windows || []
  if (wins.length === 0) return Object.assign({}, ws, { extent: { w: 1, h: 1 } })
  const left = Math.min.apply(null, wins.map(function(w) { return w.rect.x }))
  const top = Math.min.apply(null, wins.map(function(w) { return w.rect.y }))
  const right = Math.max.apply(null, wins.map(function(w) { return w.rect.x + w.rect.w }))
  const bottom = Math.max.apply(null, wins.map(function(w) { return w.rect.y + w.rect.h }))
  const bw = Math.max(1e-6, right - left), bh = Math.max(1e-6, bottom - top)
  return Object.assign({}, ws, {
    aspect: (ws.aspect > 0 ? ws.aspect : 16 / 9) * bw / bh,
    extent: { w: bw, h: bh },
    windows: wins.map(function(w) {
      return Object.assign({}, w, { rect: { x: (w.rect.x - left) / bw, y: (w.rect.y - top) / bh, w: w.rect.w / bw, h: w.rect.h / bh } })
    })
  })
}

function regular(workspaces) {
  return workspaces.filter(function(ws) { return !ws.special })
}

// Only the special workspaces on screen: the popup shows the scratchpad while it is down.
function shownSpecial(workspaces) {
  return workspaces.filter(function(ws) { return ws.special && ws.shown })
}

// Labels match the bar: each monitor numbers its own block 1-9, then 0. The monitor's
// name is added only when the occupied workspaces sit on more than one monitor.
function slotLabel(id) {
  const slot = (id - 1) % SLOTS + 1
  return slot === SLOTS ? "0" : String(slot)
}

function spansMonitors(workspaces) {
  const names = {}
  workspaces.forEach(function(ws) { if (ws.monitorName) names[ws.monitorName] = true })
  return Object.keys(names).length > 1
}

function workspaceLabel(ws, withMonitor) {
  let label
  if (ws.special) label = ws.name.replace(/^special:/, "") || "special"
  else if (ws.id > 0) label = slotLabel(ws.id)
  else label = ws.name || String(ws.id)
  return withMonitor && ws.monitorName ? label + " · " + ws.monitorName : label
}

// A window's name for tooltips and the cursor: the app, falling back to the title.
function windowLabel(win) {
  return win.appId || win.title || "?"
}

function windowCount(workspaces) {
  return workspaces.reduce(function(n, ws) { return n + ws.windows.length }, 0)
}

// Every window in display order, for keyboard navigation over one flat list.
function flatWindows(workspaces) {
  const out = []
  workspaces.forEach(function(ws) { ws.windows.forEach(function(win) { out.push(win) }) })
  return out
}

function moveCursor(index, delta, count) {
  if (count <= 0) return -1
  if (index < 0) return delta > 0 ? 0 : count - 1
  return Math.max(0, Math.min(count - 1, index + delta))
}

// Tile size and columns for `count` workspaces in the space given, Mission Control
// style: spread out in as few rows as possible. The fewest rows whose tiles are still
// at least minTile wide win; if no layout reaches minTile, the one with the biggest
// tiles does. Each tile is a caption line plus a screen of the monitor's shape, never
// wider than maxTile and never taller in total than the space.
function fitTiles(count, width, height, spacing, aspect, captionHeight, maxTile, minTile) {
  const shape = aspect > 0 ? aspect : 16 / 9
  if (!(count > 0) || !(width > 0)) return { columns: 1, tileWidth: Math.max(0, Math.floor(Math.min(width || 0, maxTile))) }
  let biggest = { columns: 1, tileWidth: -1 }
  for (let c = count; c >= 1; c--) {
    const rows = Math.ceil(count / c)
    const byWidth = (width - (c - 1) * spacing) / c
    const byHeight = height > 0 ? ((height - (rows - 1) * spacing) / rows - captionHeight) * shape : Infinity
    const w = Math.max(0, Math.floor(Math.min(byWidth, byHeight, maxTile)))
    if (minTile > 0 && w >= minTile) return { columns: c, tileWidth: w }
    if (w > biggest.tileWidth) biggest = { columns: c, tileWidth: w }
  }
  return biggest
}

// Split a list into rows of `size`, so each row can be centered on its own.
function chunk(list, size) {
  const rows = []
  for (let i = 0; i < list.length; i += Math.max(1, size)) rows.push(list.slice(i, i + Math.max(1, size)))
  return rows
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_TEXT, SLOTS, cleanText, normalizeAddress, focusExpression, logicalSize, layoutWindows,
    occupiedWorkspaces, windowBounds, regular, shownSpecial, slotLabel, spansMonitors, workspaceLabel,
    windowLabel, windowCount, flatWindows, moveCursor, fitTiles, chunk
  }
}
