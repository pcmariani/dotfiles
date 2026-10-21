#!/bin/bash
# Re-arm the panels whose rows follow the focused workspace, ONCE SWITCHING HAS
# GONE QUIET -- not on every switch.
#
# WHY (2026-10-20, paneld.log with millisecond stamps): picker-refresh.sh used
# to re-arm chrome-tabs, move, files, search and windows right after every
# workspace change, back to back. Each builds a surface and runs a producer, and
# that landed exactly while the cmd-tab switcher was arming for the user's NEXT
# press. Over a burst of 42 switches: the switcher's arm took a median of 481 ms
# when those panels were arming nearby against 238 ms when they were not (max
# 1617 ms); 13 of 42 arms outlasted paneld's fixed 400 ms settle, and 2 presses
# were lost (the held Enter went to an fzf that had not loaded). With only the
# switcher re-armed, the same kind of burst: 0 of 38 arms over 400 ms, max 331 ms,
# 0 lost presses.
#
# HOW: each call takes a token, waits QUIET seconds, and goes ahead only if it
# is still the newest call. A burst of switches therefore re-arms the others once,
# for the workspace you ended on. They are re-armed one at a time, SPACING apart,
# and a newer call stops the sequence part-way.
#
# COST: after a switch these panels keep the previous workspace's rows for about
# QUIET seconds. `windows` and `chrome-tabs` have no reveal-time refresh, so
# opening one inside that window shows the old workspace.
#
# Called detached from picker-refresh.sh. Overridable so a test can stub paneld
# and shorten the waits.

set -u

: "${STATE:=$HOME/.local/state/context}"
: "${PANELD:=$HOME/Applications/paneld.app/Contents/MacOS/paneld}"
: "${QUIET:=1.0}"
: "${SPACING:=0.15}"
: "${PANELS:=chrome-tabs move files search windows}"

TOKEN="$STATE/rearm-others.token"
ME="$$"

/bin/mkdir -p "$STATE"
printf '%s' "$ME" > "$TOKEN"

newest() { [ "$(/bin/cat "$TOKEN" 2>/dev/null)" = "$ME" ]; }

/bin/sleep "$QUIET"
newest || exit 0

[ -x "$PANELD" ] || exit 0
for panel in $PANELS; do
    newest || exit 0
    "$PANELD" rearm "$panel" >/dev/null 2>&1 || true
    /bin/sleep "$SPACING"
done
