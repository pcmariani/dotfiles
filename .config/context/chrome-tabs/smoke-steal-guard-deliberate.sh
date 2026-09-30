#!/bin/bash
# Smoke checks for chrome-workspace-steal-guard.sh's deliberate-action
# suppression, 2026-09-30.
#
# Real bug: shift-opt-`'s cross-workspace merge (mergeChromeTabInto) made
# Chrome raise the destination window, AeroSpace followed, the guard fired
# and -- seeing a (window, url) pair the poller had never cached under
# that window -- "corrected" by detaching the just-merged tab back out.
# Reproduced live with disposable windows before the fix, passing after.
# The fix: init.lua writes an absolute expiry epoch to `deliberate-until`
# before touching Chrome; the guard's deliberate_action_in_flight() stands
# down while it is unexpired.
#
# CHROME_TABS_STATE is a throwaway tmpdir for every check -- this must
# never touch real state (see memory tests-never-touch-real-state.md).
# The guard's own dbg log, last-workspace and marker files all live under
# it. AEROSPACE is a stub so main() never talks to the real window
# manager. The one thing the negative main() check may reach is a
# READ-ONLY osascript query of Chrome's front window URL, which the guard
# does before deciding "untrustworthy cache, no correction" -- nothing is
# written or moved.
set -u

GUARD="${GUARD:-$HOME/.config/context/chrome-workspace-steal-guard.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

export CHROME_TABS_STATE="$TMP/state"
mkdir -p "$CHROME_TABS_STATE"
DELIB="$CHROME_TABS_STATE/deliberate-until"

# Stub aerospace: always "Chrome is frontmost, workspace is stub-ws".
STUB_BIN="$TMP/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/aerospace" <<'EOF'
#!/bin/bash
case "$1" in
  list-windows)    echo "Google Chrome" ;;
  list-workspaces) echo "stub-ws" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$STUB_BIN/aerospace"
export AEROSPACE="$STUB_BIN/aerospace"

# --- Unit checks on the predicate itself ---
# NOT `source <(GUARD_SOURCE_ONLY=1 cat "$GUARD")` (torture-steal-guard.sh's
# idiom): that sets the variable for `cat`, not for the sourced code, so
# main() runs during the source. Found 2026-09-30 when the first cut of
# this file "passed" six checks with the function never defined --
# `undefined && fail` is silently a pass. The `declare -F` check below is
# the tripwire for that class of false pass.
export GUARD_SOURCE_ONLY=1
source "$GUARD"
unset GUARD_SOURCE_ONLY
declare -F deliberate_action_in_flight >/dev/null \
  || fail "deliberate_action_in_flight not defined after sourcing $GUARD"
ok "guard sourced, predicate defined"

rm -f "$DELIB"
deliberate_action_in_flight && fail "no marker file must read as not-in-flight"
ok "no marker file -> not in flight"

printf '' > "$DELIB"
deliberate_action_in_flight && fail "empty marker must read as not-in-flight"
ok "empty marker -> not in flight"

printf 'garbage\n' > "$DELIB"
deliberate_action_in_flight && fail "non-numeric marker must read as not-in-flight"
ok "non-numeric marker -> not in flight"

printf '1000\n' > "$DELIB"
NOW_OVERRIDE=1005 deliberate_action_in_flight && fail "expired marker (now > until) must read as not-in-flight"
ok "expired marker -> not in flight"

printf '1000\n' > "$DELIB"
NOW_OVERRIDE=1000 deliberate_action_in_flight && fail "marker at exactly now must read as expired"
ok "marker == now -> expired (strict less-than)"

printf '1000\n' > "$DELIB"
NOW_OVERRIDE=999 deliberate_action_in_flight || fail "unexpired marker must read as in-flight"
ok "unexpired marker -> in flight"

# Shape init.lua actually writes: os.time()+8 followed by newline.
printf '%s\n' "$(( $(date +%s) + 8 ))" > "$DELIB"
deliberate_action_in_flight || fail "a marker as init.lua writes it must read as in-flight with the real clock"
ok "real-clock marker as init.lua writes it -> in flight"

# --- Integration: main() stands down early on an unexpired marker ---
DBG="$CHROME_TABS_STATE/steal-guard.debug.log"
rm -f "$DBG"
printf '%s\n' "$(( $(date +%s) + 8 ))" > "$DELIB"
GUARD_ARMED=1 bash "$GUARD"
grep -q "DELIBERATE Chrome move in flight" "$DBG" 2>/dev/null \
  || fail "main() with an unexpired marker must log the DELIBERATE skip (got: $(cat "$DBG" 2>/dev/null))"
grep -q "ARMED: correcting" "$DBG" && fail "main() must never reach a correction while a deliberate move is in flight"
[ "$(cat "$CHROME_TABS_STATE/last-workspace")" = "stub-ws" ] \
  || fail "main() must still write last-workspace on the deliberate-skip path"
ok "main(): unexpired marker -> DELIBERATE skip logged, no correction, last-workspace still written"

# --- Integration: an expired marker does NOT stand down ---
rm -f "$DBG"
printf '1000\n' > "$DELIB"
GUARD_ARMED=1 bash "$GUARD"
grep -q "DELIBERATE Chrome move in flight" "$DBG" 2>/dev/null \
  && fail "main() with an expired marker must NOT take the deliberate-skip path"
ok "main(): expired marker -> proceeds past the deliberate check"

echo
echo "all $pass checks passed"
