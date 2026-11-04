#!/bin/bash
# Unit checks for splitsize.lua's PURE logic (the preset ladder and the
# pixel math). No Hammerspoon, no AeroSpace, no windows: it runs under a plain
# Lua interpreter, which is why splitsize.lua must not touch `hs.*` at load
# time. The live half (real hotkey, real windows) is live-splitsize.sh.
#
# Every expected value below is a LITERAL, never computed by calling the
# module -- a test that derives its expectation from the code under test
# cannot fail (memory: prove-the-test-can-fail).
#
# MODULE_DIR overrides where splitsize.lua is loaded from, so a deliberately
# broken copy can be pointed at to prove this script goes red.
set -u
MODULE_DIR="${MODULE_DIR:-$HOME/.hammerspoon}"
LUA="${LUA:-/opt/homebrew/bin/luajit}"

MODULE_DIR="$MODULE_DIR" "$LUA" - <<'EOF'
package.path = os.getenv("MODULE_DIR") .. "/?.lua;" .. package.path
local ok, m = pcall(require, "splitsize")
if not ok then
  io.stderr:write("FAIL: could not load splitsize: " .. tostring(m) .. "\n")
  os.exit(1)
end

local pass = 0
local function eq(label, got, want)
  if got ~= want then
    io.stderr:write(string.format("FAIL: %s: got %s, want %s\n", label, tostring(got), tostring(want)))
    os.exit(1)
  end
  io.write("   ok: " .. label .. "\n")
  pass = pass + 1
end

-- The ladder, growing from an even split.
eq("grow from 50 -> 66", m.nextPreset(50, 1), 66)
eq("grow from 66 -> 75", m.nextPreset(66, 1), 75)
eq("grow from 75 -> end of ladder", m.nextPreset(75, 1), nil)

-- Shrinking back down, past even.
eq("shrink from 75 -> 66", m.nextPreset(75, -1), 66)
eq("shrink from 66 -> 50", m.nextPreset(66, -1), 50)
eq("shrink from 50 -> 33", m.nextPreset(50, -1), 33)
eq("shrink from 33 -> 25", m.nextPreset(33, -1), 25)
eq("shrink from 25 -> end of ladder", m.nextPreset(25, -1), nil)

-- A window that AeroSpace or a minimum width left near, not on, a preset.
eq("49 counts as 50: grow -> 66", m.nextPreset(49, 1), 66)
eq("51 counts as 50: shrink -> 33", m.nextPreset(51, -1), 33)
eq("60 (clamped short of 66): grow -> 66", m.nextPreset(60, 1), 66)
eq("64 counts as 66: grow -> 75", m.nextPreset(64, 1), 75)
eq("68 counts as 66: shrink -> 50", m.nextPreset(68, -1), 50)
eq("100 (degenerate): grow -> end", m.nextPreset(100, 1), nil)
eq("0 (degenerate): shrink -> end", m.nextPreset(0, -1), nil)

-- Pixel math: round to nearest pixel.
eq("66% of 1436px = 948", m.targetWidth(66, 1436), 948)
eq("75% of 1436px = 1077", m.targetWidth(75, 1436), 1077)
eq("50% of 3000px = 1500", m.targetWidth(50, 3000), 1500)
eq("33% of 3000px = 990", m.targetWidth(33, 3000), 990)

-- rowTarget (cbm-055): the pixel width that makes window `id` pct percent of
-- its row's span (leftmost edge to rightmost edge), and that span. Rows are
-- { {id=, x=, w=}, ... } as readRow builds them.
local two = { { id = "1", x = 0, w = 1700 }, { id = "2", x = 1700, w = 1732 } }
local target, span = m.rowTarget(two, "1", 40)
eq("two windows, 40% of a 3432px span = 1373", target, 1373)
eq("two windows span 3432px", span, 3432)
-- three windows, not in screen order, the span starts at the leftmost edge
-- (100) and ends at the rightmost (2100 + 1332 = 3432): 3332px, 50% = 1666
local three = {
  { id = "c", x = 2100, w = 1332 },
  { id = "a", x = 100, w = 1000 },
  { id = "b", x = 1100, w = 1000 },
}
target, span = m.rowTarget(three, "b", 50)
eq("three windows, 50% of a 3332px span = 1666", target, 1666)
eq("three windows span 3332px", span, 3332)
eq("a one-window row has nothing to split", m.rowTarget({ { id = "1", x = 0, w = 3432 } }, "1", 40), nil)
eq("an empty row has nothing to split", m.rowTarget({}, "1", 40), nil)
eq("a window that is not in the row", m.rowTarget(two, "9", 40), nil)
eq("0% is refused", m.rowTarget(two, "1", 0), nil)
eq("100% is refused", m.rowTarget(two, "1", 100), nil)
eq("a percent that is not a number is refused", m.rowTarget(two, "1", "40"), nil)
eq("1% is the smallest share", m.rowTarget(two, "1", 1), 34)
eq("99% is the largest share", m.rowTarget(two, "1", 99), 3398)
eq("setWidth exists", type(m.setWidth), "function")

io.write(string.format("\nall %d checks passed\n", pass))
EOF
