#!/bin/bash
# Smoke checks for rows.py -- the send-tab picker's row-generation logic.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

run() {
    python3 -c "
import sys
sys.path.insert(0, '$HERE')
from rows import build_rows
$1
"
}

# Check 1: a workspace with 0 other Chrome windows gets a plain 'new' row.
out=$(run "
r = build_rows(['climb'], [], source_window_id=1)
assert r == [('climb', 'new:climb')], r
print('ok')
")
[ "$out" = "ok" ] && ok "0-window workspace gets a new: row" || fail "0-window workspace"

# Check 2: a workspace with exactly 1 OTHER window (source excluded) gets
# a plain merge row, no window title shown.
out=$(run "
windows = [{'workspace': 'climb', 'window_id': 42, 'title': 'Example'}]
r = build_rows(['climb'], windows, source_window_id=1)
assert r == [('climb', 'merge:42')], r
print('ok')
")
[ "$out" = "ok" ] && ok "1-window workspace collapses to a merge: row" || fail "1-window workspace"

# Check 3: THE BLOCKING CASE THIS WHOLE FEATURE EXISTS TO FIX -- two
# DIFFERENT workspaces, each with exactly one Chrome window, sharing an
# IDENTICAL title (the real climb/b-pm collision found this session).
# This must fail against a version of build_rows with no title_counts
# logic at all (both would still render as bare 'climb'/'b-pm' rows,
# which is actually already correct here -- the label doesn't need the
# title for a 1-window row. This check instead pins that the VALUE is
# correctly keyed by each window's own id, not accidentally shared.)
out=$(run "
windows = [
    {'workspace': 'climb', 'window_id': 100, 'title': 'Boomi_PeterMariani - Build'},
    {'workspace': 'b-pm',  'window_id': 200, 'title': 'Boomi_PeterMariani - Build'},
]
r = build_rows(['climb', 'b-pm'], windows, source_window_id=1)
assert ('climb', 'merge:100') in r, r
assert ('b-pm', 'merge:200') in r, r
print('ok')
")
[ "$out" = "ok" ] && ok "same-titled windows in different workspaces get distinct merge values" || fail "cross-workspace title collision"

# Check 4: two windows in the SAME 2+-window workspace sharing a title
# get a disambiguating suffix on their LABEL (display only).
out=$(run "
windows = [
    {'workspace': 'work', 'window_id': 10, 'title': 'Dup'},
    {'workspace': 'work', 'window_id': 20, 'title': 'Dup'},
]
r = build_rows(['work'], windows, source_window_id=1)
assert r == [('Dup (work)', 'merge:10'), ('Dup (work)', 'merge:20')], r
print('ok')
")
[ "$out" = "ok" ] && ok "same-workspace title collision gets a disambiguating label" || fail "same-workspace title collision"

# Check 5: the source window itself is excluded from every count, so a
# workspace containing ONLY the source shows as a plain 0-window 'new' row.
out=$(run "
windows = [{'workspace': 'climb', 'window_id': 1, 'title': 'Source Tab'}]
r = build_rows(['climb'], windows, source_window_id=1)
assert r == [('climb', 'new:climb')], r
print('ok')
")
[ "$out" = "ok" ] && ok "source window excluded from its own workspace's count" || fail "source exclusion"

echo "$pass checks passed"
