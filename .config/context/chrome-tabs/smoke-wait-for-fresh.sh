#!/bin/bash
# Smoke checks for wait-for-fresh.py -- the bounded wait fixing the
# still-open half of the cmd-backtick bug (see that file's own docstring
# for the three-versions-of-this-fix history: window-recent timestamp,
# then "postdate my own start", then this one -- lock-based).
#
# FRESH_FILE monkeypatched to a throwaway tmpdir, and `now`/`sleep`/
# `is_running` are fakes driven by the test, not the wall clock or a real
# lock file -- this must never touch real state (memory:
# tests-never-touch-real-state.md) and must never actually sleep.
set -u

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

HERE="$(cd "$(dirname "$0")" && pwd)"

run_case() {
    python3 -c "
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('waitmod', '$HERE/wait-for-fresh.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.FRESH_FILE = pathlib.Path('$TMP/fresh.tsv')
$1
"
}

# Case 1: active-now.py's lock is NOT held (the toggle/rapid-commit case --
# activate.py already wrote fresh.tsv instantly, nothing is in flight).
# Must read immediately, zero sleeps -- this is the exact regression the
# previous ("postdate my own start") version introduced.
rm -f "$TMP/fresh.tsv"
echo -n "111	222" > "$TMP/fresh.tsv"
out="$(run_case "
calls = []
result = m.wait_for_fresh(now=lambda: 1000.0, sleep=lambda s: calls.append(s), is_running=lambda: False)
assert result == '111\t222', repr(result)
assert calls == [], f'nothing in flight, should not have slept at all: {calls}'
print('ok')
")"
[ "$out" = "ok" ] && ok "lock not held (activate.py's own instant write) -> immediate read, no wait" || fail "case 1: $out"

# Case 2: lock IS held at start (a real active-now.py run in flight), and
# releases partway through the wait budget -- must poll and then read
# whatever fresh.tsv holds once it releases.
rm -f "$TMP/fresh.tsv"
echo -n "stale	answer" > "$TMP/fresh.tsv"
out="$(run_case "
state = {'t': 1000.0, 'polls': 0, 'locked': True}
def fake_now():
    return state['t']
def fake_sleep(s):
    state['polls'] += 1
    state['t'] += s
    if state['polls'] == 3:
        state['locked'] = False
        with open('$TMP/fresh.tsv', 'w') as f:
            f.write('fresh\tanswer')
def fake_is_running():
    return state['locked']

result = m.wait_for_fresh(now=fake_now, sleep=fake_sleep, is_running=fake_is_running)
assert result == 'fresh\tanswer', repr(result)
assert state['polls'] == 3, f'expected exactly 3 polls before the lock released, got {state[\"polls\"]}'
print('ok')
")"
[ "$out" = "ok" ] && ok "lock held, releases mid-wait -> polls stop as soon as it releases, reads the fresh content" || fail "case 2: $out"

# Case 3: lock stays held for the ENTIRE budget (a pathologically slow run,
# or the documented 33s-stall case) -- must give up and return whatever is
# there anyway, bounded, never hanging.
rm -f "$TMP/fresh.tsv"
echo -n "stale	answer" > "$TMP/fresh.tsv"
out="$(run_case "
state = {'t': 1000.0}
def fake_now():
    return state['t']
def fake_sleep(s):
    state['t'] += s
def fake_is_running():
    return True  # never releases

result = m.wait_for_fresh(now=fake_now, sleep=fake_sleep, is_running=fake_is_running)
assert result == 'stale\tanswer', repr(result)
assert state['t'] >= 1000.0 + m.WAIT_BUDGET_S, f'did not exhaust the wait budget: {state[\"t\"]}'
assert state['t'] < 1000.0 + m.WAIT_BUDGET_S + m.POLL_INTERVAL_S * 2, f'ran well past budget, not bounded: {state[\"t\"]}'
print('ok')
")"
[ "$out" = "ok" ] && ok "lock never releases -> returns stale content anyway, bounded by WAIT_BUDGET_S" || fail "case 3: $out"

# Case 4: fresh.tsv does not exist at all -- clean empty result regardless
# of lock state, no exception.
rm -f "$TMP/fresh.tsv"
out="$(run_case "
result = m.wait_for_fresh(now=lambda: 1000.0, sleep=lambda s: None, is_running=lambda: False)
assert result == '', repr(result)
print('ok')
")"
[ "$out" = "ok" ] && ok "missing fresh.tsv -> clean empty result, no exception" || fail "case 4: $out"

# Case 5: the REAL lock file, exercised for real (no fakes) -- proves
# is_active_now_running() actually detects a real flock held by another
# process, not just the fake in the above cases.
rm -f "$TMP/active-now.lock"
python3 -c "
import fcntl, os, time
fh = open('$TMP/active-now.lock', 'a')
fcntl.flock(fh, fcntl.LOCK_EX)
os.write(1, b'locked\n')
time.sleep(0.3)
" &
HOLDER_PID=$!
sleep 0.1
out="$(python3 -c "
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location('waitmod', '$HERE/wait-for-fresh.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.LOCK_FILE = pathlib.Path('$TMP/active-now.lock')
print(m.is_active_now_running())
")"
wait "$HOLDER_PID" 2>/dev/null
[ "$out" = "True" ] && ok "is_active_now_running() detects a REAL flock held by another process" || fail "case 5: expected True while the real lock was held, got: $out"

echo "smoke-wait-for-fresh: $pass checks passed"
