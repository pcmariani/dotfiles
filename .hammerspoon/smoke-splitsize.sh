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

io.write(string.format("\nall %d checks passed\n", pass))
EOF
