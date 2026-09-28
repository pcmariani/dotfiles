#!/usr/bin/env python3
"""Jump Chrome to a specific window+tab: activate.py <win_id> <tab_index>

Same three-line AppleScript Hammerspoon's own focusChromeWindowShowing
fallback already uses (~/.hammerspoon/init.lua:293-298) -- proven live
2026-09-25 switching between two real windows during this prototype, not
newly invented here.

WRITES fresh.tsv ITSELF, AFTER THE SWITCH -- added 2026-09-26, a real
regression fix. The night before, active-now.py's synchronous 0.75-0.84s
AppleScript call was moved to the background (see its own docstring) to
fix "doesn't respond when I hammer" -- but that traded away exactly the
freshness the SWITCHER'S OWN TOGGLE GESTURE depends on: switch to tab B,
then immediately re-invoke to switch BACK to tab A, and the fresh.tsv a
background active-now.py run last wrote is often still the ANSWER FROM
BEFORE THE FIRST SWITCH (that run takes most of a second; a real toggle
cadence is faster than that), so rank.py keeps marking tab A active and
pre-highlighting tab B on row 2 -- confirming just re-selects tab B,
reading as "stuck on the second position, toggle doesn't work." The
user's own report, 2026-09-26.

THIS SCRIPT ALREADY KNOWS THE ANSWER WITH ZERO EXTRA COST: it is the one
thing that just MADE win_id/tab_index active, so there is nothing to ask
Chrome or AeroSpace at all -- unlike active-now.py, which has to
reconstruct the answer after the fact. Looks the tab up in the already-
cached cache.json (poll.py's own file, a fast local read) to keep
fresh.tsv's shape exactly what active-now.py already produces (a tab_id,
not an index -- rank.py's `is_active()` needs no change at all).

ALSO WRITES frecency.json ITSELF, AFTER THE SWITCH -- added the same
night, a SECOND real bug the user's own "test it like crazy" torture test
(torture-toggle.sh) found within minutes of being written: fixing row 1
(which tab is marked active) was not enough, because row 2 -- the
pre-highlighted MRU alternate the whole point of this switcher is to let
you confirm without looking -- is ranked from frecency.json, and THAT
file is only written by poll.py's own slow, backgrounded, 1.6-2.8s full
enumeration. Torture-tested proof: walking through 5 real tabs in
sequence, row 2 kept showing tabs visited BEFORE the walk started, never
catching up to the walk itself, because poll.py's background runs could
not complete between switches. Fixed the same way the active-tab marker
was: this script already knows exactly which URL just became active, at
zero extra cost, so it updates frecency.json itself, synchronously,
matching poll.py's own update shape (count/last_seen/title per URL, plus
poll.py's own `_last_active_url` transition-detection key so poll.py
does not also independently re-record the same visit when it eventually
catches up -- harmless if it does, since poll.py's own timestamp can only
ever be equal-or-later, but pointless double counting is easy to avoid).
"""
import json
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from switcher_log import log

STATE_DIR = Path.home() / ".local/state/context/chrome-tabs"
CACHE_FILE = STATE_DIR / "cache.json"
FRESH_FILE = STATE_DIR / "fresh.tsv"
FRECENCY_FILE = STATE_DIR / "frecency.json"

AEROSPACE = "/opt/homebrew/bin/aerospace"
TITLE_SEPARATOR = " - Google Chrome - "


def write_fresh_file(win_id, tab_id):
    """Temp-then-rename, matching active-now.py's own write. MERGES into
    whatever is already there rather than overwriting wholesale
    (2026-09-28, per-workspace rewrite): fresh.tsv can now hold one line
    per Chrome window in the workspace, and this call only ever knows
    about the ONE window that just switched -- a blind overwrite would
    wipe out every OTHER window's still-good entry until the next
    active-now.py background run caught up, reintroducing exactly the
    staleness bug this file's fast, synchronous write exists to avoid,
    just for the windows NOT switched instead of the one that was.

    No race guard needed here beyond what already exists: this call is
    always the freshest possible answer for `win_id` (it just made the
    switch happen), and active-now.py's OWN write already checks whether
    fresh.tsv has grown newer than ITS start time before writing, which
    still protects a merge exactly the same way it protected a whole-file
    overwrite."""
    pairs = {}
    try:
        for line in FRESH_FILE.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            existing_win, _, existing_tab = line.partition("\t")
            pairs[existing_win] = existing_tab
    except FileNotFoundError:
        pass
    pairs[win_id] = tab_id
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = FRESH_FILE.with_suffix(".tsv.tmp")
    tmp.write_text("".join(f"{w}\t{t}\n" for w, t in pairs.items()))
    tmp.rename(FRESH_FILE)


def write_frecency(url, title):
    """Same update poll.py's own transition-detection makes, just done
    instantly instead of waiting for poll.py's next background run to
    notice. Temp-then-rename, matching poll.py's own cache write."""
    try:
        frecency = json.loads(FRECENCY_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        frecency = {}
    row = frecency.get(url, {"count": 0, "last_seen": 0, "title": ""})
    row["count"] = row.get("count", 0) + 1
    row["last_seen"] = time.time()
    row["title"] = title
    frecency[url] = row
    frecency["_last_active_url"] = url
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = FRECENCY_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(frecency, indent=2))
    tmp.rename(FRECENCY_FILE)


def tab_for(win_id, tab_index):
    """The freshly-activated tab's own cached row (tab_id/title/url), from
    the last poll -- or None if it isn't there (a race with a not-yet-
    polled new tab, or a missing cache). Never raises: a lookup miss just
    means fresh.tsv/frecency.json don't get written this time, same
    "stale-but-present beats nothing" fallback active-now.py's own miss
    case already follows."""
    try:
        cache = json.loads(CACHE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    for tab in cache.get("tabs", []):
        if tab.get("win") == win_id and str(tab.get("index")) == str(tab_index):
            return tab
    return None


def aerospace(*args):
    try:
        proc = subprocess.run([AEROSPACE, *args], capture_output=True, text=True, timeout=2)
    except (subprocess.TimeoutExpired, OSError):
        return None
    return proc.stdout.strip() if proc.returncode == 0 else None


def window_title(win_id):
    """This window's active tab's title, or None on failure. A
    single-window query, not an enumeration -- cheap, and this only ever
    runs once per activation (the moment a row is CONFIRMED, not while
    browsing the picker).

    Deliberately `title of (active tab of window id X)`, NOT `title of
    window id X` -- confirmed live 2026-09-27: Chrome's `title of window`
    silently middle-truncates (with a "…") any title longer than ~62
    characters, regardless of frontmost/occlusion state (a window brought
    to index 1 and activated still truncates). A truncated my_title can
    never be a real startswith() prefix of AeroSpace's own untruncated
    window-title list, so the isolation gate below FAIL-CLOSED-refused
    every activation on any window with a title this long -- the
    "switcher is not actually switching tabs" report. `title of (active
    tab of window)` does not truncate for the same window; it's also the
    exact property active-now.py's ENUMERATE_ACTIVE_TABS already uses, so
    this now actually matches its own docstring's claim of mirroring that
    approach. See smoke-window-title.sh."""
    try:
        proc = subprocess.run(
            ["osascript", "-e",
             f'tell application "Google Chrome" to title of (active tab of (window id {win_id}))'],
            capture_output=True, text=True, timeout=2,
        )
    except (subprocess.TimeoutExpired, OSError):
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def is_in_focused_workspace(win_id):
    """The FINAL isolation gate, added 2026-09-27 after a live, real
    reproduction: opening a NEW Chrome window inside an ALREADY-focused
    AeroSpace workspace fires `on-focus-changed`, not
    `exec-on-workspace-change` -- so nothing refreshes active-now.py's
    answer for that case (the 2026-09-26 proactive-refresh fix only
    covers switching BETWEEN workspaces). A stale front_win/fresh.tsv
    answer then let the switcher confirm a row that activated a window in
    a DIFFERENT workspace entirely, dragging the user there -- the exact
    "still not working" report, and this project's stated goal is MAXIMUM
    isolation between workspaces, not best-effort.

    Rather than chase yet another freshness gap (this is at least the
    third distinct one found across this feature's history), this is a
    hard gate, re-derived LIVE at the moment of activation, independent
    of however the candidate list upstream got computed: is `win_id`
    REALLY one of the CURRENTLY FOCUSED workspace's own Chrome windows,
    right now? Same title-matching approach active-now.py already uses
    (AeroSpace's own window title carries decoration Chrome's tab title
    doesn't -- match by prefix, longest match wins, mirroring
    active-now.py's own 2026-09-26 fix), just run in the OPPOSITE
    direction: given one specific window id, confirm it belongs, instead
    of searching for which one does.

    FAILS CLOSED: any failure to confirm (aerospace timeout, Chrome not
    answering, no focused workspace, no Chrome window there at all) means
    "cannot prove this is safe" -> refuse, not "assume yes". A refusal
    costs one missed activation, visible and retryable; a wrong one drags
    the user to a different workspace, which is the whole thing being
    guarded against."""
    focused_ws = aerospace("list-workspaces", "--focused")
    if not focused_ws:
        log("activate.gate", "FAIL-CLOSED: aerospace list-workspaces --focused returned nothing")
        return False
    chrome_titles = aerospace(
        "list-windows", "--workspace", focused_ws,
        "--app-bundle-id", "com.google.Chrome", "--format", "%{window-title}",
    )
    if not chrome_titles:
        log("activate.gate", f"FAIL-CLOSED: no Chrome window in focused_ws={focused_ws!r}")
        return False
    my_title = window_title(win_id)
    if not my_title:
        log("activate.gate", f"FAIL-CLOSED: could not get window_title for win={win_id}")
        return False
    match = any(
        (line.split(TITLE_SEPARATOR, 1)[0] if TITLE_SEPARATOR in line else line).startswith(my_title)
        for line in chrome_titles.splitlines()
    )
    log("activate.gate",
        f"win={win_id} my_title={my_title!r} focused_ws={focused_ws!r} "
        f"candidates={chrome_titles.splitlines()!r} -> {'MATCH' if match else 'NO MATCH'}")
    return match


def main():
    if len(sys.argv) != 3:
        print("usage: activate.py <win_id> <tab_index>", file=sys.stderr)
        return 2
    win_id, tab_index = sys.argv[1], sys.argv[2]
    log("activate", f"start win={win_id} index={tab_index}")

    if not is_in_focused_workspace(win_id):
        print(
            f"activate: REFUSED -- window {win_id} is not confirmed to be in the "
            "currently focused AeroSpace workspace (isolation guard)",
            file=sys.stderr,
        )
        log("activate", f"REFUSED win={win_id} index={tab_index}: not in focused workspace (isolation guard)")
        return 3

    script = f'''
tell application "Google Chrome"
  set active tab index of (window id {win_id}) to {tab_index}
  set index of (window id {win_id}) to 1
  activate
end tell
'''
    proc = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    if proc.returncode != 0:
        print(f"activate: {proc.stderr.strip()}", file=sys.stderr)
        log("activate", f"FAILED win={win_id} index={tab_index}: {proc.stderr.strip()!r}")
        return 1

    tab = tab_for(win_id, tab_index)
    if tab is not None:
        write_fresh_file(win_id, tab["tab_id"])
        write_frecency(tab["url"], tab["title"])
        log("activate", f"OK win={win_id} index={tab_index} tab_id={tab['tab_id']} url={tab['url']!r}")
    else:
        log("activate", f"OK (switched) but win={win_id} index={tab_index} not found in cache.json -- no fresh.tsv/frecency write")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
