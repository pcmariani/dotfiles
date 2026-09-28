#!/usr/bin/env python3
"""Print every tab in every Chrome window in the CURRENTLY FOCUSED
AEROSPACE WORKSPACE, ranked MRU (most-recently-used), one per line, for
fzf:

    <win_id>\t<index>\t<marker> <title, padded/elided to TITLE_WIDTH>  <dimmed url>

The recency itself is never shown (2026-09-25, the user: "we don't need"
it) -- it still drives ranking, just not the display. Title is the thing
to focus on, so it gets the fixed-width column; the url gets its own
column after it, dimmed (SGR faint, matching picker-rows.sh's own
dim_on/dim_off convention) so it reads as supporting detail, not the
main line.

Reads cache.json (last full poll -- see poll.py's own comment for why the
picker never re-enumerates live: 1.6-1.8s for 29 tabs is real, measured
2026-09-25) and frecency.json (visit history keyed by URL -- the FILE
keeps its name for now; what's IN it changed, see below).

PURE MRU NOW, NOT FRECENCY -- changed live 2026-09-25, the same afternoon,
on the user's own call after actually using it ("frecency isn't
accurate... what we really need is MRU"). The original `count *
2**(-age/4h)` formula rewarded a tab visited MANY times over a long
period even when it wasn't the most recent one -- exactly wrong for an
alt-tab gesture, where "the tab I was JUST on" should always win over
"the tab I visit constantly." This also matches the established pattern
elsewhere in this switcher family: `windows`' own spec already says
"most-recently-used first", not frecency-weighted -- chrome-tabs was the
odd one out, not the norm. RANK = last_seen timestamp alone; a tab never
visited sorts last, tiebroken by Chrome's own cache order (stable sort),
same as before.

ROW 1 IS ALWAYS THE ACTIVE TAB, UNCONDITIONALLY -- found live 2026-09-25,
the same day this became a real switcher: sorting purely by recency has NO
guarantee the active tab (which was just visited, so usually but not
ALWAYS has the most recent timestamp -- the background poll that records
a visit can lag behind the switch itself) lands on row 1. When something
else was more recent, the active tab could land on row 2 itself -- exactly
where cursor_row=2 pre-highlights -- so confirming just re-selected the
tab already on screen, reading as "hammering does nothing." `windows`'s
own producer guarantees this the same way (Spec L: "most-recently-used
first", the current window always first). Fixed by partitioning: the
active tab first, everything else ranked by recency after it.

WHICH TAB IS "active" COMES FROM A FRESH QUERY, NOT THE CACHE, WHEN ONE
IS AVAILABLE -- found live 2026-09-25, right after the row-1 fix above
still didn't feel right: `poll.py`'s full enumeration is backgrounded
(producer.sh) for speed, so its `active` flags can be several seconds
stale. Switch tabs, reopen the switcher fast, and the cache still marks
the tab you just LEFT as active -- so THAT tab (stale-active) correctly
gets row 1 by the fix above, while the tab you're actually on now sits
wherever its recency ranks it, often row 2, and confirming feels
like "it's not toggling." producer.sh runs `active-now.py` (which asks
AeroSpace which Chrome window is in the FOCUSED workspace, not Chrome's
own unreliable "front window" -- see that script's own docstring for a
second real bug found the same afternoon, and a third one -- exact vs.
prefix title matching -- found and fixed the same day after a detour
through a Hammerspoon-based redesign that turned out not to be needed;
see docs/superpowers/specs/2026-09-25-chrome-tabs-hammerspoon-active-window-design.md)
SYNCHRONOUSLY and exports `CHROME_FRESH_FRONT_WIN`/`CHROME_FRESH_ACTIVE_TAB`;
when both are set, they override the cache's own `front_win` and each
tab's own `active` flag for THIS run. Falls back to the cache's own values
if either is empty (active-now.py failed, or found no Chrome window in the
focused workspace) -- stale-but-present beats nothing.

SCOPED TO THE FOCUSED WORKSPACE, NOT ONE WINDOW -- REVERSED 2026-09-28
(the user's own reconsideration of a decision made twice before,
2026-09-25 and 2026-09-27; see active-now.py's own docstring for the full
account of why the earlier workspace-scoping attempt was abandoned, and
why that specific bug does not recur here). The candidate list is
`cache["tabs"]` filtered down to whichever windows appear in
`CHROME_FRESH_PAIRS` (see below) -- every Chrome window in the focused
AeroSpace workspace, not just one. If `CHROME_FRESH_PAIRS` is entirely
ABSENT (env var unset -- active-now.py has never run, or this is being
invoked outside producer.sh entirely), falls back to `cache["front_win"]`
scoping, or every tab if even that is missing -- unchanged fallback chain,
missing data means "can't scope it," not "scope it to nothing." An
EMPTY-but-present `CHROME_FRESH_PAIRS` (active-now.py confirmed zero
Chrome windows in the workspace) DOES mean "scope it to nothing": the
picker is correctly empty, not falling back to stale/global data.

WHICH TABS ARE "active" NOW COMES FROM `CHROME_FRESH_PAIRS`, A SET OF
(win, tab_id) PAIRS, NOT A SINGLE (front_win, active_tab) PAIR -- there can
be one such pair per Chrome window in scope, since each window has its own
independently active tab. Every one of them still gets the `▸` marker in
the display; NONE of them gets special ranking treatment any more (see
the "PURE MRU" section below for why an active-tabs-first group was tried
and reverted the same day, live, against a real two-window workspace).
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from switcher_log import log

STATE_DIR = Path.home() / ".local/state/context/chrome-tabs"
CACHE_FILE = STATE_DIR / "cache.json"
FRECENCY_FILE = STATE_DIR / "frecency.json"

TITLE_WIDTH = 50
DIM_ON = "\033[2m"
DIM_OFF = "\033[0m"


def load_json(path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def elide(text, width):
    """Pad to `width`, or truncate with an ellipsis -- never over width, so
    the URL column that follows always starts in the same place."""
    if len(text) <= width:
        return text.ljust(width)
    return text[: width - 1] + "…"


def recency(url, frecency):
    """Last-seen epoch seconds, or 0.0 for a tab never recorded as active --
    sorts it last, same place score-0 used to."""
    row = frecency.get(url)
    return row["last_seen"] if row else 0.0


def parse_fresh_pairs(raw):
    """`CHROME_FRESH_PAIRS`'s multi-line "win_id<TAB>tab_id" blob into a
    set of (win, tab_id) tuples -- one per Chrome window in the focused
    workspace whose active tab active-now.py could confirm. `None` if the
    env var is entirely absent (can't scope it, fall back to the cache's
    own signals); an empty set for a present-but-blank value (a CONFIRMED
    empty workspace -- scope it to nothing, not everything)."""
    if raw is None:
        return None
    pairs = set()
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        win, _, tab = line.partition("\t")
        pairs.add((win, tab))
    return pairs


def main():
    cache = load_json(CACHE_FILE, None)
    if cache is None:
        print("rank: no cache.json yet -- run poll.py at least once", file=sys.stderr)
        return 1
    frecency = load_json(FRECENCY_FILE, {})

    fresh_pairs = parse_fresh_pairs(os.environ.get("CHROME_FRESH_PAIRS"))
    if fresh_pairs is not None:
        fresh_windows = {win for win, _ in fresh_pairs}
        candidates = [t for t in cache["tabs"] if t["win"] in fresh_windows]
    else:
        front_win = cache.get("front_win")
        candidates = (
            [t for t in cache["tabs"] if t["win"] == front_win]
            if front_win is not None else cache["tabs"]
        )
    import time
    cache_age = time.time() - cache.get("polled_at", 0)
    log("rank",
        f"source={'fresh' if fresh_pairs is not None else 'cache-fallback'} "
        f"fresh_pairs={sorted(fresh_pairs) if fresh_pairs is not None else None!r} "
        f"cache_polled_at_age={cache_age:.2f}s candidates={len(candidates)}")

    def is_active(tab):
        if fresh_pairs is not None:
            return (tab["win"], tab["tab_id"]) in fresh_pairs
        return tab["active"]

    # PURE MRU, no active-tabs-first grouping -- REVERSED 2026-09-28, the
    # same day the group-first version above was written and live-tested:
    # with two windows in scope, BOTH of their active tabs occupied rows 1
    # and 2, so the switcher's own quick-confirm gesture (row 2) always
    # landed on "the other window's front tab" -- indistinguishable from a
    # window-switcher for the common case of exactly two windows, which
    # defeats the point of a TAB switcher. Verified live against the
    # user's own real two-window workspace before reverting.
    #
    # Accepted trade-off: without the group-first guarantee, a tab you
    # switched to by clicking directly in Chrome (bypassing this
    # switcher) can rank behind a more-frecent tab for a few seconds,
    # until poll.py's own backgrounded enumeration catches up frecency.json
    # -- narrower than it first looks, since a tab reached THROUGH this
    # switcher has no such gap at all: activate.py already writes
    # frecency.json itself, synchronously, at the moment of the switch
    # (see its own docstring). Matches the `windows` switcher's own
    # established convention (a single flat MRU list, no active-first
    # special case) -- this was the odd one out for having one at all.
    ranked = sorted(
        enumerate(candidates), key=lambda pair: (-recency(pair[1]["url"], frecency), pair[0]),
    )

    if ranked:
        row1 = ranked[0][1]
        log("rank", f"row1 win={row1['win']} index={row1['index']} active={is_active(row1)} title={row1['title']!r}")
    else:
        log("rank", "no candidates ranked -- confirmed-empty workspace" if fresh_pairs == set()
            else "no candidates ranked -- empty picker" if candidates == []
            else "no tabs at all")

    for _, tab in ranked:
        marker = "▸" if is_active(tab) else " "
        title = elide(tab["title"], TITLE_WIDTH)
        print(f"{tab['win']}\t{tab['index']}\t{marker} {title}  {DIM_ON}{tab['url']}{DIM_OFF}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
