#!/bin/bash
# Regression check for window_title()'s use of Chrome's AppleScript `title
# of window` property, which SILENTLY MIDDLE-TRUNCATES (with a "…") any
# title longer than roughly 62 characters -- confirmed live 2026-09-27,
# independent of frontmost/occlusion state (a window brought to index 1
# and activated still truncates). `title of (active tab of window)` does
# NOT truncate for the same window. This function's return value feeds
# activate.py's isolation gate's startswith() match against AeroSpace's
# own (untruncated) window-title list -- a truncated my_title can never
# be a real prefix match, so the gate FAIL-CLOSED-refuses every activation
# on any window with a title this long. Real, user-reported symptom:
# "switcher is not actually switching tabs."
#
# LIVE test against whatever real Chrome windows are open right now --
# read-only osascript title queries, no state mutation, safe (unlike
# tests-never-touch-real-state.md's concern, which is about STATE FILES).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

win_ids="$(osascript -e 'tell application "Google Chrome" to get id of every window' 2>/dev/null)"
[ -n "$win_ids" ] || { echo "SKIP: no Chrome windows open, cannot test live"; exit 0; }

found_long=0
IFS=', ' read -ra ids <<< "$win_ids"
for wid in "${ids[@]}"; do
    [ -n "$wid" ] || continue
    true_title="$(osascript -e "tell application \"Google Chrome\" to title of (active tab of (window id $wid))" 2>/dev/null)"
    [ -n "$true_title" ] || continue
    got="$(python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('activate_mod', '$HERE/activate.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(m.window_title($wid) or '')
")"
    if [ "${#true_title}" -gt 62 ]; then
        found_long=1
        if [ "$got" = "$true_title" ]; then
            ok "window_title($wid) returns the full untruncated title (len ${#true_title})"
        else
            fail "window_title($wid) returned $(printf '%q' "$got") but the real tab title is $(printf '%q' "$true_title") (len ${#true_title}) -- truncated"
        fi
    fi
done

[ "$found_long" -eq 1 ] || { echo "SKIP: no currently open window has a title >62 chars to exercise the bug"; exit 0; }
echo "smoke-window-title: $pass checks passed"
