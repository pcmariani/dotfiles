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
PENDING="$STATE/picker.refresh.pending"

/bin/mkdir -p "$STATE"

# DIAGNOSTIC LOG, kept deliberately while the cmd-tab fix is on probation.
#
# NO SCRIPTED REPRODUCER REACHES THIS FAILURE -- three were written and all
# three passed against code that was provably broken, because the real gesture
# goes cmd-tab -> paneld -> fzf -> `context enter`, and that fires this hook
# mid-ladder with a verb in flight. The keyboard is the only oracle, so the
# script has to say what it did or a recurrence is undiagnosable.
#
# Costs four `date` forks per workspace change, inside a script that already
# starts Python twice. It is off the hotkey path entirely.
#
# TO REMOVE once this has been quiet for a while: delete this block, the `dbg`
# calls, and $STATE/picker-refresh.debug.log.
DBG="$STATE/picker-refresh.debug.log"
# Self-capping, so an always-on log cannot become an unbounded file. Checked
# once per invocation, which is once per workspace change.
if [ -f "$DBG" ] && [ "$(/usr/bin/wc -l < "$DBG")" -gt 2000 ]; then
    /usr/bin/tail -n 500 "$DBG" > "$DBG.trim" 2>/dev/null && /bin/mv -f "$DBG.trim" "$DBG"
fi
dbg() { printf '%s pid=%-6s %s\n' "$(date +%H:%M:%S.%N | cut -c1-12)" "$$" "$*" >> "$DBG"; }

# How long this refresh chain may keep re-running before it gives up, as an
# absolute epoch second inherited across re-execs. TIME, not a pass count: a
# count of 3 was tried on 2026-09-12 and a human toggling cmd-tab exhausted it
# in under three seconds, at which point the chain exited KNOWING the cache was
# stale -- which is the one outcome that must never happen (see the trapdoor
# note at the bottom). Exhausting this needs ~25s of continuous switching.
: "${REFRESH_DEADLINE:=$(( $(date +%s) + 25 ))}"

# DEBOUNCE. on-focus-changed fires on every window focus change, not just
# workspace changes, and each refresh is a ~120ms Python start. Cycling windows
# with space-tab would otherwise spawn one per keypress. mkdir is the atomic
# test-and-set; the trap releases it even if the render fails.
#
# A DENIED HOOK MUST LEAVE A TRACE, AND THIS IS THE WHOLE FIX. Until 2026-09-12
# it just `exit 0`d, so the workspace change it was reporting was lost outright
# -- and because the holder had already written the cache for the PREVIOUS
# workspace, the loss was silent and permanent. Now it records that work
# remains and the holder refuses to leave while the flag is set. This costs a
# waiter one file touch: no Python, no render, no fan-out.
if ! /bin/mkdir "$LOCK" 2>/dev/null; then
    : > "$PENDING"
    dbg "LOCK-DENIED -> PENDING set (work preserved)"
    exit 0
fi
trap '/bin/rmdir "$LOCK" 2>/dev/null' EXIT
dbg "LOCK-ACQUIRED deadline_in=$(( REFRESH_DEADLINE - $(date +%s) ))s"

# CLEAR THE FLAG BEFORE READING FOCUS, NEVER AFTER. Anything that arrives from
# here on must survive into the settle check below; clearing it later would
# swallow exactly the hooks this exists to catch.
/bin/rm -f "$PENDING"

# WHERE FOCUS IS AS WE START RENDERING. Compared against live focus at the end
# of the script to decide whether our render is still describing reality -- see
# the SETTLE block at the bottom, which is the whole reason this is captured.
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
# --also-live, added for Task 7: writes the switcher's filtered cache
# (picker.prerendered.live) from the SAME render as the main cache below --
# one `context pick` call producing two files rather than two renders. The
# switcher's `workspaces`-sharing producers (pickers.toml) read that file on
# both the arm and the reveal poke; this is the only place it is written.
if "$CTX" pick --rows --source contexts \
        --also-live "$STATE/picker.prerendered.live" >"$TMP" 2>/dev/null \
        && [ -s "$TMP" ]; then
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
    # `files` since 2026-09-19 (Spec E amendment): it is armed now, and its
    # rows -- and the root file scripts/reveal-files.sh reads -- follow the
    # focused workspace by this rearm, the same way the picker's rows do.
    for panel in switcher picker move files; do
        "$PANELD" rearm "$panel" >/dev/null 2>&1 || true
    done
fi

# Hold the lock a moment longer than the render, so a burst of focus events
# collapses into one refresh rather than a queue of them.
/bin/sleep 0.4

# SETTLE, OR RUN AGAIN. THE DEBOUNCE ABOVE USED TO DROP REFRESHES OUTRIGHT --
# a hook that could not take the lock exited 0 and the workspace change it was
# reporting was lost. That is correct for the case the debounce was written for
# (space-tab cycling WINDOWS inside one workspace, where every event renders
# identical rows) and WRONG for a workspace change, whose whole point is that
# the rows must change.
#
# THE BUG IT CAUSED, 2026-09-12, reported as "cmd-tab gets stuck on its own
# workspace after the first 2,3,4 presses". The lock is held ~0.9s but the
# render FINISHES AT ~0.3s -- the tail is the three rearms plus the sleep
# above. So a switch landing in that stretch was dropped AFTER the cache had
# already been written for the workspace just left.
#
# AND IT IS A ONE-WAY TRAPDOOR, WHICH IS WHY IT STICKS RATHER THAN FLICKERING.
# A stale cache puts the workspace you are standing in on ROW 2, which is where
# cmd-tab's cursor starts (`load:down`), so Enter re-enters the workspace you
# are already in -- and AeroSpace fires NO `exec-on-workspace-change` for a
# no-op switch (verified: "Workspace 'x' is already focused", cache mtime
# unchanged). Nothing else ever rewrites the cache, so every subsequent cmd-tab
# self-switches until you change workspace by some other means. THAT is why
# ending a pass stale is unacceptable rather than merely untidy: there is no
# next event to clean up after us.
#
# RELEASE THE LOCK BEFORE DECIDING, AND THIS ORDER IS LOAD-BEARING. The first
# attempt at this fix kept the lock until after the check, and the instrumented
# log showed the decisive hook arriving 2ms into that window and being denied:
#
#   47.808 depth=2  focus moved under us     <- we knew the cache was stale
#   47.838 depth=2  exited anyway            <- pass budget exhausted
#   47.840 pid=74611 LOCK-DENIED -> dropped  <- the hook that would have fixed it
#
# Releasing first means a concurrent hook can win the lock and do exactly the
# work we were about to do; our own re-exec then finds the lock taken, records
# PENDING and exits, and that winner picks it up. Either way the work survives.
/bin/rmdir "$LOCK" 2>/dev/null
trap - EXIT

# Two independent reasons to go round again, and BOTH are needed. PENDING
# catches a hook that fired and was denied. The focus comparison catches a
# change that produced no usable hook at all -- belt and braces, because the
# whole failure mode here is a lost notification.
FOCUS_AFTER=$("$AEROSPACE" list-workspaces --focused 2>/dev/null)
dbg "SETTLE-CHECK pending=$([ -e "$PENDING" ] && echo yes || echo no) before=$FOCUS_BEFORE after=$FOCUS_AFTER cache=$(tr '\0' '\n' < "$PRE" 2>/dev/null | head -1 | awk -F'\t' '{print $1}')"
if [ -e "$PENDING" ] || [ "$FOCUS_BEFORE" != "$FOCUS_AFTER" ]; then
    if [ "$(date +%s)" -lt "$REFRESH_DEADLINE" ]; then
        dbg "RE-EXEC (work remains)"
        REFRESH_DEADLINE="$REFRESH_DEADLINE" exec "$0"
    fi
    dbg "!!! DEADLINE EXHAUSTED WHILE STALE -- this is the trapdoor"
fi
dbg "SETTLED cache=$(tr '\0' '\n' < "$PRE" 2>/dev/null | head -1 | awk -F'\t' '{print $1}') live=$FOCUS_AFTER"

# The reproducer and regression check is
# docs/experiments/2026-09-12-picker-cache-staleness.sh in context-based-mac.
# RE-RUN IT AFTER ANY CHANGE TO THIS FILE, and note it drives switches with
# `aerospace workspace` -- the FIRST fix passed it while the real gesture still
# failed, because cmd-tab goes through `context enter`, which fires this hook
# mid-ladder while paneld holds a verb in flight. A green sweep is necessary
# and NOT sufficient: press the key as well.
