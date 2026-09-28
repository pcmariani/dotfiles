#!/usr/bin/env python3
"""One-shot poll of Chrome's open tabs, for a cron-style caller to re-run
every few seconds (see poll-loop.sh / the LaunchAgent this project's docs
describe but does NOT install automatically).

Two files, both under ~/.local/state/context/chrome-tabs/:

  cache.json     -- EVERY open tab right now (window id, tab index, tab id,
                     title, url, whether it's the active tab of the front
                     window). Overwritten whole on every poll. This is what
                     the picker reads, so an on-demand pick never pays the
                     ~1.6-1.8s live-enumeration cost measured 2026-09-25
                     (osascript, 8 windows / 29 tabs, id+title+url) --
                     it is however many seconds stale as the poll interval.

  frecency.json  -- one row per URL ever seen as the FRONT window's active
                     tab: {"count": N, "last_seen": epoch_seconds,
                     "title": last-known-title}. A row is written ONLY on
                     a transition -- the active tab changing from the
                     previous poll -- not on every poll that finds the same
                     tab still active. That is the deliberate difference
                     between "recency of USE" (this) and "most recently
                     opened" or "most continuously focused" (this is
                     neither): a tab you switch to and back from twice
                     scores twice; a tab you sit on for an hour scores once.
                     "_last_active_url" inside the same file is poll.py's
                     own transition-detection state, not a real row --
                     rank.py skips keys starting with "_".

Real numbers from this project (measured 2026-09-25, not assumed): full
enumeration with id+title+url costs 1.6-1.8s for 8 windows/29 tabs; the
SAME script asking only for ids costs ~0.6-0.8s; a single active-tab-only
query (used nowhere here, but proves the floor) costs ~0.18s. Full
enumeration's cost is Apple Events round-trips per tab property access, not
`osascript` process-spawn overhead -- timed identically whether invoked as
a bare `osascript` process or via Hammerspoon's in-process
hs.osascript.applescript (both ~1.6s), which is why this poller, not the
on-demand picker, pays that cost.
"""
import fcntl
import json
import subprocess
import sys
import time
from pathlib import Path

STATE_DIR = Path.home() / ".local/state/context/chrome-tabs"
CACHE_FILE = STATE_DIR / "cache.json"
FRECENCY_FILE = STATE_DIR / "frecency.json"
LOCK_FILE = STATE_DIR / "poll.lock"

ENUMERATE_SCRIPT = '''
tell application "Google Chrome"
    set AppleScript's text item delimiters to "\\t"
    set out to {"__FRONT__" & (id of window 1)}
    set winIdx to 0
    repeat with w in windows
        set winIdx to winIdx + 1
        set frontActiveId to (id of active tab of w)
        set tabIdx to 0
        repeat with t in tabs of w
            set tabIdx to tabIdx + 1
            set isActive to "0"
            if winIdx is 1 and (id of t) is frontActiveId then set isActive to "1"
            set end of out to ((id of w) as text) & "\\t" & (tabIdx as text) & "\\t" & ((id of t) as text) & "\\t" & isActive & "\\t" & (title of t) & "\\t" & (URL of t)
        end repeat
    end repeat
    set AppleScript's text item delimiters to "\\n"
    return out as text
end tell
'''


def enumerate_tabs():
    """(front_win, rows), or (None, None) on failure.

    `front_win` is `window 1`'s id at THIS poll -- Chrome's own AppleScript
    `windows` list is front-to-back ordered, so window 1 is whichever
    window was frontmost at the moment this ran. Returned separately from
    `rows` (which still holds every window's tabs) rather than filtering
    here, so callers that want "every open tab" and callers that want
    "just the front window's tabs" (rank.py, per the user's 2026-09-25
    decision: scope the switcher to the focused Chrome window, not every
    window, not per-AeroSpace-workspace) both read the one poll.
    """
    try:
        proc = subprocess.run(
            ["osascript", "-e", ENUMERATE_SCRIPT],
            capture_output=True, text=True, timeout=10,
        )
    except subprocess.TimeoutExpired:
        return None, None
    if proc.returncode != 0:
        return None, None
    front_win = None
    rows = []
    for line in proc.stdout.splitlines():
        if line.startswith("__FRONT__"):
            front_win = line[len("__FRONT__"):]
            continue
        parts = line.split("\t")
        if len(parts) < 6:
            continue
        win_id, tab_idx, tab_id, is_active, title, url = (
            parts[0], parts[1], parts[2], parts[3], parts[4],
            "\t".join(parts[5:]),
        )
        rows.append({
            "win": win_id,
            "index": int(tab_idx),
            "tab_id": tab_id,
            "active": is_active == "1",
            "title": title,
            "url": url,
        })
    return front_win, rows


def load_json(path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def main():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from switcher_log import log
    t0 = time.time()
    log("poll", "start")

    # A single AppleScript round trip has been measured at 1.6-2.8s (see
    # the module docstring), which is not safely smaller than any interval
    # this poller might be scheduled at. Firing again while the previous
    # call is still in flight was reproduced live 2026-09-25 under a 5s
    # LaunchAgent interval: overlapping osascript invocations piled up
    # against Chrome's Apple Event handler and a later PLAIN osascript
    # call (no overlap involved) took 33s to return where it normally
    # takes <1s, before draining back to normal on its own. This lock
    # makes a scheduled run that finds one already active exit immediately
    # instead of adding to that pile.
    lock_fh = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("poll: previous run still in flight, skipping this one", file=sys.stderr)
        return 0

    front_win, tabs = enumerate_tabs()
    if tabs is None:
        # Chrome not running, or the AppleScript call failed/timed out.
        # Leave the existing cache/frecency files alone -- a poll that
        # can't see Chrome must not be read as "Chrome has zero tabs".
        print("poll: enumeration failed or timed out; left cache untouched", file=sys.stderr)
        return 1

    now = time.time()
    CACHE_FILE.write_text(json.dumps(
        {"polled_at": now, "front_win": front_win, "tabs": tabs}, indent=2))

    frecency = load_json(FRECENCY_FILE, {})
    active = next((t for t in tabs if t["active"]), None)
    prev_active_url = frecency.get("_last_active_url")

    if active is not None and active["url"] != prev_active_url:
        row = frecency.get(active["url"], {"count": 0, "last_seen": 0, "title": ""})
        row["count"] = row.get("count", 0) + 1
        row["last_seen"] = now
        row["title"] = active["title"]
        frecency[active["url"]] = row
        frecency["_last_active_url"] = active["url"]
        FRECENCY_FILE.write_text(json.dumps(frecency, indent=2))
        print(f"poll: visit recorded for {active['url']!r} (count={row['count']})")
    else:
        print(f"poll: no transition ({len(tabs)} tabs cached)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
