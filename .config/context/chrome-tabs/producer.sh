#!/bin/sh
# Producer for the "chrome-tabs" picker (pickers.toml + paneld.toml,
# cmd-backtick).
#
# Reads the LAST poll (rank.py over cache.json), then reformats its own
# "win_id<TAB>index<TAB>display" lines into "win_id:index<TAB>display"
# NUL-terminated records -- the "value-tab-display" shape
# context/picker_cli.py's compose() expects. BASE_FLAGS always passes
# `--read0 --print0` to fzf regardless of which picker it composes, so
# EVERY producer must NUL-frame its rows, not just context's own.
#
# poll.py is NO LONGER fired from here, 2026-09-28 -- REMOVED, not just
# backgrounded. It used to run IN THE BACKGROUND on every single arm of
# this panel (every real Chrome focus change, now that chrome-tabs is
# properly rearmed -- see HANDOFF.md), which turned out to be pure
# self-inflicted contention: poll.py's own LaunchAgent
# (~/Library/LaunchAgents/com.petermariani.chrome-tab-poll.plist) is
# ALREADY loaded and running it independently every 20s (confirmed live:
# `launchctl list | grep chrome-tab-poll` shows it loaded, and its own
# log shows healthy activity -- the plist's own comment calling it "NOT
# LOADED by default" due to a Chrome-Automation-permission problem is
# stale; that permission issue is evidently resolved and it has been
# running fine). Every EXTRA fire from here bought nothing (cache.json's
# frecency data doesn't need sub-second freshness -- it only feeds row
# 2's "most recent alternate" ranking) and cost a real, measured latency
# regression: Chrome's Apple Event dispatcher is effectively
# single-threaded across ALL concurrent callers, so a poll.py run in
# flight (a FULL enumeration of every tab in every window, more
# expensive than active-now.py's own single-active-tab-per-window scan)
# made the user-visible `active-now.py` call queue behind it -- this is
# the exact live symptom reported as "switch to another chrome instance,
# nothing happens on the first try, then it switches after that."
# Removing this trigger (not just re-throttling it) leaves cache.json's
# freshness exactly where it was before this whole feature existed: the
# LaunchAgent's own 20s cadence, unrelated to and unaffected by how often
# this panel itself is used.
set -u

PY=/Users/petermariani/.local/share/mise/installs/python/3.12/bin/python3
DIR=/Users/petermariani/.config/context/chrome-tabs

# active-now.py ALSO BACKGROUNDED, not called synchronously -- changed
# live 2026-09-26, the same day the user reported "doesn't respond when I
# hammer... speed is the product". Real, MEASURED bug: this script used
# to call active-now.py synchronously, right here, and active-now.py
# costs 0.75-0.84s per call (two `aerospace` round trips plus one
# `osascript` enumeration of every Chrome window's active tab) --
# blocking rank.py's own output from reaching fzf for most of a second.
# The panel's reveal_delay_ms (300ms) fires well before that finishes, so
# the panel appeared EMPTY for the rest of that stretch, and cycle
# keypresses sent during it landed on a not-yet-populated fzf and were
# silently discarded by paneld's `sendCycleKey` -- reading exactly like
# "hammering does nothing", the same failure mode `windows`' own
# paneld.toml comment already documented for a different cause.
#
# Fixed the same way poll.py's own full enumeration already is:
# backgrounded, writing its answer to fresh.tsv (see active-now.py's own
# `write_fresh_file`) for THIS script to read with a plain `cat` instead
# of waiting on a live subprocess chain. `cat` on a missing file (first
# run ever, before any background fire has completed) prints nothing and
# exits non-zero, silenced by `2>/dev/null` -- `fresh` is then empty and
# CHROME_FRESH_FRONT_WIN/_ACTIVE_TAB stay unset, which rank.py already
# falls back on gracefully (cache.json's own front_win/active flags).
# active-now.py's own flock makes a background fire that finds one
# already running exit immediately rather than piling up, same as
# poll.py's guard above.
#
# active-now.sh (Chrome's own AppleScript "window 1") is RETIRED, not
# deleted -- kept beside this file as a documented mistake. Real bug,
# found live 2026-09-25: Chrome's "front window" is Chrome's OWN internal
# focus history, unrelated to which monitor/AeroSpace workspace the user
# is actually looking at. Reproduced exactly: invoking the switcher from
# Chrome in the current workspace targeted a completely different Chrome
# window on another monitor, because THAT window happened to be Chrome's
# "window 1" from earlier testing -- and every later switch stayed
# locked to the wrong window, because nothing re-evaluated which one was
# correct. active-now.py asks AeroSpace which Chrome window is in the
# FOCUSED workspace instead, which is what actually matches the user's
# intent.
("$PY" "$DIR/active-now.py" >/dev/null 2>&1 &) </dev/null >/dev/null 2>&1

# wait-for-fresh.py (added 2026-09-27) replaces a plain `cat` here -- the
# race this fixes: active-now.py is backgrounded above and this used to
# read fresh.tsv IMMEDIATELY after, with no wait, so a run already in
# flight (~0.75-0.84s) got raced and its answer read before it landed.
# ALWAYS waits, bounded (WAIT_BUDGET_S in wait-for-fresh.py, currently
# 1.5s), for fresh.tsv to reflect something computed no earlier than the
# wait's own start -- not gated on "did something recently change" (a
# first version tried that via record-window-focus.sh's window-recent
# log and had its own cross-process ordering race; see wait-for-fresh.py's
# own docstring). Safe to always wait: this script only ever runs at REARM
# time for the `chrome-tabs` panel, never synchronously on the keypress
# itself, so there is no reveal-latency budget to protect here at all.
fresh="$("$PY" "$DIR/wait-for-fresh.py")"
# ONE env var holding the WHOLE multi-line "win_id<TAB>tab_id" blob
# (2026-09-28, per-workspace rewrite -- see active-now.py's own docstring):
# there can now be zero, one, or several active-tab pairs (one per Chrome
# window in the focused workspace), where the old single-window scope only
# ever had one. A shell env var can hold embedded newlines just fine --
# the shell never re-splits an inherited variable's VALUE, only its own
# expansions -- so rank.py reads this back with a plain os.environ.get()
# and splits on newlines itself, no temp file or second IPC channel
# needed. Replaces the old CHROME_FRESH_FRONT_WIN/CHROME_FRESH_ACTIVE_TAB
# pair, which assumed exactly one window.
export CHROME_FRESH_PAIRS="$fresh"

# Shared diagnostic log (switcher_log.py, added 2026-09-27) -- one line
# per picker reveal, so a `tail -f` of switcher.debug.log shows this
# read landing IN ORDER relative to poll.py's/active-now.py's own writes,
# which is exactly what's needed to tell "read a stale answer" from "the
# answer itself was wrong" after the fact. Same date+%N pattern already
# proven working on this machine by picker-refresh.sh's own dbg().
#
# The blob's own embedded newlines are flattened to "; " for this ONE log
# line only (2026-09-28) -- switcher.debug.log is meant to be tailed
# one-event-per-line, and a raw multi-line write here would split what is
# really a single read event across several lines with no marker tying
# them back together.
DBGLOG="$HOME/.local/state/context/chrome-tabs/switcher.debug.log"
fresh_oneline="$(printf '%s' "${fresh:-<empty>}" | tr '\n' ';')"
printf '%s [producer.sh] read fresh.tsv=%s focused_ws=%s\n' \
    "$(date +%H:%M:%S.%N | cut -c1-12)" \
    "$fresh_oneline" "$(/opt/homebrew/bin/aerospace list-workspaces --focused 2>/dev/null)" \
    >> "$DBGLOG" 2>/dev/null

# Reformatting via Python, not awk: this machine's /usr/bin/awk SILENTLY
# DROPS a `\0` escape in printf instead of emitting a NUL byte (verified
# directly, 2026-09-25: `awk '{printf "%s\0", $0}'` on two lines produced
# them run together with no separator at all, not an error) -- awk is not
# a safe tool for NUL-framing on this machine. Python's buffered stdout
# writes the byte correctly.
"$PY" "$DIR/rank.py" | "$PY" -c '
import sys
for line in sys.stdin:
    line = line.rstrip("\n")
    win_id, index, display = line.split("\t", 2)
    sys.stdout.buffer.write(f"{win_id}:{index}\t{display}\0".encode())
'
