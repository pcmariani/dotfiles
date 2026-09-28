#!/bin/sh
# Gate for on-focus-changed's Chrome-touching work (active-now.py's
# proactive refresh, `paneld rearm chrome-tabs`) -- added 2026-09-28 after
# a live, measured contention problem: on-focus-changed fires on EVERY
# window focus change anywhere on the machine (record-window-focus.sh's
# own docstring: "one window fired 4x in a row" just from an app
# re-raising itself), and both of those actions used to fire
# UNCONDITIONALLY, including for focus changes that have nothing to do
# with Chrome at all (Finder, Ghostty, anything).
#
# Each of those triggers a real `producer.sh` run, which ALSO backgrounds
# poll.py's own full tab enumeration -- measured live: this log's poll.py
# start count (2149) vs active-now.py start count (319) in the same
# window, almost 7x more poll.py fires than were ever relevant. Chrome's
# Apple Event dispatcher is effectively single-threaded across ALL
# concurrent AppleScript callers, so a poll.py run in flight when a
# genuinely relevant active-now.py/activate.py call fires makes THAT call
# queue behind it -- this is the documented mechanism already in poll.py's
# own docstring (a measured 33s stall case from two overlapping callers),
# and it is what turned active-now.py's own isolated ~40-60ms enumeration
# cost (confirmed live, uncontended) into the 0.8-1.1s completions visible
# throughout switcher.debug.log. The fix is not to make any one call
# faster -- they already are -- it's to stop firing them at all for focus
# changes Chrome was never involved in.
#
# Cheap check: `aerospace list-windows --focused` is a native AeroSpace
# query, no AppleScript, no Chrome round trip -- measured live at
# ~30-60ms, negligible next to the ~150-200ms+ this gate is trying to
# avoid triggering unnecessarily.
set -u

FOCUSED_APP="$(/opt/homebrew/bin/aerospace list-windows --focused --format '%{app-bundle-id}' 2>/dev/null)"
[ "$FOCUSED_APP" = "com.google.Chrome" ] || exit 0

/Users/petermariani/.local/share/mise/installs/python/3.12/bin/python3 \
    /Users/petermariani/.config/context/chrome-tabs/active-now.py >/dev/null 2>&1 &
/Users/petermariani/Applications/paneld.app/Contents/MacOS/paneld rearm chrome-tabs >/dev/null 2>&1
