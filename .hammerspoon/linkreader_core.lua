-- The pure half of the Slack pointer reader (see linkreader.lua). No hs.*
-- globals in here, so `lua` can test it with a fake clock and a fake hit test
-- (tests/test_linkreader_core.py in the context-based-mac repo).
--
-- read_link(hit_test, now, sleep, cap_ms) -> url | nil
--
--   hit_test()  the chain under the pointer, from the element up through at
--               most 6 parents: { { role = "AXStaticText" }, { role = "AXLink",
--               url = "https://..." }, ... }. It may return nil.
--   now()       seconds, so the cap is REAL elapsed time (a slow hit test counts),
--               not a sum of the sleeps.
--   sleep(ms)   wait between asks.
--   cap_ms      give up after this long (default 300).
--
-- Why it asks more than once (measured 2026-10-23 on Slack, see
-- chrome-bridge-spike/prototypes/linkproto.lua): Chromium answers the first
-- hit test after the pointer moves with a stale or coarse element and deepens
-- it on later asks. So ask every 40 ms and trust an answer only once two
-- consecutive asks agree; 8 asks at most.
--
-- A link is an AXLink in the chain whose AXURL is http or https. An AXWebArea's
-- url is the page, never the thing under the pointer, so it never counts, and
-- mailto:, javascript:, ftp: and the rest are not links this feature routes.

local M = {}

M.INTERVAL_MS = 40
M.MAX_ASKS = 8
M.MAX_DEPTH = 7          -- the element plus 6 parents

local function link_of(chain)
  if type(chain) ~= "table" then return nil end
  for i = 1, math.min(#chain, M.MAX_DEPTH) do
    local node = chain[i]
    if type(node) == "table" and node.role == "AXLink" then
      local url = node.url
      if type(url) == "string" then
        local scheme = url:match("^(%a[%w+.-]*):")
        scheme = scheme and scheme:lower()
        if (scheme == "http" or scheme == "https") and #url > #scheme + 3 then
          return url
        end
      end
    end
  end
  return nil
end

local function signature(chain)
  if type(chain) ~= "table" then return "nil" end
  local parts = {}
  for i = 1, math.min(#chain, M.MAX_DEPTH) do
    local node = chain[i]
    parts[#parts + 1] = tostring(type(node) == "table" and node.role) .. "|" ..
      tostring(type(node) == "table" and node.url)
  end
  return table.concat(parts, "\n")
end

function M.read_link(hit_test, now, sleep, cap_ms)
  cap_ms = cap_ms or 300
  local t0 = now()
  local prev
  for ask = 1, M.MAX_ASKS do
    local ok, chain = pcall(hit_test)
    if not ok then return nil end
    local sig = signature(chain)
    if sig == prev then return link_of(chain) end
    prev = sig
    if (now() - t0) * 1000 >= cap_ms then return nil end
    sleep(M.INTERVAL_MS)
  end
  return nil
end

return M
