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

-- State markers are IMAGES, not glyphs.
--
-- hs.chooser draws a circled-arrow icon in every row's image slot whether or
-- not we ask for one. Verified: rows carrying no `image` key and no marker text
-- at all still rendered it, so it is the cell's own art and cannot be turned
-- off. The only way to remove it is to occupy the slot -- a 1x1 transparent
-- image leaves the row clean.
--
-- Since the slot has to be filled anyway, it becomes the state marker. That is
-- strictly better than the old text glyphs: the slot is already pixel-aligned
-- so no padding maths is involved, and it frees the text line of the leading
-- "marker .. two spaces" that used to eat three columns on all 91 rows.
--
-- Built once and cached. A canvas per row would be 91 canvases per refresh.
local DOT_PX = 18
local markerCache = {}

-- hex = nil means "no marker": a transparent pixel that suppresses the arrow.
local function dotImage(hex)
  local key = hex or "none"
  if markerCache[key] then return markerCache[key] end

  local img
  if hex == nil then
    img = hs.canvas.new({ x = 0, y = 0, w = 1, h = 1 }):imageFromCanvas()
  else
    local c = hs.canvas.new({ x = 0, y = 0, w = DOT_PX, h = DOT_PX })
    c[1] = {
      type = "circle",
      center = { x = DOT_PX / 2, y = DOT_PX / 2 },
      radius = DOT_PX / 3.6,
      action = "fill",
      fillColor = { hex = hex },
    }
    img = c:imageFromCanvas()
    c:delete()
  end

  markerCache[key] = img
  return img
end

local cache = { rows = {}, picker = {}, generated = 0 }
local chooser = nil
local timer = nil

local function pickerOpt(key, fallback)
  local v = cache.picker and cache.picker[key]
  if v == nil then return fallback end
  return v
end

-- Pad to a column width in CHARACTERS, not bytes. Org names are ASCII today,
-- but utf8.len is what keeps a multibyte one from throwing the column out.
local function pad(s, width)
  s = s or ""
  local n = utf8.len(s) or #s
  if n >= width then return s end
  return s .. string.rep(" ", width - n)
end

local ORG_SEP = "/"

-- The org PREFIXES the name, and the two share ONE padded column.
--
-- Keeping them in separate columns is what caused the wrapping. Every row was
-- padded to the widest org ("Sports Basement", 15) even though only 3 of 91
-- contexts have one, which put a 17-column hole in 88 rows and pushed the line
-- to 108 characters — about 1037px of Menlo 16pt inside a 900px panel, so the
-- path wrapped onto a second line flush with the left margin.
--
-- Treating "org/name" as a single unit costs nothing. Measured on this
-- machine: the widest org+name is 38 characters, which is EXACTLY the widest
-- bare name, because the longest name (sportsbasement.sales-transactions-logs)
-- has no org. The line is now 38 + 2 + 48 = 88 characters (~845px), so only
-- the longest paths take an ellipsis and nothing wraps.
local function labelText(r)
  local org = r.org
  if org and org ~= "" then
    return org .. ORG_SEP .. (r.name or "")
  end
  return r.name or ""
end

-- One aligned line per row: org/name in a padded column, then the path.
-- The marker is not in the text at all any more — see dotImage.
--
-- Built by CONCATENATING pre-styled fragments rather than styling ranges of
-- one string. setStyle's indices are neither plainly byte- nor
-- character-based (styling range 2,2 of "●ABCDEF" produced a run at 3..3), so
-- range arithmetic here would be guesswork. Concatenation has no index math.
--
-- Every fragment carries lineBreak = "truncateTail". Without it the cell wraps
-- a too-long line onto a second row; with it the tail is clipped with a real
-- ellipsis. The path is deliberately LAST so that it is the thing truncated —
-- behind it, an org would be eaten first.
--
-- There is no subText: rows are single-line so more of them fit, matching the
-- one-row-per-line terminal look. That is only safe because fuzzy search was
-- verified to match styled text with no subText present — typing "zebra7"
-- against styled rows whose `name` did not contain it still selected row 7.
local function choicesFrom(rows)
  local mono = pickerOpt("monospace", true)
  local face = pickerOpt("font", "Menlo")
  local size = pickerOpt("font_size", 15)
  local fg = "#" .. pickerOpt("text_color", "C8D3D5")
  local dim = "#" .. pickerOpt("subtext_color", "5F7377")
  local accent = "#" .. pickerOpt("accent_color", "00FFAA")
  local orgHex = "#" .. pickerOpt("org_color", "C678DD")

  local function frag(s, hex)
    return hs.styledtext.new(s, {
      font = { name = face, size = size },
      color = { hex = hex },
      paragraphStyle = { lineBreak = "truncateTail" },
    })
  end

  -- One width for the whole org/name column.
  local labelw = 0
  for _, r in ipairs(rows) do
    labelw = math.max(labelw, utf8.len(labelText(r)) or 0)
  end

  local out = {}
  for i, r in ipairs(rows) do
    -- The current context is dimmed as well as sunk to the bottom, so the row
    -- you are already in never looks like a destination.
    local nameHex = (r.state == "current") and dim or fg
    local label = labelText(r)
    local trailing = string.rep(" ", math.max(0, labelw - (utf8.len(label) or 0))) .. "  "
    local text

    if mono then
      local org = r.org
      if org and org ~= "" then
        text = frag(org .. ORG_SEP, orgHex) .. frag(r.name or "", nameHex)
      else
        text = frag(r.name or "", nameHex)
      end
      text = text .. frag(trailing, dim) .. frag(r.path or "", dim)
    else
      text = pad(label, labelw) .. "  " .. (r.path or "")
    end

    out[i] = {
      text = text,
      name = r.name,
      -- Running is the only state worth an accent; current gets a quiet dot
      -- because it is where you already are. Idle gets a transparent pixel,
      -- purely to keep the chooser from drawing its circled arrow.
      image = dotImage((r.state == "running" and accent)
                    or (r.state == "current" and dim)
                    or nil),
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
-- Panel-wide styling. Called from setup() AND after every refresh, because at
-- setup time the cache is empty — the config arrives with the first
-- `--emit`, so styling applied only at setup would always be the fallbacks.
local function applyStyle()
  if not chooser then return end
  chooser:bgDark(true)
  -- fgColor is the colour of ALL the text, not the matched substring. Pointing
  -- it at match_color (cyan) is what turned every row cyan.
  chooser:fgColor({ hex = "#" .. pickerOpt("text_color", "C8D3D5") })
  chooser:subTextColor({ hex = "#" .. pickerOpt("subtext_color", "5F7377") })
  chooser:searchSubText(true)
  chooser:placeholderText(pickerOpt("prompt", "context"))
  chooser:rows(pickerOpt("rows", FALLBACK_ROWS))
end

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
        applyStyle()      -- the config only arrives here, never at setup
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

  applyStyle()

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

  -- Always open on an empty query. The chooser keeps the last one otherwise,
  -- which not only pre-filters the list but re-ranks it by match score —
  -- discarding the running-first ordering and putting an arbitrary row under
  -- the cursor. Clearing it is what makes ctrl-space then Enter land on the
  -- last context again.
  chooser:query("")

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

-- Exposed for the smoke check: show() must always open on an empty query.
function M.query()
  return chooser and chooser:query() or ""
end

function M.setQueryForTest(text)
  if chooser then chooser:query(text) end
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
