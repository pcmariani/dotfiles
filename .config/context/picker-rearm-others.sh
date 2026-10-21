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
# TWO TIERS (same evening, after the user: "the list for windows is way too slow
# in updating"). Only `windows` and `chrome-tabs` NEED a prompt re-arm: they have
# no reveal-time refresh, so the armed list is all they ever show. `move`, `files`
# and `search` re-produce their rows when opened (on_reveal_key + refresh), so
# their re-arm is housekeeping and can wait. The first debounce treated all five
# alike and put `windows` LAST, about 1.6 s after the switch plus its own 0.4 s
# arm. Now: FAST panels QUIET_FAST seconds after the call, SLOW panels
# QUIET_SLOW seconds after it.
#
# COST: after a switch the FAST panels keep the previous workspace's rows for
# about QUIET_FAST seconds plus their arm. Opening one inside that window shows
# the old workspace.
#
# Called detached from picker-refresh.sh. Overridable so a test can stub paneld
# and shorten the waits.

set -u

: "${STATE:=$HOME/.local/state/context}"
: "${PANELD:=$HOME/Applications/paneld.app/Contents/MacOS/paneld}"
: "${QUIET_FAST:=0.5}"
: "${QUIET_SLOW:=1.2}"
: "${SPACING:=0.12}"
: "${FAST_PANELS:=windows chrome-tabs}"
: "${SLOW_PANELS:=move files search}"

TOKEN="$STATE/rearm-others.token"
ME="$$"

/bin/mkdir -p "$STATE"
printf '%s' "$ME" > "$TOKEN"

newest() { [ "$(/bin/cat "$TOKEN" 2>/dev/null)" = "$ME" ]; }

rearm_all() {
    for panel in $1; do
        newest || exit 0
        "$PANELD" rearm "$panel" >/dev/null 2>&1 || true
        /bin/sleep "$SPACING"
    done
}

[ -x "$PANELD" ] || exit 0

/bin/sleep "$QUIET_FAST"
newest || exit 0
rearm_all "$FAST_PANELS"

# The slow tier waits until QUIET_SLOW after the call, not after the fast tier.
/bin/sleep "$(awk -v slow="$QUIET_SLOW" -v fast="$QUIET_FAST" -v n="$(echo $FAST_PANELS | wc -w)" -v sp="$SPACING" \
    'BEGIN { d = slow - fast - n * sp; if (d < 0) d = 0; print d }')"
newest || exit 0
rearm_all "$SLOW_PANELS"
