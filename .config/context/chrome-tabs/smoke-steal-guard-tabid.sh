#!/bin/bash
# Smoke checks for chrome-workspace-steal-guard.sh's tab-id match, 2026-10-25.
#
# Real bug: the guard called a tab "stolen" whenever the front window's active
# (window, url) pair was missing from the poller's cache, which can be 60 s
# old. A tab that redirects ON ITS OWN (the Boomi sign-in chain,
# sso.boomi.com -> byndid -> callback, runs all day in a background Gmail
# tab) changes url but keeps its tab id; switching to that window mid-chain
# got the tab detached and sent to the workspace the user came from (35
# "ARMED: correcting" lines in steal-guard.debug.log, most of them auth
# redirects). A genuinely stolen link is a NEW tab: new id, new url.
#
# Everything is a throwaway tmpdir plus stub aerospace/osascript: nothing
# touches real state, Chrome or the window manager, and GUARD_ARMED stays 0
# so the verdict is the guard's DRY-RUN line (see tests-never-touch-real-state).
set -u

GUARD="${GUARD:-$HOME/.config/context/chrome-workspace-steal-guard.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; }

export CHROME_TABS_STATE="$TMP/state"
mkdir -p "$CHROME_TABS_STATE"
DBG="$CHROME_TABS_STATE/steal-guard.debug.log"

STUB_BIN="$TMP/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/aerospace" <<'STUB'
#!/bin/bash
case "$1" in
  list-windows)    echo "Google Chrome" ;;
  list-workspaces) echo "now-ws" ;;
  *) exit 1 ;;
esac
STUB
cat > "$STUB_BIN/osascript" <<'STUB'
#!/bin/bash
# What the guard's front-window query would print; the test sets FRONT.
printf '%b' "$FRONT"
STUB
chmod +x "$STUB_BIN/aerospace" "$STUB_BIN/osascript"
export AEROSPACE="$STUB_BIN/aerospace" OSASCRIPT_BIN="$STUB_BIN/osascript"
export AEROSPACE_STARTED_EPOCH_OVERRIDE=1000 GUARD_ARMED=0

URL_OLD='https://sso.boomi.com/oauth2/v1/authorize?x=1'
URL_NEW='https://auth.byndid.com/v2/callback?state=abc'
python3 - "$CHROME_TABS_STATE/cache.json" "$URL_OLD" <<'PY'
import json, sys, time
json.dump({"polled_at": time.time(), "front_win": "100", "tabs": [
    {"win": "100", "index": 1, "tab_id": "200", "active": True,
     "title": "t", "url": sys.argv[2]},
    {"win": "100", "index": 2, "tab_id": "201", "active": False,
     "title": "t", "url": "https://mail.google.com/"},
]}, open(sys.argv[1], "w"))
PY

# One guard run with FRONT as the osascript answer; echoes the verdict line.
verdict() {
    FRONT="$1" bash "$GUARD" >/dev/null 2>&1
    tail -n 1 "$DBG"
}
reset() { rm -f "$DBG" "$CHROME_TABS_STATE/last-workspace"; printf 'prev-ws' > "$CHROME_TABS_STATE/last-workspace"; }

reset
out=$(verdict "100\t$URL_NEW\t200")
case "$out" in *"cache_status=known"*) ok "same tab id, new url (self redirect) -> known" ;;
  *) fail "self-redirect must not be corrected, got: $out" ;; esac

reset
out=$(verdict "100\thttps://example.com/stolen\t999")
case "$out" in *"DRY-RUN: would correct"*) ok "new tab id, new url (stolen link) -> would correct" ;;
  *) fail "a stolen link must still be corrected, got: $out" ;; esac

reset
out=$(verdict "100\t$URL_OLD\t999")
case "$out" in *"cache_status=known"*) ok "url already cached under the window -> known (old rule kept)" ;;
  *) fail "cached url must stay known, got: $out" ;; esac

reset
out=$(verdict "100\thttps://example.com/stolen")
case "$out" in *"DRY-RUN: would correct"*) ok "no tab id from Chrome -> falls back to the url rule" ;;
  *) fail "missing tab id must fall back to url matching, got: $out" ;; esac

reset
out=$(verdict "101\thttps://example.com/other\t200")
case "$out" in *"DRY-RUN: would correct"*) ok "tab id cached under a DIFFERENT window -> not known" ;;
  *) fail "a tab id must match within its own window, got: $out" ;; esac

echo "all steal-guard tab-id checks passed"
