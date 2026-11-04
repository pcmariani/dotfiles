-- Split-size keys: grow or shrink the FOCUSED window through a fixed ladder of
-- shares of its row, using AeroSpace's ABSOLUTE resize (`resize width <px>`).
--
--   cmd-ctrl-alt-]  grow   25 -> 33 -> 50 -> 66 -> 75
--   cmd-ctrl-alt-[  shrink 75 -> 66 -> 50 -> 33 -> 25
--
-- Why this shape (2026-09-30):
--
-- * The first attempt positioned windows itself with hs.window:setFrame().
--   AeroSpace owns tiled geometry and fights it, and iterating every window
--   hung the machine. This never sets a frame. It asks AeroSpace for a width
--   and lets the tiling tree redistribute the rest.
--
-- * The second attempt bound `aerospace resize width +100`, calling
--   `aerospace` by bare name. Hammerspoon's PATH is only /usr/bin:/bin:
--   /usr/sbin:/sbin, so the shell answered exit 127 "command not found" and
--   the keys LOOKED dead while actually firing. Every command here uses an
--   absolute path, and every failure path shows an alert, because a silent
--   no-op is the expensive failure, not the noisy one.
--
-- * AeroSpace's `resize width <n>` with a bare number is absolute. The
--   earlier handoff claimed it was only relative; measured false on
--   2026-09-30 (asked 952, got 950).
--
-- * Stateless. The next step is computed from the focused window's ACTUAL
--   share of its row, so resizing by any other means never desyncs it. The
--   earlier cycleSplitSize kept a state file that could not know.
--
-- * The preset is a share of the row's span (leftmost edge to rightmost
--   edge), so it is the same arithmetic for two windows or three. With three
--   or more, the others share whatever remains. A window's own minimum width
--   can stop the resize short (Chrome stopped at 626px on the built-in
--   screen), so the alert reports the share actually reached, not the one
--   asked for.
--
-- The stepping and pixel math are pure and take no `hs` dependency at load
-- time, so smoke-splitsize.sh can test them under a plain Lua interpreter.

local M = {}

M.PRESETS = { 25, 33, 50, 66, 75 }

-- Percentage points. A window within this of a preset counts as AT it, so a
-- resize that lands 1-2% short (gaps, rounding) does not make the next press
-- re-request the same preset.
M.TOLERANCE = 2

M.AEROSPACE = "/opt/homebrew/bin/aerospace"

-- Pure. `currentPct` is the focused window's share of its row in percent.
-- `direction` is +1 to grow, -1 to shrink. Returns the next preset on the
-- ladder, or nil when already at (or past) the end.
function M.nextPreset(currentPct, direction)
  if direction > 0 then
    for _, p in ipairs(M.PRESETS) do
      if p > currentPct + M.TOLERANCE then
        return p
      end
    end
  else
    for i = #M.PRESETS, 1, -1 do
      local p = M.PRESETS[i]
      if p < currentPct - M.TOLERANCE then
        return p
      end
    end
  end
  return nil
end

-- Pure. Nearest whole pixel.
function M.targetWidth(pct, span)
  return math.floor(span * pct / 100 + 0.5)
end

-- Pure (cbm-055, a startup `window` step). `row` is { {id=, x=, w=}, ... }
-- (as readRow builds it), `id` a window id string, `pct` a share from 1 to 99.
-- Returns the pixel width that makes that window `pct` percent of the row's
-- span (leftmost edge to rightmost edge, so it is the same arithmetic for two
-- windows or three) and the span; nil when there is nothing to split (fewer
-- than two windows), the window is not in the row, or `pct` is not a share.
function M.rowTarget(row, id, pct)
  if type(pct) ~= "number" or pct < 1 or pct > 99 then
    return nil
  end
  if #row < 2 then
    return nil
  end
  local left, right, found = math.huge, -math.huge, false
  for _, win in ipairs(row) do
    left = math.min(left, win.x)
    right = math.max(right, win.x + win.w)
    if win.id == id then
      found = true
    end
  end
  if not found then
    return nil
  end
  local span = right - left
  return M.targetWidth(pct, span), span
end

-- ---------------------------------------------------------------------------
-- Everything below needs Hammerspoon.
-- ---------------------------------------------------------------------------

local function say(msg)
  hs.alert.show(msg, 1.0)
end

-- Runs `aerospace <args>` through the shell with the absolute path.
-- Returns ok, combinedOutput.
local function aerospace(args)
  local out, ok = hs.execute(M.AEROSPACE .. " " .. args .. " 2>&1")
  return ok, out or ""
end

-- Tiled-row windows of the focused workspace, as { {id=, x=, w=}, ... }, and
-- the focused window's id. Returns nil plus a message on any problem.
local function readRow()
  local ok, focused = aerospace("list-windows --focused --format '%{window-id}'")
  focused = focused:gsub("%s+$", "")
  if not ok or focused == "" then
    return nil, "split: no focused window (" .. focused .. ")"
  end

  local listOk, listing = aerospace(
    "list-windows --workspace focused --format '%{window-id}|%{window-layout}'")
  if not listOk then
    return nil, "split: aerospace failed: " .. listing:gsub("%s+$", "")
  end

  local row, focusedInRow = {}, false
  for id, layout in listing:gmatch("(%d+)|([^\n]+)") do
    if layout == "h_tiles" then
      local win = hs.window(tonumber(id))
      if win then
        local f = win:frame()
        row[#row + 1] = { id = id, x = f.x, w = f.w }
        if id == focused then
          focusedInRow = true
        end
      end
    end
  end

  if not focusedInRow then
    -- Accordion, floating, vertical tiles, or a hidden-app window. Resize
    -- would be refused or meaningless, so say why instead of doing nothing.
    return nil, "split: focused window is not in a horizontal tiled row"
  end
  if #row < 2 then
    return nil, "split: nothing to split, only one tiled window"
  end

  return row, focused
end

local function share(row, focusedId)
  local left, right, focusedW = math.huge, -math.huge, nil
  for _, win in ipairs(row) do
    left = math.min(left, win.x)
    right = math.max(right, win.x + win.w)
    if win.id == focusedId then
      focusedW = win.w
    end
  end
  local span = right - left
  return focusedW / span * 100, span
end

-- direction: +1 grow the focused window, -1 shrink it. Returns ok, sharePct.
function M.step(direction)
  local row, focusedId = readRow()
  if not row then
    say(focusedId) -- on failure the second value is the message
    return false
  end

  local currentPct, span = share(row, focusedId)
  local preset = M.nextPreset(currentPct, direction)
  if not preset then
    say(string.format("split: already at %d%%", math.floor(currentPct + 0.5)))
    return false
  end

  local target = M.targetWidth(preset, span)
  local ok, out = aerospace(string.format(
    "resize width %d --window-id %s", target, focusedId))
  if not ok then
    say("split: resize failed: " .. out:gsub("%s+$", ""))
    return false
  end

  -- AeroSpace applies the new width asynchronously; read the real result
  -- back rather than trusting the request.
  hs.timer.usleep(200000)
  local after, afterFocused = readRow()
  if not after then
    say(afterFocused)
    return false
  end
  local reached = share(after, afterFocused)
  local reachedRounded = math.floor(reached + 0.5)

  if math.abs(reached - preset) > 3 then
    say(string.format("split: %d%% (wanted %d%%, window minimum width)", reachedRounded, preset))
  else
    say(string.format("split: %d%%", reachedRounded))
  end
  return true, reached
end

-- A startup `window` step (cbm-055, run by `context startup` through
-- `hs -c 'return require("splitsize").setWidth(<id>, <pct>)'`): make window
-- `windowId` take `pct` percent of its row. Unlike `step` it works on ANY
-- window by id, not the focused one, finds that window's workspace itself (so
-- no workspace name is ever put into Lua by the caller), and is SILENT: no
-- alerts, because nobody pressed a key. Never sets a frame. Returns the share
-- of the row actually reached, in percent, or nil plus a message.
--
-- The window's workspace must be on screen: a hidden workspace's windows report
-- a parked frame, so the span would be nonsense.
function M.setWidth(windowId, pct)
  if type(windowId) ~= "number" or windowId ~= math.floor(windowId) or windowId < 0 then
    return nil, "setWidth: the window id must be a whole number"
  end
  if type(pct) ~= "number" or pct < 1 or pct > 99 then
    return nil, "setWidth: the share must be from 1 to 99"
  end
  local id = string.format("%d", windowId)

  local listOk, listing = aerospace(
    "list-windows --all --format '%{window-id}|%{workspace}|%{window-layout}'")
  if not listOk then
    return nil, "setWidth: aerospace failed: " .. listing:gsub("%s+$", "")
  end
  local windows, workspace, layout = {}, nil, nil
  for wid, ws, lay in listing:gmatch("(%d+)|([^|\n]+)|([^\n]+)") do
    windows[#windows + 1] = { id = wid, ws = ws, layout = lay }
    if wid == id then
      workspace, layout = ws, lay
    end
  end
  if not workspace then
    return nil, "setWidth: window " .. id .. " not found"
  end
  if layout ~= "h_tiles" then
    return nil, "setWidth: window " .. id .. " is not in a horizontal tiled row (" .. layout .. ")"
  end

  local visOk, visible = aerospace("list-workspaces --monitor all --visible --format '%{workspace}'")
  local onScreen = false
  if visOk then
    for name in visible:gmatch("[^\n]+") do
      if name == workspace then
        onScreen = true
      end
    end
  end
  if not onScreen then
    return nil, "setWidth: workspace " .. workspace .. " is not on screen"
  end

  local function readFrames()
    local row = {}
    for _, w in ipairs(windows) do
      if w.ws == workspace and w.layout == "h_tiles" then
        local win = hs.window(tonumber(w.id))
        if win then
          local f = win:frame()
          row[#row + 1] = { id = w.id, x = f.x, w = f.w }
        end
      end
    end
    return row
  end

  local target = M.rowTarget(readFrames(), id, pct)
  if not target then
    return nil, "setWidth: nothing to split, or the window has no frame"
  end
  local ok, out = aerospace(string.format("resize width %d --window-id %s", target, id))
  if not ok then
    return nil, "setWidth: resize failed: " .. out:gsub("%s+$", "")
  end

  -- AeroSpace applies the width asynchronously; read the real result back.
  hs.timer.usleep(200000)
  local after = readFrames()
  for _, win in ipairs(after) do
    if win.id == id then
      return (share(after, id))
    end
  end
  return nil, "setWidth: the window vanished after the resize"
end

return M
