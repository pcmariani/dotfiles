#!/usr/bin/env python3
"""Bounded wait between producer.sh backgrounding active-now.py and reading
its answer (fresh.tsv) -- the fix for the still-open half of the
cmd-backtick bug: producer.sh ALWAYS backgrounds active-now.py and used to
read fresh.tsv IMMEDIATELY, without waiting, so a run already in flight
(~0.75-0.84s) got raced and its answer read before it landed. Live-proven
both ways: the exact producer.sh=994907846/994908263 vs
real-active=994907907 trace from one session, and later, with two Chrome
windows in one AeroSpace workspace, a stale read of the OTHER window's tabs
that persisted even after switching focus.

THIRD VERSION, 2026-09-28 morning: the SECOND version (see prior git
history if needed) waited for fresh.tsv's mtime to postdate this script's
OWN start time. That broke the switcher's own TOGGLE/rapid-mash gesture:
`activate.py` already writes fresh.tsv ITSELF, INSTANTLY, the moment a
switch commits (see its own docstring) -- with no AppleScript round trip
needed, well before the on-focus-changed-triggered rearm's own
wait-for-fresh.py call even STARTS. That write can therefore never
postdate this script's start (it happened first), so the second version
always concluded "not caught up yet" and waited out the FULL budget on
every single commit, even though the answer sitting in fresh.tsv was
already exactly right. Live-reproduced: user reported "if I mash
cmd-backtick too quickly it doesn't switch, but waiting ~0.5s works" --
confirmed in switcher.debug.log, a 1.7s gap between activate.py's instant
write and producer.sh's next read, with active-now.py's own concurrent
background run failing to match and leaving fresh.tsv untouched in
between (so nothing ever satisfied the old "must be newer than my start"
condition within budget).

This version drops timestamp comparison entirely and asks the actual
question: is active-now.py's own enumeration CURRENTLY in flight? Reuses
its LOCK_FILE (the same `fcntl.flock(..., LOCK_EX | LOCK_NB)` it already
takes at the top of `main()`, before any AppleScript call). If nothing
holds the lock, whatever is in fresh.tsv right now is the best available
answer -- either a fresh `activate.py` write, or a previously-completed
`active-now.py` run -- read it immediately, no wait. If the lock IS held,
a real computation just started (the one THIS producer.sh invocation's
own background fire kicked off, or one already in flight from a moment
earlier), so wait, bounded, for it to release, then read. No timestamps,
no cross-process ordering to get right, no needless wait when the answer
was already correct.

Bounded by WAIT_BUDGET_S, never blocks forever, and always prints
whatever fresh.tsv holds at the end -- caught up or not, same
"stale-but-present beats nothing" contract active-now.py's own
enumeration-failure path already follows.

See smoke-wait-for-fresh.sh.
"""
import fcntl
import sys
import time
from pathlib import Path

STATE_DIR = Path.home() / ".local/state/context/chrome-tabs"
FRESH_FILE = STATE_DIR / "fresh.tsv"
LOCK_FILE = STATE_DIR / "active-now.lock"

WAIT_BUDGET_S = 1.5
POLL_INTERVAL_S = 0.02


def is_active_now_running():
    """True if active-now.py currently holds LOCK_FILE. Opened "a" (append,
    never truncates) since this only ever probes the lock, never writes
    through it -- active-now.py's own `open(LOCK_FILE, "w")` remains the
    only writer."""
    try:
        fh = open(LOCK_FILE, "a")
    except OSError:
        return False
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.flock(fh, fcntl.LOCK_UN)
        return False
    except BlockingIOError:
        return True
    finally:
        fh.close()


def read_fresh():
    try:
        with open(FRESH_FILE) as f:
            return f.read()
    except OSError:
        return ""


def wait_for_fresh(now=None, sleep=time.sleep, is_running=None):
    """The bounded wait itself, parameterized so tests can drive it without
    a real clock or a real lock file. Returns fresh.tsv's content."""
    if now is None:
        now = time.time
    if is_running is None:
        is_running = is_active_now_running

    deadline = now() + WAIT_BUDGET_S
    while is_running() and now() < deadline:
        sleep(POLL_INTERVAL_S)
    return read_fresh()


def main():
    sys.stdout.write(wait_for_fresh())
    return 0


if __name__ == "__main__":
    sys.exit(main())
