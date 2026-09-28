#!/bin/bash
# Smoke checks for rank.py -- the MRU-ranking half of the chrome-tabs
# switcher. No prior test covered this script; added 2026-09-25 after a
# real bug: sorting purely by score has no guarantee the ACTIVE tab lands
# on row 1, so a high-scoring alternate could outrank it and push the
# active tab to row 2 -- exactly where cursor_row=2 pre-highlights,
# making a confirm re-select the tab you're already on (reads as "the
# switcher does nothing"). That guarantee (active tabs pinned ahead of
# everything else) was ITSELF REVERSED 2026-09-28, the same day it was
# extended to a multi-window group: with two Chrome windows in scope,
# both windows' active tabs occupied rows 1-2, so the switcher's own
# quick-confirm gesture (row 2) always landed on "the other window's
# front tab" -- indistinguishable from a window-switcher for the common
# two-window case, verified live against the user's own real workspace.
# Checks 1-3 below now assert the OPPOSITE of what they originally
# guarded -- see rank.py's own docstring for the accepted trade-off this
# reversal takes on.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

# CHROME_FRESH_PAIRS explicitly UNSET for every call unless a check sets it
# itself -- these checks must not be affected by whatever happens to be in
# the real environment.
run_rank() {
    env -u CHROME_FRESH_PAIRS python3 -c "
import sys, pathlib
sys.path.insert(0, '$HERE')
import rank
rank.CACHE_FILE = pathlib.Path('$TMP/cache.json')
rank.FRECENCY_FILE = pathlib.Path('$TMP/frecency.json')
import switcher_log
switcher_log.STATE_DIR = pathlib.Path('$TMP')
switcher_log.LOG_FILE = switcher_log.STATE_DIR / 'switcher.debug.log'
raise SystemExit(rank.main())
"
}

# switcher_log's STATE_DIR/LOG_FILE also redirected in run_rank() and
# check 3's inline block, 2026-09-27 -- rank.py's own top-level `from
# switcher_log import log` was writing every one of these checks' fixture
# titles ("Active Tab", "Really active now", ...) into the REAL, production
# switcher.debug.log, the exact file HANDOFF.md calls "the primary
# diagnostic tool for this bug" -- a tests-never-touch-real-state.md
# violation this test itself introduced when switcher_log.py was added,
# after this file was written. Patching the module object's own attributes
# works even though rank.py only imports the `log` NAME, not the module --
# the function still resolves STATE_DIR/LOG_FILE from switcher_log's own
# globals at call time.
#
# Check 1 (REVERSED 2026-09-28): a non-active tab visited more recently
# than the active one now correctly OUTRANKS it -- pure MRU, no
# active-tabs-first special case any more. The marker still correctly
# lands on the active tab wherever it ends up, which is what a picker
# consumer actually depends on (not row position).
python3 -c "
import json, time
now = time.time()
json.dump({'polled_at': now, 'front_win': 'W1', 'tabs': [
    {'win': 'W1', 'index': 1, 'tab_id': 't1', 'active': True, 'title': 'Active Tab, visited long ago', 'url': 'https://active.example'},
    {'win': 'W1', 'index': 2, 'tab_id': 't2', 'active': False, 'title': 'Recently visited alternate', 'url': 'https://recent.example'},
]}, open('$TMP/cache.json', 'w'))
json.dump({
    'https://active.example': {'count': 1, 'last_seen': now - 3600, 'title': 'Active Tab'},
    'https://recent.example': {'count': 1, 'last_seen': now, 'title': 'Recently visited alternate'},
}, open('$TMP/frecency.json', 'w'))
"
out="$(run_rank)"
first_line=$(echo "$out" | sed -n '1p')
second_line=$(echo "$out" | sed -n '2p')
case "$first_line" in
    *"Recently visited alternate"*) ;;
    *) fail "the more-recently-visited tab did not outrank the active-but-stale one: $out" ;;
esac
case "$second_line" in
    *"▸ Active Tab, visited long ago"*) ;;
    *) fail "the active tab's marker did not survive it ranking below the alternate: $out" ;;
esac
ok "pure MRU: a recently-visited tab outranks the active tab, which still keeps its marker"

# Check 2: with no scoring data at all (fresh machine), ties are broken by
# cache/enumeration order, same as any other tie -- there is no more
# active-tab special case to fall back on.
python3 -c "
import json, time
now = time.time()
json.dump({'polled_at': now, 'front_win': 'W1', 'tabs': [
    {'win': 'W1', 'index': 1, 'tab_id': 't1', 'active': False, 'title': 'Never active, enumerated first', 'url': 'https://a.example'},
    {'win': 'W1', 'index': 2, 'tab_id': 't2', 'active': True, 'title': 'Active Tab', 'url': 'https://b.example'},
]}, open('$TMP/cache.json', 'w'))
"
rm -f "$TMP/frecency.json"
out="$(run_rank)"
first_line=$(echo "$out" | sed -n '1p')
case "$first_line" in
    *"Never active, enumerated first"*) ;;
    *) fail "expected a tied recency to break by enumeration order, got: $out" ;;
esac
ok "with no frecency data at all, a tie breaks by enumeration order, not by active status"

# Check 3: CHROME_FRESH_PAIRS still correctly marks the RIGHT tab as
# active (the real bug found live 2026-09-25: the cache's own "active"
# flag comes from a BACKGROUNDED poll that can be several seconds behind,
# so switching tabs and reopening the switcher fast still shows the tab
# you just LEFT as active). The marker must reflect the fresh signal --
# ranking position is a separate concern, covered by Check 1 above.
python3 -c "
import json, time
now = time.time()
json.dump({'polled_at': now - 5, 'front_win': 'W1', 'tabs': [
    {'win': 'W1', 'index': 1, 'tab_id': 't1', 'active': True, 'title': 'Stale-active (you just left this)', 'url': 'https://stale.example'},
    {'win': 'W1', 'index': 2, 'tab_id': 't2', 'active': False, 'title': 'Really active now', 'url': 'https://real.example'},
]}, open('$TMP/cache.json', 'w'))
"
rm -f "$TMP/frecency.json"
out="$(CHROME_FRESH_PAIRS="W1	t2" env python3 -c "
import sys, pathlib
sys.path.insert(0, '$HERE')
import rank
rank.CACHE_FILE = pathlib.Path('$TMP/cache.json')
rank.FRECENCY_FILE = pathlib.Path('$TMP/frecency.json')
import switcher_log
switcher_log.STATE_DIR = pathlib.Path('$TMP')
switcher_log.LOG_FILE = switcher_log.STATE_DIR / 'switcher.debug.log'
raise SystemExit(rank.main())
")"
case "$out" in
    *"▸ Really active now"*) ;;
    *) fail "CHROME_FRESH_PAIRS did not move the marker onto the really-active tab: $out" ;;
esac
case "$out" in
    *"▸ Stale-active"*) fail "the stale cache flag still carries the marker too: $out" ;;
esac
ok "CHROME_FRESH_PAIRS overrides a stale cache active flag's marker"

# Check 4: pure MRU, not frecency -- changed live 2026-09-25 on the user's
# own call after using it ("frecency isn't accurate... what we really
# need is MRU"). A tab visited 50 times 2 hours ago must NOT outrank one
# visited once a minute ago. The math against the OLD formula (count *
# 2**(-age_hours/4), 4h halflife): frequent = 50 * 2**(-2/4) ~= 35.4;
# recent = 1 * 2**(-(1/60)/4) ~= 1.0 -- the old code would have ranked
# `frequent` FIRST, exactly backwards for an alt-tab gesture. Verified
# this discriminates: reproducing the old formula against this same
# fixture puts `frequent` ahead of `recent`, this check's `recent`
# expectation fails against it (confirmed by hand before trusting this
# check). Checks row 1, not row 2 -- unlike when this check was written,
# there is no more active-tab special case pushing a non-active winner
# down a row (see Check 1 above).
python3 -c "
import json, time
now = time.time()
json.dump({'polled_at': now, 'front_win': 'W1', 'tabs': [
    {'win': 'W1', 'index': 1, 'tab_id': 't1', 'active': False, 'title': 'Visited constantly, 2 hours ago', 'url': 'https://frequent.example'},
    {'win': 'W1', 'index': 2, 'tab_id': 't2', 'active': False, 'title': 'Visited once, a minute ago', 'url': 'https://recent.example'},
    {'win': 'W1', 'index': 3, 'tab_id': 't3', 'active': True, 'title': 'Active Tab', 'url': 'https://active.example'},
]}, open('$TMP/cache.json', 'w'))
json.dump({
    'https://frequent.example': {'count': 50, 'last_seen': now - 2*3600, 'title': 'x'},
    'https://recent.example': {'count': 1, 'last_seen': now - 60, 'title': 'y'},
}, open('$TMP/frecency.json', 'w'))
"
out="$(run_rank)"
first_line=$(echo "$out" | sed -n '1p')
case "$first_line" in
    *"Visited once, a minute ago"*) ;;
    *) fail "the recently-visited-once tab did not rank above the frequently-visited-long-ago one: $out" ;;
esac
ok "pure MRU: one recent visit outranks many old ones"

# Check 5 -- per-workspace scope, 2026-09-28: candidates are the UNION of
# every window CHROME_FRESH_PAIRS names, not just one. A third window's
# tabs (not in CHROME_FRESH_PAIRS at all -- a Chrome window in a DIFFERENT
# workspace) must be excluded.
python3 -c "
import json, time
now = time.time()
json.dump({'polled_at': now, 'tabs': [
    {'win': 'W1', 'index': 1, 'tab_id': 't1', 'active': True, 'title': 'W1 active', 'url': 'https://w1a.example'},
    {'win': 'W2', 'index': 1, 'tab_id': 't2', 'active': True, 'title': 'W2 active', 'url': 'https://w2a.example'},
    {'win': 'W3', 'index': 1, 'tab_id': 't3', 'active': True, 'title': 'Other workspace, must be excluded', 'url': 'https://w3a.example'},
]}, open('$TMP/cache.json', 'w'))
"
rm -f "$TMP/frecency.json"
out="$(CHROME_FRESH_PAIRS="$(printf 'W1\tt1\nW2\tt2')" env python3 -c "
import sys, pathlib
sys.path.insert(0, '$HERE')
import rank
rank.CACHE_FILE = pathlib.Path('$TMP/cache.json')
rank.FRECENCY_FILE = pathlib.Path('$TMP/frecency.json')
import switcher_log
switcher_log.STATE_DIR = pathlib.Path('$TMP')
switcher_log.LOG_FILE = switcher_log.STATE_DIR / 'switcher.debug.log'
raise SystemExit(rank.main())
")"
case "$out" in
    *"Other workspace, must be excluded"*) fail "a window outside CHROME_FRESH_PAIRS leaked into the candidate set: $out" ;;
esac
line_count="$(printf '%s\n' "$out" | grep -c .)"
[ "$line_count" -eq 2 ] || fail "expected exactly 2 candidates (W1 + W2), got $line_count: [$out]"
ok "candidates are the union of every window in CHROME_FRESH_PAIRS, excluding windows outside it"

# Check 6 (REVERSED 2026-09-28): a NON-active tab in one window, visited
# more recently than another window's OWN active tab, now correctly
# outranks it -- proof there is no per-window or active-group special
# case left anywhere in the multi-window ranking. This is the exact
# scenario found live: with two windows open, the quick-confirm gesture
# (row 2) used to always land on "the other window's front tab" under
# the group-first version -- pure MRU across the whole workspace fixes
# that by design.
python3 -c "
import json, time
now = time.time()
json.dump({'polled_at': now, 'tabs': [
    {'win': 'W1', 'index': 1, 'tab_id': 't1', 'active': True, 'title': 'W1 active, visited long ago', 'url': 'https://w1a.example'},
    {'win': 'W2', 'index': 1, 'tab_id': 't2', 'active': True, 'title': 'W2 active, also long ago', 'url': 'https://w2a.example'},
    {'win': 'W2', 'index': 2, 'tab_id': 't2b', 'active': False, 'title': 'W2 inactive, visited just now', 'url': 'https://w2b.example'},
]}, open('$TMP/cache.json', 'w'))
json.dump({
    'https://w1a.example': {'count': 1, 'last_seen': now - 3600, 'title': 'x'},
    'https://w2a.example': {'count': 1, 'last_seen': now - 3600, 'title': 'y'},
    'https://w2b.example': {'count': 1, 'last_seen': now, 'title': 'z'},
}, open('$TMP/frecency.json', 'w'))
"
out="$(CHROME_FRESH_PAIRS="$(printf 'W1\tt1\nW2\tt2')" env python3 -c "
import sys, pathlib
sys.path.insert(0, '$HERE')
import rank
rank.CACHE_FILE = pathlib.Path('$TMP/cache.json')
rank.FRECENCY_FILE = pathlib.Path('$TMP/frecency.json')
import switcher_log
switcher_log.STATE_DIR = pathlib.Path('$TMP')
switcher_log.LOG_FILE = switcher_log.STATE_DIR / 'switcher.debug.log'
raise SystemExit(rank.main())
")"
first_line=$(echo "$out" | sed -n '1p')
case "$first_line" in
    *"W2 inactive, visited just now"*) ;;
    *) fail "a recently-visited non-active tab did not outrank both windows' older active tabs: $out" ;;
esac
case "$first_line" in
    *▸*) fail "a non-active tab must not carry the active marker: $first_line" ;;
esac
ok "a recently-visited non-active tab outranks another window's active tab -- no group-first special case"

# Check 7 -- a present-but-EMPTY CHROME_FRESH_PAIRS (active-now.py
# confirmed zero Chrome windows in the workspace) scopes to NOTHING, not
# to every tab -- distinct from the var being entirely unset.
python3 -c "
import json, time
now = time.time()
json.dump({'polled_at': now, 'front_win': 'W1', 'tabs': [
    {'win': 'W1', 'index': 1, 'tab_id': 't1', 'active': True, 'title': 'Should not appear', 'url': 'https://a.example'},
]}, open('$TMP/cache.json', 'w'))
"
out="$(CHROME_FRESH_PAIRS="" env python3 -c "
import sys, pathlib
sys.path.insert(0, '$HERE')
import rank
rank.CACHE_FILE = pathlib.Path('$TMP/cache.json')
rank.FRECENCY_FILE = pathlib.Path('$TMP/frecency.json')
import switcher_log
switcher_log.STATE_DIR = pathlib.Path('$TMP')
switcher_log.LOG_FILE = switcher_log.STATE_DIR / 'switcher.debug.log'
raise SystemExit(rank.main())
")"
[ -z "$out" ] || fail "expected an empty picker for a confirmed-empty workspace, got: [$out]"
ok "a present-but-empty CHROME_FRESH_PAIRS scopes to nothing, not to every tab"

echo "smoke-rank: $pass checks passed"
