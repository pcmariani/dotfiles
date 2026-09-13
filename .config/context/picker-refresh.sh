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
: "${AEROSPACE:=/opt/homebrew/bin/aerospace}"
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

# WHERE FOCUS IS AS WE START RENDERING. Compared against live focus at the end
# of the script to decide whether our render is still describing reality -- see
# the COALESCE block at the bottom, which is the whole reason this is captured.
FOCUS_BEFORE=$("$AEROSPACE" list-workspaces --focused 2>/dev/null)

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
    # SWITCHER FIRST, deliberately. Its producer is a cached `cat` (~0ms)
    # while picker's and move's each run the agent-status join (100-210ms at
    # 9 herdr sessions, 2026-09-10). cmd-tab is the fast toggle and the one
    # whose latency is felt, so it should not be asked to rebuild between the
    # two slow ones. paneld does its panel work on the main queue, so this can
    # only help or be neutral -- it is a mitigation, not a proven fix.
    for panel in switcher picker move; do
        "$PANELD" rearm "$panel" >/dev/null 2>&1 || true
    done
fi

# Hold the lock a moment longer than the render, so a burst of focus events
# collapses into one refresh rather than a queue of them.
/bin/sleep 0.4

# COALESCE. THE DEBOUNCE ABOVE DROPS REFRESHES, IT DOES NOT QUEUE THEM -- a
# hook that cannot take the lock exits 0 and is gone. That is correct for the
# case the debounce was written for (space-tab cycling WINDOWS inside one
# workspace, where every event would render identical rows) and WRONG for a
# workspace change, whose whole point is that the rows must change.
#
# THE BUG IT CAUSED, 2026-09-12, reported as "cmd-tab gets stuck on its own
# workspace after the first 2,3,4 presses". The lock is held ~0.9s but the
# render FINISHES AT ~0.3s -- the tail is the three rearms plus the sleep
# above. So there is a ~0.3-0.5s stretch in which the cache has ALREADY been
# written for the workspace you just left and the lock is STILL held, and a
# switch landing there is dropped after the damage is done. Measured: stale at
# gaps of 0.3s and 0.5s, clean at 0.0, 0.2, 0.7, 0.9 and 1.2s. (Too EARLY is
# harmless -- the render reads focus live at ~120ms and simply picks up the
# newer workspace. Too late and the lock is free.)
#
# AND IT IS A ONE-WAY TRAPDOOR, WHICH IS WHY IT "STICKS" RATHER THAN
# FLICKERING. A stale cache puts the workspace you are standing in on ROW 2,
# which is where cmd-tab's cursor starts (`load:down`), so Enter re-enters the
# workspace you are already in -- and AeroSpace fires NO
# `exec-on-workspace-change` for a no-op switch (verified: "Workspace 'x' is
# already focused", cache mtime unchanged). So nothing ever rewrites the cache
# and every subsequent cmd-tab self-switches, until you change workspace by
# some other means.
#
# So: if focus moved while we held the lock, that change's own hook was
# dropped and we are the only one who can still act on it. Release and run
# again. Releasing FIRST is deliberate -- if a real hook beats us to the lock
# it does exactly the work we were about to do, and our re-exec then exits 0
# at the lock, which is the right outcome either way.
#
# Bounded at 3 total passes so a user holding down a switch key cannot pin the
# lock indefinitely. Exhausting the bound needs ~3s of continuous switching,
# and the next settled workspace change refreshes normally.
#
# The reproducer is `docs/experiments/2026-09-12-picker-cache-staleness.sh` in
# the context-based-mac repo. RE-RUN IT AFTER ANY CHANGE TO THIS FILE: the
# failure is invisible at the keyboard, because the list is drawn, the cursor
# is on row 2, Enter is delivered and a workspace IS entered. Nothing errors.
FOCUS_AFTER=$("$AEROSPACE" list-workspaces --focused 2>/dev/null)
if [ "$FOCUS_BEFORE" != "$FOCUS_AFTER" ] && [ "${REFRESH_DEPTH:-0}" -lt 2 ]; then
    /bin/rmdir "$LOCK" 2>/dev/null
    trap - EXIT
    REFRESH_DEPTH=$(( ${REFRESH_DEPTH:-0} + 1 )) exec "$0"
fi
