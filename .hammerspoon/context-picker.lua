-- Resident context picker.
--
-- Drawing the picker inside Hammerspoon costs ~33ms against ~280ms for
-- launching choose, because this process has already paid for AppKit. A
-- do-nothing Swift NSPanel measured 160-197ms to appear, so the saving is not
-- choose's to give back — it comes entirely from not launching anything.

local M = {}

local CONTEXT_BIN = "/Users/petermariani/projects/context-based-mac/bin/context"
local REFRESH_SECONDS = 60
local FALLBACK_WIDTH_PX = 900
local FALLBACK_ROWS = 12

-- Kept identical to STATE_MARKERS in context/format.py.
local MARKERS = { running = "●", current = "○", idle = " " }

local cache = { rows = {}, picker = {}, generated = 0 }
local chooser = nil
local timer = nil

local function pickerOpt(key, fallback)
  local v = cache.picker and cache.picker[key]
  if v == nil then return fallback end
  return v
end

-- Two-line rows: marker + org + name on top, path underneath. Padding is
-- computed here rather than in Python because only this side knows the font is
-- monospaced and what the column widths should be.
local function choicesFrom(rows)
  local orgw, namew = 0, 0
  for _, r in ipairs(rows) do
    orgw = math.max(orgw, #(r.org or ""))
    namew = math.max(namew, #(r.name or ""))
  end
  local out = {}
  for i, r in ipairs(rows) do
    out[i] = {
      text = string.format("%s  %-" .. orgw .. "s  %-" .. namew .. "s",
                           MARKERS[r.state] or " ", r.org or "", r.name or ""),
      subText = r.path or "",
      name = r.name,
    }
  end
  return out
end

-- What the rows would render as. Compared before touching the chooser so an
-- unchanged refresh is a no-op.
local function signature(rows)
  local parts = {}
  for i, r in ipairs(rows) do
    parts[i] = (r.name or "") .. "\0" .. (r.state or "") .. "\0" .. (r.org or "")
              .. "\0" .. (r.path or "")
  end
  return table.concat(parts, "\1")
end

local applied = nil

-- Setting :choices() invalidates the chooser's table view, so the NEXT show()
-- has to rebuild every row. Refreshing after each show therefore made the
-- following open expensive. Most refreshes return identical rows — the
-- contexts and their states have not moved — so skip the update unless
-- something actually changed.
local function applyChoices()
  if not chooser then return end
  local sig = signature(cache.rows)
  if sig == applied then return end
  chooser:choices(choicesFrom(cache.rows))
  applied = sig
end

-- Refresh the cache from `context pick --emit`, asynchronously.
-- On failure the previous cache is kept: a stale picker beats an empty one.
function M.refresh(callback)
  local task = hs.task.new(CONTEXT_BIN, function(code, stdout, stderr)
    if code == 0 then
      local ok, data = pcall(hs.json.decode, stdout)
      if ok and type(data) == "table" and type(data.rows) == "table" then
        cache = data
        applyChoices()
      else
        print("context-picker: could not parse --emit output")
      end
    else
      print("context-picker: refresh failed (" .. tostring(code) .. "): "
            .. tostring(stderr))
    end
    if callback then callback() end
  end, { "pick", "--emit" })
  task:start()
end

local function enter(name)
  hs.task.new(CONTEXT_BIN, function(code, _, stderr)
    if code ~= 0 then
      print("context-picker: enter " .. name .. " failed: " .. tostring(stderr))
    end
    -- Entering changes which context is running and which is current, and both
    -- drive the ordering, so refresh rather than wait for the timer.
    M.refresh()
  end, { "enter", name }):start()
end

function M.setup()
  if chooser then return end

  chooser = hs.chooser.new(function(choice)
    if choice and choice.name then enter(choice.name) end
  end)

  chooser:rows(pickerOpt("rows", FALLBACK_ROWS))
  chooser:bgDark(true)
  chooser:fgColor({ hex = "#" .. pickerOpt("match_color", "00FFFF") })
  chooser:subTextColor({ hex = "#808080" })
  chooser:searchSubText(true)
  chooser:placeholderText("context")

  -- Prewarm. The first show() of a new chooser costs ~138ms building its view
  -- hierarchy, the second ~60ms, then ~23ms. Paying that at load means the
  -- first show the user sees is already warm. show() and hide() back to back
  -- do not paint a frame.
  chooser:choices({ { text = " ", subText = "" } })
  chooser:show()
  chooser:hide()

  M.refresh()

  timer = hs.timer.doEvery(REFRESH_SECONDS, function() M.refresh() end)
end

function M.show()
  if not chooser then M.setup() end

  -- Width is a percentage of the FOCUSED screen, so convert from a pixel
  -- target each time. 900px is 62.5% of the 1440px laptop and 26.2% of the
  -- 3440px LG; a fixed percentage cannot serve both.
  local screenWidth = hs.screen.mainScreen():frame().w
  local target = pickerOpt("target_width_px", FALLBACK_WIDTH_PX)
  chooser:width(math.min(100, target / screenWidth * 100))
  chooser:rows(pickerOpt("rows", FALLBACK_ROWS))

  if #cache.rows == 0 then
    -- Cold cache: wait for the fetch rather than flash an empty panel. Still
    -- faster than the choose path, which pays this AND the 200ms launch.
    M.refresh(function() chooser:show() end)
    return
  end

  -- Deliberately NOT applyChoices() here. Every refresh already applies its
  -- rows, so the chooser is current before we are called. Rebuilding 202
  -- formatted rows on the hot path measured 78-85ms against 23ms without it —
  -- more than the panel draw itself.
  chooser:show()
  M.refresh()   -- self-correct in the background if state moved
end

-- Visibility is an INSTANCE method; there is no hs.chooser.currentChooser().
-- Exposed so the smoke check can drive show/hide without reaching inside.
function M.isVisible()
  return chooser ~= nil and chooser:isVisible()
end

function M.hide()
  if chooser then chooser:hide() end
end

-- Consumed by `context doctor`.
function M.status()
  return hs.json.encode({
    loaded = true,
    rows = #cache.rows,
    generated = cache.generated or 0,
    refresh_seconds = REFRESH_SECONDS,
  })
end

return M
