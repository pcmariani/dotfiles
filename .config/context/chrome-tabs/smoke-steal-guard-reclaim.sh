#!/bin/bash
# Smoke checks for chrome-workspace-steal-guard.sh's reclaim-first correction,
# 2026-10-30 (cbm-002).
#
# Real bug: a link clicked in Slack made Chrome raise its front window in
# another workspace; the guard "corrected" by breaking the tab out into a NEW
# window in the workspace the user was in, even when that workspace already had
# a Chrome window. The correction now tries `context chrome-reclaim` first (the
# tab moves into that workspace's own Chrome window) and only falls back to the
# break-out when reclaim refuses.
#
# Nothing real is touched: CHROME_TABS_STATE is a tmpdir, and CONTEXT_BIN, HS_BIN
# and AEROSPACE are stubs that record their arguments. The stubs, not the guard,
# decide what each check sees, so every check is about the guard's decision.
set -u

GUARD="${GUARD:-$HOME/.config/context/chrome-workspace-steal-guard.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

export CHROME_TABS_STATE="$TMP/state"
mkdir -p "$CHROME_TABS_STATE"
CALLS="$TMP/calls"

STUB="$TMP/bin"; mkdir -p "$STUB"
# `context` stub: records its arguments, exits with $FAKE_CONTEXT_RC.
cat > "$STUB/context" <<'EOF'
#!/bin/bash
echo "context $*" >> "$CALLS"
exit "${FAKE_CONTEXT_RC:-0}"
EOF
cat > "$STUB/hs" <<'EOF'
#!/bin/bash
echo "hs $*" >> "$CALLS"
EOF
cat > "$STUB/aerospace" <<'EOF'
#!/bin/bash
echo "aerospace $*" >> "$CALLS"
EOF
chmod +x "$STUB"/*
export CALLS CONTEXT_BIN="$STUB/context" HS_BIN="$STUB/hs" AEROSPACE="$STUB/aerospace"
export TIMEOUT_BIN="${TIMEOUT_BIN:-/opt/homebrew/bin/timeout}"

# Sourced the way smoke-steal-guard-deliberate.sh does it, with the same
# tripwire: an undefined function must not read as a pass.
export GUARD_SOURCE_ONLY=1
source "$GUARD"
unset GUARD_SOURCE_ONLY
declare -F do_correction >/dev/null \
  || fail "do_correction not defined after sourcing $GUARD"
ok "guard sourced, do_correction defined"

run() { : > "$CALLS"; FAKE_CONTEXT_RC="$1" do_correction "rjw"; }

run 0
[ "$(sed -n 1p "$CALLS")" = "context chrome-reclaim --workspace rjw" ] \
  || fail "reclaim must be called first with the workspace the user was in: $(cat "$CALLS")"
ok "reclaim is tried first, for the workspace the user was in"
grep -q '^aerospace workspace rjw$' "$CALLS" \
  || fail "a successful reclaim must send the user back to rjw: $(cat "$CALLS")"
grep -q '^hs ' "$CALLS" && fail "a successful reclaim must not also break the tab out"
ok "reclaim succeeded: user sent back, no break-out"

for rc in 11 15 19 21 22 23 1 127; do
  run "$rc"
  grep -q "^hs -c correctChromeSteal('rjw')\$" "$CALLS" \
    || fail "reclaim exit $rc must fall back to the break-out: $(cat "$CALLS")"
  grep -q '^aerospace ' "$CALLS" \
    && fail "reclaim exit $rc must not refocus on its own: $(cat "$CALLS")"
done
ok "any refusal falls back to the break-out, and only that"

for rc in 17 124; do
  run "$rc"
  grep -q '^hs ' "$CALLS" \
    && fail "exit $rc means the tab may have moved: the break-out must not run"
  grep -q '^aerospace ' "$CALLS" \
    && fail "exit $rc: the guard must not refocus either"
done
ok "unknown outcome (17) and timeout (124) do nothing more"

: > "$CALLS"; CONTEXT_BIN="$TMP/does-not-exist" do_correction "rjw"
grep -q "^hs -c correctChromeSteal('rjw')\$" "$CALLS" \
  || fail "a missing context binary must leave today's break-out working: $(cat "$CALLS")"
ok "missing context binary falls back to the break-out"

echo "PASS: $pass checks"
