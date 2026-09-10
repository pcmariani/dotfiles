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
# RETIRED 2026-09-05, with the Ghostty terminal picker itself. What stood here
# read $STATE/picker.loop.pid, touched a retirement marker, and walked two
# levels of pgrep to SIGTERM the loop's fzf without ever matching on a command
# line -- fzf-lua runs fzf inside nvim and killing that would be a real loss.
#
# paneld needs none of it. It owns its child, so a rearm's surface rebuild
# takes the whole process group by SIGHUP on pty close -- measured against a
# forked grandchild. There is no pid to read, no marker to write, and no
# ambiguity between a SIGTERM and an Esc for the marker to resolve, because
# the generation on the exit notification says which arm it belongs to.
#
# The lesson the walk encoded is not retired, only its mechanism: never match
# a kill on a command line. paneld cannot, having no kill to make.

# paneld holds its OWN armed fzf, and that fzf read these rows with `cat` at
# arm time -- so rewriting the file changes nothing it can see. Without this
# call the panel shows the MRU as it stood at paneld's last arm, which is the
# same staleness this whole script exists to prevent for the predecessor.
#
# It cannot interrupt anything: paneld defers a rearm while a verb is in
# flight and while the panel is visible, and fires it on the next exit. That
# matters here specifically, because `context enter` CHANGES THE WORKSPACE and
# so triggers this script mid-ladder.
#
# Non-fatal by construction: paneld may not be installed or running, and the
# rows above are still worth rendering either way -- `context record-focus`
# and the prerender are the parts nothing else does.
PANELD="${PANELD:-$HOME/Applications/paneld.app/Contents/MacOS/paneld}"
if [ -x "$PANELD" ]; then
    # EVERY panel whose producer reads picker.prerendered needs telling, not
    # just the picker. Rearming re-runs the producer, and the producer here is
    # `cat picker.prerendered` -- so a panel that is not rearmed keeps the rows
    # it captured whenever it last armed.
    #
    # `switcher` added 2026-09-10 and it is not cosmetic there: its whole
    # premise is that row 2 is the workspace you were just in. Without this
    # line its rows freeze until its next use, and cmd-tab rotates among
    # whichever few workspaces happened to be recent at each arm rather than
    # going to the previous one. Found by hand; nothing tests it.
    #
    # `move` added 2026-09-10 for the same reason, found by re-reading rather
    # than by being bitten: its producer is `cat picker.prerendered` too, so
    # it had been showing rows frozen at its own last use all along.
    for panel in picker switcher move; do
        "$PANELD" rearm "$panel" >/dev/null 2>&1 || true
    done
fi

# Hold the lock a moment longer than the render, so a burst of focus events
# collapses into one refresh rather than a queue of them.
/bin/sleep 0.4
