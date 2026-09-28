#!/bin/bash
# Smoke checks for activate.py's fresh.tsv AND frecency.json writes,
# 2026-09-26.
#
# Real regression #1: the night before, active-now.py's synchronous
# 0.75-0.84s AppleScript call was backgrounded to fix "doesn't respond
# when I hammer" -- but that traded away the freshness the switcher's own
# TOGGLE gesture depends on (switch to tab B, then immediately re-invoke
# to switch back to tab A). The background active-now.py run often
# hadn't caught up yet, so rank.py kept marking the OLD tab active --
# reported live as "stuck on the second position, toggle doesn't work".
# activate.py already knows the answer with zero extra cost (it is the
# thing that just made the switch), so it now writes fresh.tsv itself,
# instantly, right after the switch.
#
# Real regression #2, found by the user's own "test it like crazy"
# torture test (torture-toggle.sh) the SAME night, minutes after
# regression #1's fix shipped: fixing row 1 (the active marker) was not
# enough -- row 2, the pre-highlighted MRU alternate, is ranked from
# frecency.json, which was STILL only written by poll.py's slow
# (1.6-2.8s) backgrounded enumeration. Walking through 5 real tabs in
# sequence, row 2 never caught up to the walk at all. Fixed the same
# way: activate.py now writes frecency.json itself too.
#
# STATE_DIR/CACHE_FILE/FRESH_FILE/FRECENCY_FILE are monkeypatched to a
# throwaway tmpdir for every check -- this must never touch real state
# (see memory tests-never-touch-real-state.md). switcher_log's own
# STATE_DIR/LOG_FILE are ALSO redirected, 2026-09-27 -- activate.py's
# top-level `from switcher_log import log` was writing every check's
# fixture titles into the REAL switcher.debug.log otherwise (same fix
# applied to smoke-active-now.sh/smoke-rank.sh; see their comments).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

# A real cache.json shape, two windows worth of tabs, so a lookup that
# ignored `win` (only matched `index`) would silently pick the wrong one.
cat > "$TMP/cache.json" <<'JSON'
{"polled_at": 0, "front_win": "111", "tabs": [
    {"win": "111", "index": 1, "tab_id": "t1", "active": true, "title": "A", "url": "https://a.example"},
    {"win": "111", "index": 2, "tab_id": "t2", "active": false, "title": "B", "url": "https://b.example"},
    {"win": "222", "index": 2, "tab_id": "wrong-window-t2", "active": false, "title": "Decoy", "url": "https://decoy.example"}
]}
JSON

run_case() {
    local win_id="$1" tab_index="$2"
    python3 -c "
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('activate_mod', '$HERE/activate.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.CACHE_FILE = m.STATE_DIR / 'cache.json'
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.FRECENCY_FILE = m.STATE_DIR / 'frecency.json'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

class FakeProc:
    returncode = 0
    stderr = ''
def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

# Default: the isolation gate confirms a match, so these pre-existing
# checks (about fresh.tsv/frecency.json writes) exercise ONLY what they
# already tested -- the gate itself is proven separately below.
m.aerospace = lambda *a: 'Matching Title'
m.window_title = lambda win_id: 'Matching Title'

sys.argv = ['activate.py', '$win_id', '$tab_index']
raise SystemExit(m.main())
"
}

run_case 111 2 >/dev/null
fresh="$(cat "$TMP/fresh.tsv" 2>/dev/null)"
case "$fresh" in
    "111	t2") ok "fresh.tsv gets the switched-to tab's own tab_id, matched by (win, index)" ;;
    *) fail "expected fresh.tsv to hold '111\\tt2', got: [$fresh]" ;;
esac

rm -f "$TMP/fresh.tsv"
run_case 999 1 >/dev/null
case "$([ -f "$TMP/fresh.tsv" ] && echo present || echo absent)" in
    absent) ok "an unmatched (win, index) leaves fresh.tsv untouched rather than writing garbage" ;;
    *) fail "expected no fresh.tsv for an unmatched window/index, but one was written" ;;
esac

# fresh.tsv MERGES rather than overwrites, 2026-09-28 (per-workspace
# rewrite): switching a tab in window 111 must not erase window 222's own
# still-good entry, already sitting in fresh.tsv from an earlier switch
# (or from active-now.py's own background enumeration).
rm -f "$TMP/fresh.tsv"
printf '222\tt9\n' > "$TMP/fresh.tsv"
run_case 111 2 >/dev/null
fresh="$(cat "$TMP/fresh.tsv" 2>/dev/null)"
case "$fresh" in
    *"222	t9"*) ;;
    *) fail "expected window 222's prior entry to survive the merge, got: [$fresh]" ;;
esac
case "$fresh" in
    *"111	t2"*) ;;
    *) fail "expected window 111's new entry after the merge, got: [$fresh]" ;;
esac
line_count="$(printf '%s\n' "$fresh" | grep -c .)"
[ "$line_count" -eq 2 ] || fail "expected exactly 2 lines after the merge, got $line_count: [$fresh]"
ok "fresh.tsv merges the switched window's entry, leaving other windows' entries untouched"

# frecency.json: the switched-to tab's URL gets a fresh entry, and
# _last_active_url is set so poll.py's own catch-up run does not
# re-record the same visit a second time.
rm -f "$TMP/fresh.tsv" "$TMP/frecency.json"
run_case 111 2 >/dev/null
frec_check="$(python3 -c "
import json
f = json.load(open('$TMP/frecency.json'))
row = f.get('https://b.example')
assert row is not None, 'no entry for the activated tab URL'
assert row['count'] == 1, f'expected count 1, got {row[\"count\"]}'
assert row['title'] == 'B', f'expected title B, got {row[\"title\"]}'
assert f.get('_last_active_url') == 'https://b.example', 'transition marker not updated'
print('ok')
" 2>&1)"
case "$frec_check" in
    ok) ok "frecency.json gets a fresh entry for the switched-to tab, instantly" ;;
    *) fail "frecency.json write incorrect: $frec_check" ;;
esac

# A SECOND activation of the SAME tab increments count and bumps
# last_seen forward -- proves this is a real update, not a one-shot
# create-only path that would silently stop tracking recency after the
# first visit.
sleep 0.05
run_case 111 2 >/dev/null
frec_check2="$(python3 -c "
import json
f = json.load(open('$TMP/frecency.json'))
row = f['https://b.example']
assert row['count'] == 2, f'expected count 2 after a second visit, got {row[\"count\"]}'
print('ok')
" 2>&1)"
case "$frec_check2" in
    ok) ok "a second activation of the same tab increments its frecency count" ;;
    *) fail "second-visit update incorrect: $frec_check2" ;;
esac

# --- The isolation gate itself, added 2026-09-27 after a live, real
# reproduction: a NEW Chrome window opened inside an ALREADY-focused
# workspace left fresh.tsv/cache.json pointing at a stale window in a
# DIFFERENT workspace, and confirming a row dragged the user there.
run_gated_case() {
    local win_id="$1" tab_index="$2" focused_title="$3" my_title="$4"
    python3 -c "
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('activate_mod', '$HERE/activate.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.CACHE_FILE = m.STATE_DIR / 'cache.json'
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.FRECENCY_FILE = m.STATE_DIR / 'frecency.json'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

class FakeProc:
    returncode = 0
    stderr = 'should never be reached when the gate refuses'
def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

m.aerospace = lambda *a: '$focused_title' if a[0] == 'list-windows' else 'ai'
m.window_title = lambda win_id: '$my_title'

sys.argv = ['activate.py', '$win_id', '$tab_index']
sys.exit(m.main())
"
    echo "exit=$?"
}

# The exact reproduction: the target window's OWN title ("Context Mac
# Status", the stale/wrong workspace's window) does NOT match the
# CURRENTLY FOCUSED workspace's real Chrome window title ("Google Gemini
# - Google Chrome - Peter") -- must refuse, not switch.
rm -f "$TMP/fresh.tsv"
gate_out="$(run_gated_case 111 2 'Google Gemini - Google Chrome - Peter' 'Context Mac Status')"
if echo "$gate_out" | grep -q "exit=3" && [ ! -f "$TMP/fresh.tsv" ]; then
    ok "isolation gate REFUSES a window that is not in the currently focused workspace, exit=3, no fresh.tsv write"
else
    fail "expected the gate to refuse (exit=3, no fresh.tsv write), got: $gate_out, fresh.tsv=$([ -f "$TMP/fresh.tsv" ] && echo present || echo absent)"
fi

# The matching case: the target window's title DOES match (by the same
# longest-prefix rule active-now.py uses) -- must proceed normally.
rm -f "$TMP/fresh.tsv"
gate_out2="$(run_gated_case 111 2 'Google Gemini - Google Chrome - Peter' 'Google Gemini')"
if echo "$gate_out2" | grep -q "exit=0"; then
    ok "isolation gate ALLOWS a window that IS in the currently focused workspace"
else
    fail "expected the gate to allow a real match, got: $gate_out2"
fi

# A failed/timed-out aerospace query must fail CLOSED (refuse), not open.
rm -f "$TMP/fresh.tsv"
gate_out3="$(python3 -c "
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('activate_mod', '$HERE/activate.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.STATE_DIR = pathlib.Path('$TMP')
m.CACHE_FILE = m.STATE_DIR / 'cache.json'
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.FRECENCY_FILE = m.STATE_DIR / 'frecency.json'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'
m.aerospace = lambda *a: None
m.window_title = lambda win_id: 'Anything'
sys.argv = ['activate.py', '111', '2']
sys.exit(m.main())
"; echo "exit=$?")"
if echo "$gate_out3" | grep -q "exit=3"; then
    ok "isolation gate fails CLOSED when aerospace cannot be reached (refuses, does not assume yes)"
else
    fail "expected fail-closed on an aerospace failure, got: $gate_out3"
fi

echo "smoke-activate: $pass checks passed"
