#!/bin/bash
# TORTURE TEST for the Chrome workspace-steal guard, run against the REAL
# running Chrome/AeroSpace/Hammerspoon, not fixtures -- same discipline as
# this directory's existing torture-toggle.sh (restore original state
# when done; prove the mechanism live, not just its pieces in isolation).
#
# Does NOT require "exactly 1 Chrome window" -- this machine routinely has
# many real windows open, and joinChromeTabToOtherWindow()'s own "exactly
# 2 windows" scope doesn't hold here. Instead: every artifact this script
# creates is a single disposable tab tagged with this run's own PID in its
# URL fragment, tracked by its own CGWindowID (NOT Chrome's AppleScript
# window id -- a different, uncorrelated number space, confirmed live
# 2026-09-26), and cleaned up by closing that exact window via Hammerspoon.
# Nothing else on the machine is touched.
#
# GUARD_ARMED is forced to 1 for the duration of the invocations THIS
# script makes only -- the live aerospace.toml wiring is untouched and
# stays in dry-run (GUARD_ARMED unset there) until Task 5.
set -u

PY=/Users/petermariani/.local/share/mise/installs/python/3.12/bin/python3
GUARD=~/.config/context/chrome-workspace-steal-guard.sh
MARKER=~/.local/state/context/chrome-tabs/last-corrected-window
LOCKDIR=~/.local/state/context/chrome-tabs/correction.lock

pass=0
fail_count=0
fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count+1)); }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

ORIGINAL_WS=$(/opt/homebrew/bin/aerospace list-workspaces --focused)
TARGET_WS="context-based-mac"
[ "$ORIGINAL_WS" = "$TARGET_WS" ] && TARGET_WS="ai"
echo "Original workspace: $ORIGINAL_WS, correction target for this run: $TARGET_WS"

close_by_cgid() {
    local cgid="$1"
    /opt/homebrew/bin/hs -c "local w = hs.window($cgid); if w then w:close() end" >/dev/null 2>&1
}

# --- Check 1: end-to-end steal-and-correct ---
echo
echo "=== Check 1: a genuinely unknown tab, armed, gets detached and moved ==="
TAG="torture-steal-guard-$$-1"
open -a "Google Chrome" "https://example.com/#$TAG"
sleep 1.5
BEFORE_COUNT=$(osascript -e 'tell application "Google Chrome" to count windows')

DBG_LINES_BEFORE=$(wc -l < ~/.local/state/context/chrome-tabs/steal-guard.debug.log 2>/dev/null || echo 0)

GUARD_ARMED=1 bash -c "
    source <(GUARD_SOURCE_ONLY=1 cat '$GUARD')
    write_last_workspace '$TARGET_WS'
"
GUARD_ARMED=1 bash "$GUARD"
sleep 2

AFTER_COUNT=$(osascript -e 'tell application "Google Chrome" to count windows')
FOCUSED_AFTER=$(/opt/homebrew/bin/aerospace list-workspaces --focused)

if [ "$AFTER_COUNT" -eq $((BEFORE_COUNT + 1)) ] && [ "$FOCUSED_AFTER" = "$TARGET_WS" ]; then
    ok "steal corrected: window count +1 ($BEFORE_COUNT -> $AFTER_COUNT), focus landed on $TARGET_WS"
else
    fail "expected window count +1 and focus on $TARGET_WS, got $BEFORE_COUNT -> $AFTER_COUNT windows, focus=$FOCUSED_AFTER"
fi

# The marker file itself is racy to assert on directly: the live
# aerospace.toml wiring (already active, dry-run) fires on the
# correction's own real refocus and consumes/clears the marker as an
# echo within milliseconds -- exactly the mechanism this guard is FOR.
# Check the debug log for corroborating evidence instead of the raw file.
if tail -n +"$((DBG_LINES_BEFORE + 1))" ~/.local/state/context/chrome-tabs/steal-guard.debug.log 2>/dev/null \
        | grep -q "ARMED: correcting"; then
    ok "debug log recorded an ARMED correction for this run"
else
    fail "debug log has no ARMED correction line for this run"
fi

# Re-derive the new window's CGWindowID by title match (win_id namespaces
# don't correlate -- Chrome's own AppleScript id and CGWindowID are
# different spaces, confirmed live 2026-09-26), for cleanup at the end.
NEW_CGID=$(/opt/homebrew/bin/aerospace list-windows --workspace "$TARGET_WS" --app-bundle-id com.google.Chrome --format '%{window-id} %{window-title}' \
    | grep "$TAG\|Example Domain" | head -1 | awk '{print $1}')
if [ -n "$NEW_CGID" ]; then
    ok "located the corrected window for cleanup (id $NEW_CGID)"
else
    fail "could not locate the corrected window in $TARGET_WS for cleanup"
fi

# --- Check 2: the guard's own refocus does not loop ---
echo
echo "=== Check 2: re-entrancy -- running the guard again right after must be a no-op ==="
COUNT_BEFORE_RERUN=$(osascript -e 'tell application "Google Chrome" to count windows')
GUARD_ARMED=1 bash "$GUARD"
sleep 1
COUNT_AFTER_RERUN=$(osascript -e 'tell application "Google Chrome" to count windows')
if [ "$COUNT_AFTER_RERUN" -eq "$COUNT_BEFORE_RERUN" ]; then
    ok "re-running the guard right after a correction did not create another window ($COUNT_AFTER_RERUN windows, unchanged)"
else
    fail "expected window count to stay at $COUNT_BEFORE_RERUN after a re-run, got $COUNT_AFTER_RERUN"
fi

# --- Check 3: lock prevents a concurrent second correction ---
echo
echo "=== Check 3: correction.lock blocks a concurrent correction attempt ==="
/bin/mkdir "$LOCKDIR" 2>/dev/null
LOCK_TEST_OUT=$(GUARD_ARMED=1 bash -c "
    source <(GUARD_SOURCE_ONLY=1 cat '$GUARD')
    acquire_correction_lock && echo UNEXPECTED_ACQUIRED || echo BLOCKED
")
if [ "$LOCK_TEST_OUT" = "BLOCKED" ]; then
    ok "a held correction.lock blocks a second acquire attempt"
else
    fail "expected a held lock to block a second acquire, got: $LOCK_TEST_OUT"
fi
/bin/rmdir "$LOCKDIR" 2>/dev/null

# --- Restore original state ---
echo
echo "=== Restoring: closing the disposable test window, refocusing the original workspace ==="
if [ -n "$NEW_CGID" ]; then
    close_by_cgid "$NEW_CGID"
    sleep 0.5
fi
/opt/homebrew/bin/aerospace workspace "$ORIGINAL_WS" >/dev/null 2>&1
FINAL_COUNT=$(osascript -e 'tell application "Google Chrome" to count windows')
FOCUSED_FINAL=$(/opt/homebrew/bin/aerospace list-workspaces --focused)
if [ "$FINAL_COUNT" -eq "$BEFORE_COUNT" ] && [ "$FOCUSED_FINAL" = "$ORIGINAL_WS" ]; then
    ok "restored to $BEFORE_COUNT Chrome windows and the original workspace ($ORIGINAL_WS)"
else
    fail "restore incomplete: windows=$FINAL_COUNT (expected $BEFORE_COUNT) focus=$FOCUSED_FINAL (expected $ORIGINAL_WS)"
fi

echo
echo "torture-steal-guard: $pass checks passed, $fail_count failed"
[ "$fail_count" -eq 0 ]
