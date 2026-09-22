-- ~/.hammerspoon/init.lua

-- Command-line bridge, so `hs -c "..."` can talk to this running instance.
-- Used by `context doctor` and other tooling to probe this instance.
require("hs.ipc")

-- THE CONTEXT PICKER LIVES IN paneld NOW, 2026-09-05.
--
-- What stood here was `contextPicker` (context-picker.lua, an hs.chooser) on
-- F18, plus a hyper-P binding that forwarded to paneld. Both are retired.
--
-- paneld registers ctrl-space itself through Carbon's RegisterEventHotKey, so
-- there is nothing for Karabiner to rewrite, nothing for Hammerspoon to catch,
-- and no `hs -c` round trip to skip. The chooser was measurably the faster
-- picker and the fzf panel is the one that gets used.
--
-- `hs.ipc` above STAYS: `context doctor` and other tooling talk to this
-- instance through it. context-picker.lua is kept on disk, unloaded.
--
-- To roll back: init.lua.bak2-prechooser, and restore the karabiner.edn
-- "context picker" rule from karabiner.edn.bak2-prechooser.

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


-- Break the active tab out into its own window, so it can then be thrown
-- at a workspace like any other window.
--
-- Uses Chrome's OWN Tab-menu command, and deliberately NOT AppleScript's
-- `move`. Measured 2/2 on Chrome 152.0.7977.84 (2026-09-11):
-- `move tab 1 of window id A to end of tabs of window id B` returns exit 0
-- with no error and delivers a blank chrome://newtab/ carrying a FRESH tab
-- id -- the URL, the back/forward history and all page state are gone. It
-- looks exactly like success. The menu item runs the same internal code as
-- dragging a tab out, so everything survives: verified tab id identical
-- before and after, with `go back` still walking the real history.
--
-- Chrome disables the item when the window holds a single tab, so
-- `enabled` is Chrome's own answer to "is there anything to break out"
-- rather than a count we would have to keep in step. The whole lookup is
-- 2-3ms in-process (7 trials), against 210-246ms for the same click driven
-- through osascript -- which is also the bridge that can wedge.
local BREAK_OUT_TAB_PATH = { "Tab", "Move Tab to New Window" }

local function breakOutChromeTab()
  local chrome = hs.application.get("Google Chrome")

  if not chrome then
    hs.alert.show("🌐 Chrome is not running")
    return false
  end

  -- The menu acts on the frontmost window's active tab. Acting while
  -- something else holds focus would silently break out a tab the user
  -- cannot see.
  if not chrome:isFrontmost() then
    return false
  end

  local item = chrome:findMenuItem(BREAK_OUT_TAB_PATH)

  if not item then
    -- The path is matched by its ENGLISH name, so a Chrome rename or a
    -- UI-language change lands here. Say so out loud: a key that silently
    -- does nothing is the expensive failure, not the noisy one.
    hs.alert.show("🌐 Chrome has no 'Move Tab to New Window' menu item")
    return false
  end

  -- Single-tab window: nothing to break out. Silent, like `space-t`.
  if not item.enabled then
    return false
  end

  return chrome:selectMenuItem(BREAK_OUT_TAB_PATH)
end

-- ⌘⇧⌃⌥D → break the active Chrome tab into its own window ("detach")
hs.hotkey.bind({ "cmd", "shift", "ctrl", "alt" }, "d", breakOutChromeTab)


-- Detach the active tab AND immediately offer to place the new window,
-- which is the two-key flow (space-d then shift-cmd-esc) as one key.
--
-- `paneld show` is a direct IPC call to the daemon and deliberately NOT a
-- synthesized shift-cmd-esc: synthesized keystrokes have been observed
-- silently ceasing mid-session, and this composition is exactly what they
-- would break, invisibly.
--
-- No settle delay is needed. Focus is ALREADY on the new window by the
-- time selectMenuItem returns -- measured at +0ms, with
-- `aerospace list-windows --focused` agreeing -- so `move`, which acts on
-- the focused window, acts on the window we just made.
--
-- Absolute path because Hammerspoon does not inherit the Homebrew PATH.
-- hs.task rather than hs.execute so this never blocks the main thread.
local PANELD_BIN =
  "/Users/petermariani/Applications/paneld.app/Contents/MacOS/paneld"

local function detachChromeTabToWorkspace()
  -- Only offer the picker if a tab actually left. Otherwise this key on a
  -- single-tab window would pop the picker and move the window you were
  -- already in -- not what the key says it does.
  if not breakOutChromeTab() then
    return false
  end

  hs.task.new(PANELD_BIN, nil, { "show", "move" }):start()
  return true
end

-- ⌘⌃⌥D (hyper MINUS shift) → detach the tab, then pick its workspace.
-- It cannot be hyper-shift-D: hyper already CONTAINS shift, so hyper-D and
-- hyper-shift-D are the same chord and Hammerspoon cannot tell them apart.
-- Dropping shift is what keeps this in the same `d` mnemonic family while
-- staying a distinct binding.
hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "d", detachChromeTabToWorkspace)


-- Join the active tab of the frontmost Chrome window into the OTHER Chrome
-- window. v1 scope, agreed with the user 2026-09-22: exactly two Chrome
-- windows open -- three or more is ambiguous about which window "wins"
-- and no-ops rather than guessing.
--
-- Exists because of an AeroSpace bug: dragging a tab between two TILED
-- windows makes the target window jump away mid-drag. Not fixable here --
-- this trades the drag for a key.
--
-- TWO MECHANISMS ARE RULED OUT, both confirmed live against Chrome
-- 153.0.8010.53, 2026-09-22, with disposable throwaway windows (a tab
-- driven through two URLs so it has real back/forward history):
--
--   AppleScript's own `move tab N of window id A to end of tabs of window
--   id B` is DESTRUCTIVE. It returns success with no error and delivers a
--   blank chrome://newtab/ carrying a FRESH tab id -- the URL and the
--   entire back/forward history are gone. Looks exactly like success.
--   NEVER use it for this.
--
--   Chrome's Tab menu has no "Move Tab to Window" item on this version --
--   only "Move Tab to New Window", which is breakOutChromeTab's own
--   mechanism above, unrelated and untouched.
--
-- WHAT WORKS: the tab's own real right-click context menu, opened with
-- ZERO mouse movement via performAction("AXShowMenu") on the tab's
-- accessibility element. It contains "Move Tab to Another Window" with a
-- submenu listing the other open window(s) -- the same internal code path
-- as a real drag, so history survives. Verified live: a tab driven through
-- two URLs kept the SAME AppleScript tab id across the join, and calling
-- `go back` on it in its new window correctly returned to the earlier
-- URL -- where the AppleScript verb above produces a dead blank tab.
-- BUG, found live 2026-09-22: this used to be AppleScript's global `count
-- windows`, which counts every Chrome window on the whole machine, not just
-- the two the user is looking at. That is wrong for what this key is FOR --
-- two windows tiled side by side in ONE AeroSpace workspace -- and it fails
-- in exactly the realistic case: the user has other Chrome windows open in
-- OTHER workspaces essentially always, so the global count is almost never
-- 2 even when the two windows on screen are exactly what the key should
-- act on. Reproduced live: 6 Chrome windows machine-wide, 2 in the focused
-- workspace, key fired, silent no-op. Scoped to AeroSpace's own idea of
-- "this workspace" instead -- the same authority `context`'s own Python
-- side defers to, never AppleScript's.
local function chromeWindowCountInFocusedWorkspace()
  local out, ok = hs.execute(aerospace .. " list-windows --workspace focused --json")

  if not ok then
    return nil
  end

  local windows = hs.json.decode(out)

  if not windows then
    return nil
  end

  local count = 0

  for _, w in ipairs(windows) do
    if w["app-name"] == "Google Chrome" then
      count = count + 1
    end
  end

  return count
end

-- The tab strip CANNOT be found by walking the window's full accessibility
-- tree top-down -- that recursion wanders into web page content and is
-- dangerously slow (measured: it did not return). Hit-testing instead:
-- a handful of probe points near the top-left of the window land on a
-- tab-strip descendant. (x=100 at this offset is Chrome's "Tab Search"
-- dropdown, an AXPopUpButton, not a tab -- harmless here since we only use
-- the hit to walk UP to its parent's siblings, not act on it directly.)
-- One hop up from the hit is an AXGroup whose AXChildren include the
-- AXTabGroup; ITS AXChildren are the tabs (AXRadioButton, AXValue == true
-- on the active one).
local function findActiveChromeTab(window)
  local sw = hs.axuielement.systemWideElement()
  local f = window:frame()

  for _, dx in ipairs({ 100, 120, 140, 160, 180, 200, 220 }) do
    for _, dy in ipairs({ 10, 14, 18 }) do
      local hit = sw:elementAtPosition(f.x + dx, f.y + dy)
      local parent = hit and hit:attributeValue("AXParent")
      local siblings = parent and parent:attributeValue("AXChildren")

      if siblings then
        for _, sibling in ipairs(siblings) do
          if sibling:attributeValue("AXRole") == "AXTabGroup" then
            for _, tab in ipairs(sibling:attributeValue("AXChildren") or {}) do
              if tab:attributeValue("AXValue") == true then
                return tab
              end
            end
          end
        end
      end
    end
  end

  return nil
end

-- The context menu ITSELF is also found by hit-testing, not by walking the
-- app's AXChildren (no AXMenu ever showed up there, checked live) and not
-- by counting arrow-key presses down from the top. That looked promising
-- at first -- 4 downs landed on "Move Tab to Another Window" -- until a
-- SECOND run, on a menu never dismissed with Escape, added its 4 downs to
-- the PREVIOUS run's leftover highlight instead of starting fresh, and a
-- later blind Enter on that drifted position landed on "Show Tabs
-- Vertically". That preference is APP-WIDE, not per-window, so it
-- silently changed the layout of every real Chrome window on this
-- machine -- caught only because a screenshot of a REAL window was taken
-- immediately after. (Reverted the same way: chrome:selectMenuItem
-- {"View","Show Tabs Vertically"}.) Hit-testing sidesteps the highlight
-- state entirely, and performAction("AXShowMenu") is always preceded by a
-- defensive Escape below, in case a previous run of this function did not
-- get to clean up its own menu.
--
-- Scanned relative to the ACTIVE TAB's own position, not the window's
-- frame -- proven offsets (menu item column starting ~130pt right of the
-- tab's left edge, item rows every ~24-34pt) hold regardless of window
-- size or position, where a window-frame-relative offset would not.
local function findVisibleMenuItem(originX, originY, title)
  local sw = hs.axuielement.systemWideElement()

  for dx = 0, 420, 20 do
    for dy = 0, 420, 14 do
      local hit = sw:elementAtPosition(originX + dx, originY + dy)

      if hit
          and hit:attributeValue("AXRole") == "AXMenuItem"
          and hit:attributeValue("AXTitle") == title
      then
        return hit
      end
    end
  end

  return nil
end

-- The submenu's own items are found the same way, scanned from the
-- "Move Tab to Another Window" item's OWN position and size (not a fixed
-- offset), since the submenu opens immediately to its right regardless of
-- where on screen that item ended up.
--
-- v1 requires EXACTLY ONE candidate. "New Window" is Chrome's own generic
-- entry, not a specific window, and is excluded. Zero real candidates
-- means the only other window is Incognito -- Chrome itself excludes it
-- from this list, by design, and there is nothing to do. Two or more
-- would mean the earlier `chromeWindowCountInFocusedWorkspace() == 2` check raced against a
-- window opening; either way, an ambiguous target is a no-op, not a
-- guess.
local function findSoleOtherWindowMenuItem(moveItem)
  local sw = hs.axuielement.systemWideElement()
  local pos = moveItem:attributeValue("AXPosition")
  local size = moveItem:attributeValue("AXSize")
  local originX = pos.x + size.w
  local originY = pos.y - 60

  local seen = {}
  local candidate, count = nil, 0

  for dx = 0, 700, 25 do
    for dy = 0, 400, 16 do
      local hit = sw:elementAtPosition(originX + dx, originY + dy)

      if hit and hit:attributeValue("AXRole") == "AXMenuItem" then
        local title = hit:attributeValue("AXTitle")

        if title and title ~= "" and title ~= "New Window" and not seen[title] then
          seen[title] = true
          candidate = hit
          count = count + 1
        end
      end
    end
  end

  if count == 1 then
    return candidate
  end

  return nil
end

local function dismissAnyChromeMenu()
  hs.eventtap.keyStroke({}, "escape", 0)
end

local function joinChromeTabToOtherWindow()
  local chrome = hs.application.get("Google Chrome")

  if not chrome then
    hs.alert.show("🌐 Chrome is not running")
    return false
  end

  -- Same guard as breakOutChromeTab: acting on a window the user cannot
  -- see would be a surprise, not a feature.
  if not chrome:isFrontmost() then
    return false
  end

  -- Scoped to the focused AeroSpace workspace (bug found live 2026-09-22
  -- -- see the function's own comment). NOT #chrome:allWindows() either --
  -- that was seen, live, to include a near-zero-size stray AX window
  -- (frame 86x19), so a raw accessibility count would misfire this gate.
  if chromeWindowCountInFocusedWorkspace() ~= 2 then
    return false
  end

  local window = chrome:focusedWindow()

  if not window then
    return false
  end

  -- Defensive: discard anything a previous, interrupted run of this
  -- function left open, so a stale highlight can never carry into this
  -- run (see the comment on findVisibleMenuItem above for why that
  -- matters).
  dismissAnyChromeMenu()
  hs.timer.usleep(200000)

  local tab = findActiveChromeTab(window)

  if not tab then
    hs.alert.show("🌐 Chrome's tab strip is not where it used to be")
    return false
  end

  tab:performAction("AXShowMenu")
  hs.timer.usleep(400000)

  local tabPos = tab:attributeValue("AXPosition")
  local moveItem = findVisibleMenuItem(
    tabPos.x, tabPos.y, "Move Tab to Another Window"
  )

  if not moveItem then
    -- The path is matched by its ENGLISH name, so a Chrome rename lands
    -- here. Say so out loud: a key that silently does nothing is the
    -- expensive failure, not the noisy one.
    hs.alert.show("🌐 Chrome has no 'Move Tab to Another Window' menu item")
    dismissAnyChromeMenu()
    return false
  end

  -- AXPress on a submenu-owning item is what opens ITS submenu -- this is
  -- how VoiceOver activates one -- which avoids arrow keys (and their
  -- stateful-highlight trap above) entirely.
  moveItem:performAction("AXPress")
  hs.timer.usleep(400000)

  local otherWindowItem = findSoleOtherWindowMenuItem(moveItem)

  if not otherWindowItem then
    dismissAnyChromeMenu()
    return false
  end

  otherWindowItem:performAction("AXPress")
  return true
end

-- ⌘⇧⌃⌥O → join the active Chrome tab into the other Chrome window ("the
-- OTHER one"). `o` was free in the space-mode layer -- checked against
-- every bare-letter rule in karabiner.edn's space-mode block -- and reads
-- as "other" alongside `d` for "detach".
hs.hotkey.bind({ "cmd", "shift", "ctrl", "alt" }, "o", joinChromeTabToOtherWindow)



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
