#!/bin/bash
# Regenerate the picker's pre-rendered rows.
#
# WHY THIS EXISTS: the loop renders the rows after each dismissal, so anything
# that changed the focused workspace by OTHER means -- space-tab, an aerospace
# hotkey, clicking a window -- left the panel showing a stale current row, a
# stale set of dots and a stale order. AeroSpace already runs callbacks on
# focus change, so the cache is refreshed from there: event-driven, and it adds
# nothing to the hotkey's path.
#
# Called from `exec-on-workspace-change` in aerospace.toml, which only fires
# when the focused workspace actually changed.

set -u

: "${CTX:=/Users/petermariani/projects/context-based-mac/bin/context}"
: "${STATE:=/Users/petermariani/.local/state/context}"
PRE="$STATE/picker.prerendered"
LOCK="$STATE/picker.refresh.lock"

/bin/mkdir -p "$STATE"

# DEBOUNCE. on-focus-changed fires on every window focus change, not just
# workspace changes, and each refresh is a ~120ms Python start. Cycling windows
# with space-tab would otherwise spawn one per keypress. mkdir is the atomic
# test-and-set; the trap releases it even if the render fails.
if ! /bin/mkdir "$LOCK" 2>/dev/null; then
    exit 0
fi
trap '/bin/rmdir "$LOCK" 2>/dev/null' EXIT

# Note where focus actually is BEFORE rendering, so the rows we render already
# reflect it. `enter` used to be the MRU's only writer, which made the picker's
# row 2 -- the row its cursor starts on -- "the last place you entered from the
# picker" rather than "the place you were just in".
"$CTX" record-focus >/dev/null 2>&1

# Write to a temp file and RENAME. The loop reads this file with `cat` at show
# time, so a partial write would be read as truncated rows -- and the records
# are NUL-framed, so a torn final record is a corrupt row rather than a
# missing one.
TMP="$PRE.$$"
if "$CTX" pick --rows --source contexts >"$TMP" 2>/dev/null && [ -s "$TMP" ]; then
    /bin/mv -f "$TMP" "$PRE"
else
    /bin/rm -f "$TMP"
fi

# RETIRE THE FZF THAT IS HOLDING THE OLD ROWS.
#
# In prerender mode the loop starts fzf immediately after a dismissal, so
# fzf reads this file ONCE, then sits on the hidden panel waiting. Updating
# the file cannot reach it -- the rows you see are "as of the last
# dismissal". That is invisible when you arrive somewhere THROUGH the
# picker, because the dismissal restarts fzf; it shows up when you switch
# workspaces any other way (space-w to an ambient room, space-tab), where
# nothing restarts it and the current row is a switch behind until the
# second open.
#
# SIGTERM is the signal precisely so the loop can tell this from a user
# dismissal and not toggle the hidden panel back on. The panel is hidden
# while this runs, so the restart is invisible.
#
# Walked down from the loop's own pid, NEVER matched on the command line:
# fzf-lua runs fzf inside nvim and killing that would be a real loss.
# Unconditional now: this script only runs from exec-on-workspace-change, so
# AeroSpace itself already guarantees the workspace changed by the time we
# get here -- there is nothing left to compare against.
loop_pid=$(/bin/cat "$STATE/picker.loop.pid" 2>/dev/null)
if [ -n "${loop_pid:-}" ]; then
    # Written BEFORE the kill: fzf traps SIGTERM and exits 130, exactly as
    # it does for Esc, so the loop cannot tell them apart by status.
    /usr/bin/touch "$STATE/picker.retired"
    for kid in $(/usr/bin/pgrep -P "$loop_pid" 2>/dev/null); do
        # Both levels: fzf is a direct child while the loop pipes straight
        # into it, but a grandchild under any shell that adds a subshell.
        # And `ps -o comm=` gives the FULL PATH, so match on the basename.
        for cand in "$kid" $(/usr/bin/pgrep -P "$kid" 2>/dev/null); do
            case "$(/bin/ps -o comm= -p "$cand" 2>/dev/null)" in
                */fzf|fzf) /bin/kill -TERM "$cand" 2>/dev/null ;;
            esac
        done
    done
fi

# Hold the lock a moment longer than the render, so a burst of focus events
# collapses into one refresh rather than a queue of them.
/bin/sleep 0.4
