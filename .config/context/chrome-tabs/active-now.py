#!/usr/bin/env python3
"""Which Chrome window(s) belong to the CURRENTLY FOCUSED AeroSpace
workspace, and each one's active tab -- writes fresh.tsv as zero or more
"win_id<TAB>active_tab_id" lines (one per matched window), same "can't
tell you, don't guess" contract poll.py's own enumeration failure follows.

REWRITTEN 2026-09-28 for per-workspace scope (the user's own
reconsideration of a decision made twice before, 2026-09-25 and
2026-09-27): this used to query ONLY the literal focused window
(`list-windows --focused`), on the reasoning that workspace-membership
scoping had already been tried and picked the WRONG single window when
two Chrome windows shared a workspace -- AeroSpace's own listing order has
nothing to do with which one the user actually has front (see this file's
own prior history, or git log, for that bug's full account). That bug is
specific to needing to choose ONE window; it disappears entirely once the
switcher's own scope is "every Chrome window in this workspace" rather
than "the one window," since there is no longer a single window to choose
wrong. Also drops the "focus must be on Chrome" gate entirely: the
switcher is now meant to work invoked from any app, as long as some Chrome
window sits in the focused workspace.

Queries `list-windows --workspace focused --json` -- the SAME call
~/.hammerspoon/init.lua's own chromeWindowsInFocusedWorkspace() already
uses successfully for the opt-backtick join feature -- filters to
`app-name == "Google Chrome"`, and matches EACH one's window-title against
the bulk enumeration below, collecting every match instead of stopping at
the first. AeroSpace's own `window-id` is discarded after filtering, never
used as a match key: it is a CGWindowID, a completely different number
space from Chrome's own AppleScript window ids this whole pipeline keys
everything by (poll.py's cache.json, this file's own matched output).

AeroSpace already tracks every window's real workspace/monitor -- it is
the authoritative source this project already trusts everywhere else (see
e.g. context/facts.py). AeroSpace's own window title for a Chrome window
is "<active tab title> - Google Chrome - <profile name>" (verified live,
2026-09-25) -- the tab title is everything before the FIRST occurrence of
that literal separator.

MATCHED BY PREFIX, NOT EXACT EQUALITY -- fixed live 2026-09-25: Chrome
decorates the AX/AeroSpace-visible WINDOW title with extra text a tab's
own AppleScript `title of tab` does not have (a memory warning, an unread
count), so exact equality silently fails whenever a window happens to be
decorated. The true match's own tab title is always the LONGEST real
prefix of the target title (decoration is only ever appended, never
inserted or truncated), so the longest matching candidate among Chrome's
bulk-enumerated windows is the correct one for a given target.

If more than one Chrome window in the same workspace somehow has the
identical active-tab title (two windows both on the exact same page), the
first bulk-enumeration match wins for THAT target -- a real, accepted,
rare-case limitation, not silently wrong so much as best-effort under
genuine ambiguity (unchanged from the single-window version).

A WHOLE-RUN failure (aerospace's own query failing, or ANY workspace
window failing to find a match) leaves fresh.tsv UNTOUCHED rather than
overwriting it with a partial result -- "stale-but-present beats nothing"
applied at the run level, not per-window, so a transient miss for one
window can never silently drop another window's still-good, previously
written answer. The one exception: aerospace's query SUCCEEDING and
reporting a genuinely empty workspace (zero Chrome windows) is a
CONFIRMED fact, not a miss, and IS written -- as an empty file -- so a
stale multi-window answer from before the user closed everything does not
linger forever.
"""
import fcntl
import json
import subprocess
import sys
import time
from pathlib import Path

AEROSPACE = "/opt/homebrew/bin/aerospace"
TITLE_SEPARATOR = " - Google Chrome - "

STATE_DIR = Path.home() / ".local/state/context/chrome-tabs"
FRESH_FILE = STATE_DIR / "fresh.tsv"
LOCK_FILE = STATE_DIR / "active-now.lock"

ENUMERATE_ACTIVE_TABS = """
tell application "Google Chrome"
    set winIds to id of every window
    set tabTitles to title of (active tab of every window)
    set tabIds to id of (active tab of every window)
end tell
set AppleScript's text item delimiters to "\\t"
return (winIds as text) & "\\n" & (tabTitles as text) & "\\n" & (tabIds as text)
"""
# VECTORIZED, not a per-window repeat loop -- see git history (2026-09-28):
# Chrome's OWN `active tab of every window` (and `title of (active tab of
# every window)`) works as a single BULK Apple Event across all windows at
# once, measured ~3-4x faster than a script-level loop fetching the same
# two properties per window.


def aerospace(*args):
    try:
        proc = subprocess.run([AEROSPACE, *args], capture_output=True, text=True, timeout=2)
    except (subprocess.TimeoutExpired, OSError):
        return None
    return proc.stdout.strip() if proc.returncode == 0 else None


def chrome_window_titles_in_focused_workspace():
    """AeroSpace's own decorated window-titles for every Chrome window in
    the focused workspace. `None` on a query failure (never guess); `[]`
    is a real, confirmed "no Chrome windows here"."""
    out = aerospace("list-windows", "--workspace", "focused", "--json")
    if out is None:
        return None
    try:
        windows = json.loads(out)
    except json.JSONDecodeError:
        return None
    return [w["window-title"] for w in windows if w.get("app-name") == "Google Chrome"]


def best_match(target_title, win_ids, tab_ids, tab_titles):
    """Longest-prefix match against the bulk enumeration -- see module
    docstring. `None` if nothing matches `target_title` at all."""
    best_win_id = best_tab_id = None
    best_len = -1
    for win_id, tab_id, tab_title in zip(win_ids, tab_ids, tab_titles):
        if tab_title and target_title.startswith(tab_title) and len(tab_title) > best_len:
            best_win_id, best_tab_id, best_len = win_id, tab_id, len(tab_title)
    if best_win_id is None:
        return None
    return best_win_id, best_tab_id, best_len


def write_fresh_file(lines, not_before=None):
    """Temp-then-rename, matching poll.py's own cache write -- a reader
    (producer.sh) must never see a half-written file. `lines` is a list of
    already-formatted "win_id\\ttab_id" strings (possibly empty -- see
    module docstring on a confirmed-empty workspace).

    `not_before`: if fresh.tsv's own mtime is already newer than this
    (this run's start time), something else -- activate.py, or a second
    active-now.py run -- wrote a fresher answer while this run was still
    computing its own, slower one. Skip the write rather than clobber it."""
    if not_before is not None:
        try:
            if FRESH_FILE.stat().st_mtime > not_before:
                sys.path.insert(0, str(Path(__file__).resolve().parent))
                from switcher_log import log
                log("active-now", f"SKIPPED write ({len(lines)} pairs): fresh.tsv already newer (race guard)")
                return
        except FileNotFoundError:
            pass
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = FRESH_FILE.with_suffix(".tsv.tmp")
    tmp.write_text("".join(f"{line}\n" for line in lines))
    tmp.rename(FRESH_FILE)


def main():
    # BACKGROUNDED BY producer.sh, LOCKED non-blocking, and start_time
    # recorded before any work -- all unchanged from the single-window
    # version; see git history for the full latency/race account.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from switcher_log import log

    start_time = time.time()
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    log("active-now", "start")
    lock_fh = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        log("active-now", "SKIP: previous run still in flight")
        return 0

    target_titles = chrome_window_titles_in_focused_workspace()
    if target_titles is None:
        log("active-now", "abort: aerospace list-windows --workspace focused --json returned nothing/unparseable")
        return 0
    if not target_titles:
        log("active-now", "no Chrome windows in the focused workspace -- writing a confirmed-empty fresh.tsv")
        write_fresh_file([], not_before=start_time)
        return 0

    try:
        proc = subprocess.run(
            ["osascript", "-e", ENUMERATE_ACTIVE_TABS],
            capture_output=True, text=True, timeout=5,
        )
    except subprocess.TimeoutExpired:
        log("active-now", f"abort: ENUMERATE_ACTIVE_TABS timed out after {time.time()-start_time:.2f}s")
        return 0
    if proc.returncode != 0:
        log("active-now", f"abort: ENUMERATE_ACTIVE_TABS failed rc={proc.returncode} stderr={proc.stderr.strip()!r}")
        return 0

    # rstrip("\n") first -- osascript ALWAYS appends a trailing newline to
    # whatever `return` yields, so a plain split("\n") here would always
    # see a spurious 4th, empty element and abort on every real call.
    lines = proc.stdout.rstrip("\n").split("\n")
    if len(lines) != 3:
        log("active-now", f"abort: ENUMERATE_ACTIVE_TABS returned {len(lines)} lines, expected 3: {proc.stdout!r}")
        return 0
    win_ids, tab_titles, tab_ids = (line.split("\t") for line in lines)
    if not (len(win_ids) == len(tab_ids) == len(tab_titles)):
        log("active-now", f"abort: mismatched column counts ({len(win_ids)}/{len(tab_ids)}/{len(tab_titles)})")
        return 0

    matched = []
    for target_title in target_titles:
        result = best_match(target_title, win_ids, tab_ids, tab_titles)
        if result is None:
            log("active-now", f"NO MATCH for target_title={target_title!r}")
            continue
        best_win_id, best_tab_id, best_len = result
        matched.append((best_win_id, best_tab_id))
        log("active-now", f"MATCH win={best_win_id} tab={best_tab_id} match_len={best_len} target_title={target_title!r}")

    if len(matched) != len(target_titles):
        # A WHOLE-RUN failure, not a partial write -- see module docstring.
        log("active-now",
            f"abort: only {len(matched)}/{len(target_titles)} workspace windows matched, "
            f"elapsed={time.time()-start_time:.2f}s -- fresh.tsv left untouched")
        return 0

    lines_out = [f"{w}\t{t}" for w, t in matched]
    for line in lines_out:
        print(line)
    log("active-now", f"{len(matched)}/{len(target_titles)} workspace windows matched, elapsed={time.time()-start_time:.2f}s")
    write_fresh_file(lines_out, not_before=start_time)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
