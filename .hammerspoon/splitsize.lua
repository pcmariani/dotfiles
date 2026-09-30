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

return M
