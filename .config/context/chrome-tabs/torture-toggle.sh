#!/bin/bash
# TORTURE TEST for the chrome-tabs switcher, 2026-09-26 -- run against the
# REAL running Chrome, not fixtures. The user, after two real regressions
# found live the same night: "let's keep the panel and the Chrome MRU, but
# we just need to test it like crazy... snappy enough that I don't have to
# think about it, it just works." This is that test: rapid real toggles,
# an MRU walk across several real tabs, a real latency distribution (not
# one sample), and a tight concurrent race stress -- all against the
# actual front Chrome window, restoring its original active tab when done.
#
# WHAT THIS CANNOT PROVE: the real feel of a physical hand hammering a
# physical key through Karabiner -> Carbon -> paneld's own CycleMachine.
# That chain has no CLI equivalent -- this script proves the SCRIPT layer
# (producer.sh/rank.py/activate.py/active-now.py) is correct and fast
# under real, repeated, adversarial use; the keyboard itself still needs
# the user's own hands.
set -u

PY=/Users/petermariani/.local/share/mise/installs/python/3.12/bin/python3
DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE=~/.local/state/context/chrome-tabs/cache.json
FRESH=~/.local/state/context/chrome-tabs/fresh.tsv

pass=0
fail_count=0
fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count+1)); }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

WIN=$(python3 -c "import json; print(json.load(open('$CACHE'))['front_win'])")
ORIGINAL_ACTIVE=$(python3 -c "
import json
c = json.load(open('$CACHE'))
for t in c['tabs']:
    if t['win'] == '$WIN' and t['active']:
        print(t['index']); break
")
TAB_COUNT=$(python3 -c "
import json
c = json.load(open('$CACHE'))
print(len([t for t in c['tabs'] if t['win'] == '$WIN']))
")

echo "Front window: $WIN ($TAB_COUNT tabs), originally active: index $ORIGINAL_ACTIVE"
if [ "$TAB_COUNT" -lt 3 ]; then
    echo "Need at least 3 tabs in the front window for a meaningful torture test; found $TAB_COUNT. Aborting." >&2
    exit 2
fi

row1_index() {
    ~/.config/context/chrome-tabs/producer.sh 2>/dev/null | tr '\0' '\n' | head -1 | sed -E 's/^[0-9]+:([0-9]+).*/\1/'
}

# --- Check 1: rapid ping-pong between two real tabs, N rounds ---
echo
echo "=== Check 1: rapid ping-pong (15 rounds, tabs 1 and 2) ==="
lat_file=$(mktemp)
round_fail=0
for i in $(seq 1 15); do
    for target in 1 2; do
        "$PY" "$DIR/activate.py" "$WIN" "$target" >/dev/null 2>&1
        t0=$(python3 -c 'import time; print(time.time())')
        got=$(row1_index)
        t1=$(python3 -c 'import time; print(time.time())')
        python3 -c "print(f'{($t1 - $t0)*1000:.1f}')" >> "$lat_file"
        if [ "$got" != "$target" ]; then
            fail "round $i: activated tab $target but producer.sh row 1 showed tab $got"
            round_fail=1
        fi
    done
done
[ "$round_fail" -eq 0 ] && ok "30/30 ping-pong switches landed on row 1 correctly, zero staleness"

echo "Producer latency during ping-pong (ms):"
python3 -c "
import statistics
vals = [float(l) for l in open('$lat_file')]
vals.sort()
p95 = vals[int(len(vals)*0.95)]
print(f'  min={min(vals):.1f} mean={statistics.mean(vals):.1f} max={max(vals):.1f} p95={p95:.1f} (n={len(vals)})')
if p95 < 250:
    print('   ok: p95 well under the 300ms reveal delay')
else:
    print('   FAIL: p95 latency too close to or over the reveal delay')
"
rm -f "$lat_file"

# --- Check 2: MRU walk across every real tab in the window ---
echo
echo "=== Check 2: MRU walk across all $TAB_COUNT tabs, verify row 1 + ranking each step ==="
walk_fail=0
# Visit every index once, in a shuffled-ish but deterministic order distinct
# from natural order (reverse, then back to front) so the MRU ranking is a
# real exercise, not just "most recent == highest index".
order=$(seq "$TAB_COUNT" -1 1)
prev=""
for target in $order; do
    "$PY" "$DIR/activate.py" "$WIN" "$target" >/dev/null 2>&1
    out=$(~/.config/context/chrome-tabs/producer.sh 2>/dev/null | tr '\0' '\n')
    row1=$(printf '%s\n' "$out" | head -1 | sed -E 's/^[0-9]+:([0-9]+).*/\1/')
    if [ "$row1" != "$target" ]; then
        fail "MRU walk: activated tab $target, row 1 showed tab $row1"
        walk_fail=1
    fi
    # The tab we were JUST on before this one should now rank as the
    # freshest of "the rest" -- i.e. row 2.
    if [ -n "$prev" ]; then
        row2=$(printf '%s\n' "$out" | sed -n '2p' | sed -E 's/^[0-9]+:([0-9]+).*/\1/')
        if [ "$row2" != "$prev" ]; then
            fail "MRU walk: after switching $prev -> $target, expected row 2 (most recent alternate) to be tab $prev, got tab $row2"
            walk_fail=1
        fi
    fi
    prev="$target"
done
[ "$walk_fail" -eq 0 ] && ok "MRU walk across all $TAB_COUNT tabs: row 1 and row 2 correct at every step"

# --- Check 3: tight concurrent race stress ---
echo
echo "=== Check 3: concurrent race stress (activate + background active-now.py firing together, 10 rounds) ==="
race_fail=0
for i in $(seq 1 10); do
    target=$(( (i % 2) + 1 ))
    # Fire a background active-now.py AND the activation almost
    # simultaneously -- the exact shape of the race the mtime guard
    # exists for.
    ("$PY" "$DIR/active-now.py" >/dev/null 2>&1 &)
    "$PY" "$DIR/activate.py" "$WIN" "$target" >/dev/null 2>&1
    sleep 0.05
    got=$(cat "$FRESH" 2>/dev/null | cut -f2)
    expected_tabid=$(python3 -c "
import json
c = json.load(open('$CACHE'))
for t in c['tabs']:
    if t['win'] == '$WIN' and str(t['index']) == '$target':
        print(t['tab_id']); break
")
    if [ "$got" != "$expected_tabid" ]; then
        fail "race round $i: expected fresh.tsv tab_id $expected_tabid (tab $target), got $got"
        race_fail=1
    fi
done
[ "$race_fail" -eq 0 ] && ok "10/10 rounds: a concurrent background active-now.py never clobbered the fresher activate.py write"

# --- Restore original state ---
echo
echo "=== Restoring original active tab (index $ORIGINAL_ACTIVE) ==="
"$PY" "$DIR/activate.py" "$WIN" "$ORIGINAL_ACTIVE" >/dev/null 2>&1
final=$(row1_index)
[ "$final" = "$ORIGINAL_ACTIVE" ] && ok "restored to the original active tab" || fail "restore failed: expected tab $ORIGINAL_ACTIVE, row 1 shows $final"

echo
echo "torture-toggle: $pass checks passed, $fail_count failed"
[ "$fail_count" -eq 0 ]
