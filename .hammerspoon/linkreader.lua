-- Opt + right-click on a link in Slack sends that link to the link-to panel:
-- `context link-send URL --source slack`. The click is swallowed, so Slack's
-- own context menu does not open. The pure half (ask until two answers agree,
-- accept only an http/https AXLink) is linkreader_core.lua, tested by
-- tests/test_linkreader_core.py in the context-based-mac repo.
--
-- Why this shape (2026-10-23, prototype: chrome-bridge-spike/prototypes/linkproto.lua):
--
-- * Slack is Electron. Its page is invisible to the accessibility API until
--   AXManualAccessibility is set on the app. The setting sticks for the life
--   of that process, but a Slack launched after start() has never had it, so it
--   is set (once per process id) before the first read after the front app
--   changes, not once at start().
--
-- * The tap stays running and checks the frontmost app AT EVENT TIME, rather
--   than an application watcher arming and disarming it. A watcher can miss an
--   activation (a reload mid-switch, a space change) and leave the tap armed
--   or disarmed wrongly; asking "who is frontmost" when the click arrives
--   cannot be stale. Outside ARMED_APPS the callback returns at once, before
--   it reads any accessibility state, so every other app's right-clicks pass
--   through untouched.
--
-- * Only opt alone (no cmd, ctrl or shift) is ours. A hit that is not a link
--   (or any error) lets the click through unchanged. When it IS a link both
--   the right-mouse down and its matching up are swallowed; the flag that
--   remembers the up is cleared at start, at stop and on every new down, so a
--   lost up can never eat a later click.
--
-- * The URL goes to `context` as one argv element of an hs.task, after a `--`,
--   never through a shell and never through `hs -c`: a URL is text from a chat
--   message. Absolute path, because Hammerspoon's PATH is
--   /usr/bin:/bin:/usr/sbin:/sbin and a bare command fails silently (exit 127).
--
-- * A failure alert is chosen by exit code from a fixed table (the codes and
--   lines mirror context/links.py LinkExit and MESSAGES; a test compares them).
--   Nothing from the URL, the workspace, stdout or stderr is ever shown.

local core = require("linkreader_core")

local M = {}

M.CONTEXT = os.getenv("HOME") .. "/.local/bin/context"
M.SOURCE = "slack"
M.CAP_MS = 300

-- The one table of apps whose right-clicks this reads. Bundle ids.
M.ARMED_APPS = {
  ["com.tinyspeck.slackmacgap"] = true,
}

-- Exit code -> alert line, mirroring context/links.py.
M.MESSAGES = {
  [10] = "Not a link I can open",
  [11] = "No Chrome window for that workspace",
  [12] = "Chrome is not running",
  [13] = "The Chrome extension is not answering",
  [14] = "The window manager is not answering",
  [15] = "More than one workspace could take this link",
  [16] = "Choose where this link should go",
  [17] = "The link may have opened but this could not be confirmed",
  [18] = "No link is waiting",
  [19] = "The link was refused",
  [20] = "The link panel is not available",
  [21] = "No Chrome window of the right profile for that workspace",
  [22] = "The Chrome extension is not connected for that profile (see context bridge status)",
  [23] = "The Chrome profiles could not be matched to the windows",
}
M.FALLBACK_MESSAGE = "Sending the link failed"

local swallowUp = false
local preparedPid = nil     -- the app process AXManualAccessibility was last set on

-- The chain under the pointer: the element and up to 6 parents, each as
-- { role =, url = } (url only read for an AXLink, as a table's .url or a string).
local function hitTestAt(point)
  return function()
    local el = hs.axuielement.systemElementAtPosition(point)
    local chain = {}
    for _ = 0, 6 do
      if not el then break end
      local role = tostring(el.AXRole)
      local url
      if role == "AXLink" then
        url = el.AXURL
        if type(url) == "table" then url = url.url end
        if url ~= nil then url = tostring(url) end
      end
      chain[#chain + 1] = { role = role, url = url }
      el = el.AXParent
    end
    return chain
  end
end

local function prepare(app)
  local pid = app:pid()
  if pid == preparedPid then return end
  hs.axuielement.applicationElement(app).AXManualAccessibility = true
  -- Remembered only once the set went through: an error above (guarded lets
  -- the click pass) leaves it unset, so the next click tries again.
  preparedPid = pid
end

local function send(url)
  local task = hs.task.new(M.CONTEXT, function(code)
    if code ~= 0 then
      hs.alert.show(M.MESSAGES[code] or M.FALLBACK_MESSAGE, 3)
    end
  end, { "link-send", "--source", M.SOURCE, "--", url })
  -- A task that never launched has no exit code to alert on, and the click is
  -- already swallowed: say so rather than lose the link in silence.
  local ok, started = pcall(function() return task and task:start() end)
  if not ok or not started then
    hs.alert.show(M.FALLBACK_MESSAGE, 3)
  end
end

local function onMouse(e)
  local types = hs.eventtap.event.types
  if e:getType() == types.rightMouseUp then
    if swallowUp then swallowUp = false; return true end
    return false
  end

  swallowUp = false
  local flags = e:getFlags()
  if not (flags.alt and not flags.cmd and not flags.ctrl and not flags.shift) then return false end
  local app = hs.application.frontmostApplication()
  if not app or not M.ARMED_APPS[app:bundleID() or ""] then return false end

  prepare(app)
  local url = core.read_link(hitTestAt(e:location()), hs.timer.secondsSinceEpoch,
    function(ms) hs.timer.usleep(ms * 1000) end, M.CAP_MS)
  if not url then return false end
  swallowUp = true
  send(url)
  return true
end

-- A Lua error in the callback must never eat or break a click: let it through.
local function guarded(e)
  local ok, swallow = pcall(onMouse, e)
  if not ok then
    swallowUp = false
    return false
  end
  return swallow
end

-- The tap lives in a global, not in M: a module reloaded in place gets a fresh
-- M, and a tap held only by the old one could never be stopped.
function M.stop()
  if _G.__linkReaderTap then _G.__linkReaderTap:stop(); _G.__linkReaderTap = nil end
  swallowUp = false
end

function M.start()
  M.stop()
  preparedPid = nil
  -- A hung Slack accessibility call would otherwise block the tap (and every
  -- click behind it) for the default ~6 s. 0.15 s is far above a normal answer.
  pcall(function() hs.axuielement.systemWideElement():setTimeout(0.15) end)
  local types = hs.eventtap.event.types
  _G.__linkReaderTap = hs.eventtap.new({ types.rightMouseDown, types.rightMouseUp }, guarded)
  _G.__linkReaderTap:start()
end

return M
