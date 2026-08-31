-- ~/.hammerspoon/init.lua

-- Command-line bridge, so `hs -c "..."` can talk to this running instance.
-- Used by the context picker; also how `context doctor` probes the backend.
require("hs.ipc")

-- Resident context picker. ctrl-space reaches this through bin/context-pick.
-- A global, not a local: `hs -c` evaluates in the global environment, and
-- bin/context-pick probes for this name.
contextPicker = require("context-picker")
contextPicker.setup()

-- Karabiner maps ctrl-space (caps+space) to F18 and this shows the picker.
-- Going through F18 rather than having Karabiner run bin/context-pick avoids
-- the `hs -c` round trip, which was 60-70ms of the ~130ms total. Karabiner
-- still claims the chord, so it cannot fall through to the space-mode layer.
hs.hotkey.bind({}, "f18", function() contextPicker.show() end)

-----------------------------------------------------------
-- Microphone mute
-----------------------------------------------------------

local micMenuItem = hs.menubar.new()
local micTimer = nil

local function getDefaultMic()
  return hs.audiodevice.defaultInputDevice()
end

local function updateMicIndicator()
  local mic = getDefaultMic()

  if not mic then
    micMenuItem:setTitle("🎙️ ?")
    return
  end

  local muted = mic:inputMuted()

  if muted then
    micMenuItem:setTitle("🔇")
  else
    micMenuItem:setTitle("🎙️")
  end
end

function toggleMicMute()
  local mic = getDefaultMic()

  if not mic then
    hs.alert.show("🎙️ No microphone found")
    return
  end

  local muted = mic:inputMuted()

  if muted == nil then
    hs.alert.show("🎙️ Microphone does not support mute")
    return
  end

  mic:setInputMuted(not muted)
  updateMicIndicator()

  if muted then
    hs.alert.show("🎙️ MIC ON")
  else
    hs.alert.show("🔇 MIC MUTED")
  end
end

-----------------------------------------------------------
-- Menu bar
-----------------------------------------------------------

micMenuItem:setMenu({
  {
    title = "Toggle Microphone",
    fn = function()
      toggleMicMute()
    end
  }
  -- ,
  -- {
  --   title = "Update",
  --   fn = function()
  --     updateMicIndicator()
  --   end
  -- }
})

updateMicIndicator()

micTimer = hs.timer.doEvery(1, updateMicIndicator)

-----------------------------------------------------------
-- Global hotkey
-----------------------------------------------------------

-- Goku/Karabiner:
--
--   Space + M
--       ↓
--   Hyper + M
--       ↓
--   ⌘⌃⌥⇧M
--       ↓
--   Hammerspoon

hs.hotkey.bind({ "cmd", "shift", "ctrl", "alt" }, "m", toggleMicMute)

-----------------------------------------------------------
-- Hammerspoon reload
-----------------------------------------------------------

if hs.settings.get("hammerspoonReloading") then
  hs.settings.set("hammerspoonReloading", false)

  hs.timer.doAfter(0.2, function()
    hs.alert.show("🔨 Hammerspoon reloaded")
  end)
end

hs.hotkey.bind({ "cmd", "shift", "ctrl", "alt" }, "r", function()
  hs.settings.set("hammerspoonReloading", true)
  hs.reload()
end)




-----------------------------------------------------------
-- Chrome tab focusing
-----------------------------------------------------------

-- Hammerspoon doesn't inherit the Homebrew PATH,
-- so use the absolute path to AeroSpace.
local aerospace = "/opt/homebrew/bin/aerospace"

local tabFieldSeparator = "<|>"

-- Ask Chrome to describe every tab in every window.
--
-- A window's title only ever reflects its *active* tab, so matching
-- on window titles alone silently fails whenever the target tab is
-- sitting in the background. Enumerating tabs avoids that.
--
-- Windows are identified by their AppleScript id rather than their
-- index: index is front-to-back z-order and shifts the moment you
-- focus something else, which would race the tab switch below.
--
-- Returns a list of:
--   { windowID, windowTitle, tabIndex, tabTitle, tabURL }
local function listChromeTabs()
  local script = string.format([[
    tell application "Google Chrome"
      set fieldSeparator to "%s"
      set rowList to {}

      repeat with theWindow in windows
        -- Whatever Hammerspoon will see as this window's title.
        try
          set windowTitle to name of theWindow
        on error
          set windowTitle to title of active tab of theWindow
        end try

        repeat with t from 1 to (count of tabs of theWindow)
          set theTab to tab t of theWindow

          set end of rowList to ((id of theWindow as text) & fieldSeparator ¬
            & windowTitle & fieldSeparator ¬
            & (t as text) & fieldSeparator ¬
            & (title of theTab) & fieldSeparator ¬
            & (URL of theTab))
        end repeat
      end repeat

      return rowList
    end tell
  ]], tabFieldSeparator)

  local ok, rows = hs.osascript.applescript(script)

  if not ok or type(rows) ~= "table" then
    return {}
  end

  local tabs = {}

  for _, row in ipairs(rows) do
    local fields = {}

    for field in (row .. tabFieldSeparator):gmatch(
      "(.-)" .. tabFieldSeparator:gsub("%p", "%%%0")
    ) do
      table.insert(fields, field)
    end

    if #fields >= 5 then
      table.insert(tabs, {
        -- Kept as a string: Chrome's window ids are large, and we
        -- only ever hand them straight back to AppleScript.
        windowID    = fields[1],
        windowTitle = fields[2],
        tabIndex    = tonumber(fields[3]),
        tabTitle    = fields[4],
        -- The URL may itself contain the separator; rejoin the tail.
        tabURL      = table.concat(fields, tabFieldSeparator, 5),
      })
    end
  end

  return tabs
end

-- Allow a single string instead of requiring a table.
local function asList(value)
  if type(value) == "string" then
    return { value }
  end

  return value
end

local function containsAny(haystack, needles)
  if not needles then
    return false
  end

  for _, needle in ipairs(needles) do
    if haystack:find(needle, 1, true) then
      return true
    end
  end

  return false
end

-- How many times to re-check for the retitled window, ~30ms apart.
local chromeFocusRetries = 10

-- Chrome decorates the accessibility title that Hammerspoon and
-- AeroSpace read, so the tab title is a *prefix* of the window
-- title rather than equal to it:
--
--   AppleScript : "Inbox (744) - … - Boomi, LP Mail"
--   AXTitle     : "Inbox (744) - … - Boomi, LP Mail
--                  - High memory usage - 2.0 GB
--                  - Google Chrome - Person 1"
local function windowShowsTab(w, match, titleMatches)
  local axTitle = w:title() or ""

  if #match.tabTitle > 0
      and axTitle:sub(1, #match.tabTitle) == match.tabTitle
  then
    return true
  end

  -- Volatile titles (Gmail's unread count, memory notices) can
  -- change between the two reads, so also accept the caller's
  -- own title criteria.
  return containsAny(axTitle, titleMatches)
end

local function focusChromeWindowShowing(match, titleMatches, attemptsLeft)
  local chrome = hs.application.get("Google Chrome")

  if chrome then
    for _, w in ipairs(chrome:allWindows()) do
      if windowShowsTab(w, match, titleMatches) then
        hs.execute(aerospace .. " focus --window-id " .. w:id())
        return
      end
    end
  end

  -- The window title may not have caught up with the tab switch yet.
  if attemptsLeft > 0 then
    hs.timer.doAfter(0.03, function()
      focusChromeWindowShowing(match, titleMatches, attemptsLeft - 1)
    end)

    return
  end

  -- Never found an AeroSpace window id, so let Chrome raise the
  -- window itself and rely on AeroSpace following app activation.
  hs.osascript.applescript(string.format([[
    tell application "Google Chrome"
      set index of window id %s to 1
      activate
    end tell
  ]], match.windowID))
end

-- Find the first tab matching the supplied criteria, switch its
-- window to that tab, and ask AeroSpace to focus that window.
--
-- Supported criteria:
--
--   { title = "some title" }
--
--   { title = { "title one", "title two" } }
--
--   { url = "example.com" }
--
--   { url = { "example.com", "example.org" } }
--
-- Title and URL criteria are OR'd together.
local function focusChromeTarget(label, criteria)
  local chrome = hs.application.get("Google Chrome")

  if not chrome then
    hs.alert.show("🌐 Chrome is not running")
    return false
  end

  criteria = criteria or {}

  local titleMatches = asList(criteria.title)
  local urlMatches = asList(criteria.url)

  local match = nil

  for _, candidate in ipairs(listChromeTabs()) do
    if containsAny(candidate.tabTitle, titleMatches)
        or containsAny(candidate.tabURL, urlMatches)
    then
      match = candidate
      break
    end
  end

  if not match then
    hs.alert.show("🌐 Chrome target not found: " .. label)
    return false
  end

  -- Switch the tab first so the window settles on the title we are
  -- about to search for. Chrome's AppleScript window ids are not
  -- CGWindowIDs, so the title is the only handle across the two APIs.
  hs.osascript.applescript(string.format(
    'tell application "Google Chrome" to ' ..
    'set active tab index of window id %s to %d',
    match.windowID, match.tabIndex
  ))

  focusChromeWindowShowing(match, titleMatches, chromeFocusRetries)

  return true
end


-----------------------------------------------------------
-- Chrome hotkeys
-----------------------------------------------------------

-- ⌘⇧⌃⌥G → Boomi Gmail
hs.hotkey.bind(
  { "cmd", "shift", "ctrl", "alt" },
  "g",
  function()
    focusChromeTarget("Boomi Gmail", {
      title = "Boomi, LP Mail",
      -- Account-scoped: the personal Gmail window lives at u/1.
      url = "mail.google.com/mail/u/0",
    })
  end
)





-- -----------------------------------------------------------
-- -- Chrome window focusing
-- -----------------------------------------------------------
--
-- -- Hammerspoon doesn't inherit the Homebrew PATH,
-- -- so use the absolute path to AeroSpace.
-- local aerospace = "/opt/homebrew/bin/aerospace"
--
-- -- Find a Chrome window whose title contains titleMatch,
-- -- then ask AeroSpace to focus that exact window.
-- local function focusChromeWindow(titleMatch)
--   local output, ok = hs.execute(
--     aerospace
--     .. " list-windows --all --format '%{window-id}|%{app-name}|%{window-title}'"
--   )
--
--   if not ok then
--     hs.alert.show("🚨 AeroSpace command failed")
--     return false
--   end
--
--   for line in output:gmatch("[^\r\n]+") do
--     local windowID, appName, windowTitle =
--         line:match("^(%d+)|([^|]+)|(.+)$")
--
--     if windowID
--         and appName == "Google Chrome"
--         and windowTitle
--         and windowTitle:find(titleMatch, 1, true)
--     then
--       hs.execute(
--         aerospace .. " focus --window-id " .. windowID
--       )
--
--       return true
--     end
--   end
--
--   hs.alert.show("🌐 Chrome window not found")
--   return false
-- end
--
-- -----------------------------------------------------------
-- -- Chrome targets
-- -----------------------------------------------------------
--
-- local function focusChromeTarget(name, titleMatches)
--   titleMatches = titleMatches or { name }
--
--   for _, titleMatch in ipairs(titleMatches) do
--     if focusChromeWindow(titleMatch) then
--       return true
--     end
--   end
--
--   hs.alert.show("🌐 Chrome target not found: " .. name)
--   return false
-- end
--
--
--
-- local function focusChromeTarget(label, criteria)
--   local chrome = hs.application.get("Google Chrome")
--
--   if not chrome then
--     hs.alert.show("🌐 Chrome is not running")
--     return false
--   end
--
--   criteria = criteria or {}
--
--   local titleMatches = criteria.title
--   local urlMatch = criteria.url
--
--   -- Allow a single title string instead of requiring a table.
--   if type(titleMatches) == "string" then
--     titleMatches = { titleMatches }
--   end
--
--   for _, w in ipairs(chrome:allWindows()) do
--     local title = w:title() or ""
--     local titleMatched = false
--     local urlMatched = false
--
--     -- Match window title.
--     if titleMatches then
--       for _, pattern in ipairs(titleMatches) do
--         if title:find(pattern, 1, true) then
--           titleMatched = true
--           break
--         end
--       end
--     end
--
--     -- Match Chrome's current document URL.
--     if urlMatch then
--       local ax = hs.axuielement.windowElement(w)
--       local url = ax:attributeValue("AXDocument")
--
--       if url and url:find(urlMatch, 1, true) then
--         urlMatched = true
--       end
--     end
--
--     if titleMatched or urlMatched then
--       w:focus()
--       return true
--     end
--   end
--
--   hs.alert.show("🌐 Chrome target not found: " .. label)
--   return false
-- end
--
--
-- -----------------------------------------------------------
-- -- Chrome hotkeys
-- -----------------------------------------------------------
--
-- hs.hotkey.bind(
--   { "cmd", "shift", "ctrl", "alt" },
--   "g",
--   function()
--     focusChromeTarget("Boomi, LP Mail")
--   end
-- )
--
-- hs.hotkey.bind(
--   { "cmd", "shift", "ctrl", "alt" },
--   "c",
--   function()
--     focusChromeTarget("ChatGPT")
--   end
-- )
