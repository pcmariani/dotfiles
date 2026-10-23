-- Three-finger swipe up brings up the unified picker: `paneld toggle search`,
-- the same call the space-e Karabiner rule makes. Swipe down closes it: an
-- Escape keystroke, sent only while `paneld status` says the search panel is
-- visible. Not `paneld hide`: show/hide against the live daemon can strand a
-- surface, and Escape is the path a keypress takes (fzf aborts, paneld re-arms).
--
-- Why this shape (2026-10-23, measured with a throwaway logger):
--
-- * macOS gives three-finger vertical swipes to Mission Control / App Expose.
--   They have to be moved to four fingers (System Settings > Trackpad > More
--   Gestures) or the system takes the swipe before anything here matters. The
--   `TrackpadThreeFingerVertSwipeGesture` default reads 0 once that is done.
--
-- * Gesture events carry the raw touches. A touch has a normalizedPosition
--   (0..1, origin bottom-left, so UP is +y), a phase and `touching`. Real
--   swipes up measured dy +0.32 to +0.56 over 150-420 ms with dx within 0.03;
--   sideways swipes dx +-0.35 with dy near 0; two-finger scrolls never reach
--   three touches.
--
-- * Fire once the travel passes THRESHOLD_UP, mid-swipe, not at finger lift
--   (saves ~200 ms). One fire per three-finger touch sequence, plus COOLDOWN,
--   because a ragged lift reports 3 -> 2 -> 3 fingers within a few ms.
--
-- * Absolute path to paneld and a visible alert on a non-zero exit:
--   Hammerspoon's PATH has no Homebrew, so a bare command fails silently.

local M = {}

M.PANELD = os.getenv("HOME") .. "/Applications/paneld.app/Contents/MacOS/paneld"
M.THRESHOLD_UP = 0.20    -- fraction of the trackpad's height, up or down
M.MAX_SIDE = 0.15        -- sideways drift allowed during the travel
M.COOLDOWN = 0.6         -- seconds between two fires

local track, lastFire = nil, 0

local function get(t, k)
  local ok, v = pcall(function()
    local x = t[k]
    if type(x) == "function" then return x(t) end
    return x
  end)
  return ok and v or nil
end

local function centroid(touches)
  local sx, sy = 0, 0
  for _, t in ipairs(touches) do
    local p = get(t, "normalizedPosition")
    sx, sy = sx + p.x, sy + p.y
  end
  return sx / #touches, sy / #touches
end

local function fire()
  hs.task.new(M.PANELD, function(code, _, err)
    if code ~= 0 then
      hs.alert.show("swipe: paneld toggle search exited " .. tostring(code) .. " " .. tostring(err), 3)
    end
  end, { "toggle", "search" }):start()
end

-- Close the picker the way Esc does, but only when it is actually showing, so a
-- swipe down in any other app never sends it a stray Escape.
local function closeIfVisible()
  hs.task.new(M.PANELD, function(code, out)
    if code ~= 0 then
      hs.alert.show("swipe: paneld status exited " .. tostring(code), 3)
      return
    end
    local block = tostring(out):match("panel%s+search\n(.-)\n\n") or tostring(out):match("panel%s+search\n(.*)")
    local state = block and block:match("state%s+([^\n]+)")
    if state and state:find("visible", 1, true) and not state:find("hidden", 1, true) then
      hs.eventtap.keyStroke({}, "escape", 0)
    end
  end, { "status" }):start()
end

local function onGesture(e)
  local touching = {}
  for _, t in ipairs(e:getTouches() or {}) do
    local phase = get(t, "phase")
    if get(t, "touching") and phase ~= "ended" and phase ~= "cancelled" then
      touching[#touching + 1] = t
    end
  end
  if #touching == 3 then
    local x, y = centroid(touching)
    if not track then track = { x0 = x, y0 = y, fired = false } end
    local dy = y - track.y0
    if not track.fired and math.abs(dy) >= M.THRESHOLD_UP
        and math.abs(x - track.x0) <= M.MAX_SIDE then
      track.fired = true
      local now = hs.timer.secondsSinceEpoch()
      if now - lastFire >= M.COOLDOWN then
        lastFire = now
        if dy > 0 then fire() else closeIfVisible() end
      end
    end
  else
    track = nil
  end
  return false
end

-- The tap lives in a global, not in M: a module reloaded in place gets a fresh
-- M, and a tap held only by the old one could never be stopped, so one swipe
-- would toggle the picker once per leftover tap (open, then closed again).
function M.stop()
  if _G.__swipeTap then _G.__swipeTap:stop(); _G.__swipeTap = nil end
  track = nil
end

function M.start()
  M.stop()
  _G.__swipeTap = hs.eventtap.new({ hs.eventtap.event.types.gesture }, onGesture)
  _G.__swipeTap:start()
end

return M
