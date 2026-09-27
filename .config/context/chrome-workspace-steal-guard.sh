#!/bin/bash
# chrome-workspace-steal-guard.sh
#
# Detects a link opened from ANY app silently dragging the user's focused
# AeroSpace workspace to wherever Chrome's own internal "front window"
# happens to live, and corrects it by detaching the just-added tab back
# to where the user actually was. Full design, including two adversarial
# review passes, at:
# docs/superpowers/specs/2026-09-26-chrome-workspace-steal-guard-design.md
# in context-based-mac (this script itself is NOT tracked in that repo --
# it lives here, alongside picker-refresh.sh, yadm-tracked).
#
# Called from `exec-on-workspace-change` in aerospace.toml, chained BEFORE
# picker-refresh.sh -- see that file's own header comment for why this
# must not be embedded inside picker-refresh.sh instead (its internal
# settle/re-exec loop would multiply firings).
set -u

: "${CHROME_TABS_STATE:=$HOME/.local/state/context/chrome-tabs}"
: "${AEROSPACE:=/opt/homebrew/bin/aerospace}"
: "${HS_BIN:=/opt/homebrew/bin/hs}"
: "${TIMEOUT_BIN:=/opt/homebrew/bin/timeout}"
: "${GUARD_ARMED:=0}"          # 0 = observe/dry-run only, 1 = real corrections
: "${STALENESS_LIMIT:=60}"     # seconds -- see design doc's staleness reasoning
: "${STARTUP_GRACE:=10}"       # seconds since AeroSpace's own process start
: "${ECHO_WINDOW:=5}"          # seconds a correction marker is trusted as "just us"
: "${LOCK_STALE_AFTER:=30}"    # seconds before an orphaned correction.lock is force-cleared

CACHE="$CHROME_TABS_STATE/cache.json"
LAST_WS="$CHROME_TABS_STATE/last-workspace"
MARKER="$CHROME_TABS_STATE/last-corrected-window"
LOCKDIR="$CHROME_TABS_STATE/correction.lock"
DBG="$CHROME_TABS_STATE/steal-guard.debug.log"

/bin/mkdir -p "$CHROME_TABS_STATE"

# Self-capping, same convention as picker-refresh.sh's own debug log --
# kept deliberately while this mechanism is new and hard to reproduce
# synthetically (the real trigger is an actual link-open from another
# app, which no fixture can stand in for).
if [ -f "$DBG" ] && [ "$(/usr/bin/wc -l < "$DBG")" -gt 2000 ]; then
    /usr/bin/tail -n 500 "$DBG" > "$DBG.trim" 2>/dev/null && /bin/mv -f "$DBG.trim" "$DBG"
fi
dbg() { printf '%s pid=%-6s %s\n' "$(date +%H:%M:%S.%N | cut -c1-12)" "$$" "$*" >> "$DBG"; }

# Reads $LAST_WS. Empty on first run / cleared state -- callers must treat
# that as "no known prior workspace", not a workspace literally named "".
read_last_workspace() {
    [ -f "$LAST_WS" ] && cat "$LAST_WS" || true
}

# Temp-then-rename, same pattern as picker-refresh.sh's own prerendered
# file -- a torn write here would hand the NEXT invocation a corrupt
# "before" workspace name.
write_last_workspace() {
    local ws="$1"
    local tmp="$LAST_WS.$$"
    printf '%s' "$ws" > "$tmp" && /bin/mv -f "$tmp" "$LAST_WS"
}

# True (0) if the front window is the exact window this guard's own last
# correction just created, within ECHO_WINDOW seconds -- i.e. this
# invocation is the guard reacting to its own refocus, not a new steal.
# Clears the marker on any read (match or not) so it never lingers as a
# false match for a later, unrelated invocation.
is_reentrant_echo() {
    local win_id="$1"
    [ -f "$MARKER" ] || return 1
    local marked_id marked_ts now age
    IFS=$'\t' read -r marked_id marked_ts < "$MARKER"
    /bin/rm -f "$MARKER"
    [ "$marked_id" = "$win_id" ] || return 1
    now=$(date +%s)
    age=$(( now - marked_ts ))
    [ "$age" -ge 0 ] && [ "$age" -lt "$ECHO_WINDOW" ]
}

# True (0) if AeroSpace itself started less than STARTUP_GRACE seconds
# ago. Whether exec-on-workspace-change fires during AeroSpace's own
# launch was never confirmed live (an actual restart was judged too
# disruptive to force just to test) -- this is the fail-safe instead of
# the untested assumption. The cache-missing check in cache_status
# independently covers most of the same window without needing this
# number to be exactly right.
#
# AEROSPACE_STARTED_EPOCH_OVERRIDE / NOW_OVERRIDE exist ONLY so tests can
# exercise this without touching the real AeroSpace process -- never set
# them outside a test.
in_startup_grace_period() {
    local started_epoch now
    if [ -n "${AEROSPACE_STARTED_EPOCH_OVERRIDE:-}" ]; then
        started_epoch="$AEROSPACE_STARTED_EPOCH_OVERRIDE"
    else
        local pid
        pid=$(pgrep -x AeroSpace | head -1)
        [ -n "$pid" ] || return 1
        started_epoch=$(ps -o lstart= -p "$pid" 2>/dev/null \
            | xargs -I{} date -j -f '%a %b %d %T %Y' '{}' +%s 2>/dev/null)
        [ -n "$started_epoch" ] || return 1
    fi
    now=${NOW_OVERRIDE:-$(date +%s)}
    [ $(( now - started_epoch )) -lt "$STARTUP_GRACE" ]
}

# Prints one of: known | unknown | untrustworthy
#
# "known": this exact (window, url) pair is in a fresh cache -- a real,
# deliberate focus change, not a steal.
# "unknown": cache is fresh but has no row matching this (window, url) --
# likely a just-created tab.
# "untrustworthy": cache is missing, unreadable, or older than
# STALENESS_LIMIT -- treated the same as "known" (do nothing), because an
# untrustworthy cache cannot support a correction decision either way.
#
# Matches ANY cached row for the window id, ignoring poll.py's `active`
# flag -- that flag is only ever true for whichever window was frontmost
# at POLL time, not necessarily this window, so matching on it would
# misfire on ordinary switches into a background window (design doc
# review finding #2).
cache_status() {
    local win_id="$1" url="$2"
    [ -f "$CACHE" ] || { echo untrustworthy; return; }
    python3 - "$CACHE" "$win_id" "$url" "$STALENESS_LIMIT" <<'PYEOF'
import json, sys, time
cache_path, win_id, url, staleness_limit = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
try:
    data = json.load(open(cache_path))
except (OSError, json.JSONDecodeError):
    print("untrustworthy")
    sys.exit()
polled_at = data.get("polled_at")
if polled_at is None or (time.time() - polled_at) > staleness_limit:
    print("untrustworthy")
    sys.exit()
for t in data.get("tabs", []):
    if t.get("win") == win_id and t.get("url") == url:
        print("known")
        sys.exit()
print("unknown")
PYEOF
}

# mkdir is the atomic test-and-set, same convention as picker-refresh.sh's
# own $LOCK. Additionally force-clears a lock older than LOCK_STALE_AFTER
# seconds before trying -- a killed/crashed correction (user logout,
# force-quit) must not wedge every future correction permanently.
acquire_correction_lock() {
    if [ -d "$LOCKDIR" ]; then
        local age
        age=$(( $(date +%s) - $(stat -f %m "$LOCKDIR" 2>/dev/null || echo 0) ))
        if [ "$age" -gt "$LOCK_STALE_AFTER" ]; then
            dbg "correction.lock stale (age=${age}s), force-clearing"
            /bin/rmdir "$LOCKDIR" 2>/dev/null
        fi
    fi
    /bin/mkdir "$LOCKDIR" 2>/dev/null
}

current_workspace() {
    "$AEROSPACE" list-workspaces --focused 2>/dev/null
}

current_app() {
    "$AEROSPACE" list-windows --focused --format '%{app-name}' 2>/dev/null
}

# Single targeted query for window 1's (frontmost's) id and active tab
# URL -- ~0.2s measured, not the ~0.5-0.85s of enumerating every window,
# because this now runs on EVERY workspace change, not just a switcher
# reveal. Prints "windowId<TAB>url" on success, nothing on failure (Chrome
# not running, no windows, etc). Window 1 is, by construction, whichever
# window Chrome just raised -- the same one that caused this callback to
# fire in the first place (see the design doc's mechanism section).
chrome_front_window_url() {
    /usr/bin/osascript -e '
tell application "Google Chrome"
    if (count of windows) is 0 then return ""
    set w to window 1
    return ((id of w) as text) & "\t" & (URL of active tab of w)
end tell' 2>/dev/null
}

# Backgrounds the actual correction, timeout-wrapped so a hang (an
# accessibility prompt, Chrome modal, busy Hammerspoon) can never block
# AeroSpace's own hook regardless of whether that hook turns out to be
# synchronous (design doc review finding #4). The lock is released by
# this same subshell's trap, so it spans the correction's real lifetime
# even though THIS script exits long before the correction finishes.
run_correction() {
    local prev_ws="$1"
    if [[ "$prev_ws" == *"'"* ]]; then
        dbg "REFUSING correction: workspace name '$prev_ws' contains a quote, unsafe to embed in hs -c"
        /bin/rmdir "$LOCKDIR" 2>/dev/null
        return
    fi
    (
        trap '/bin/rmdir "'"$LOCKDIR"'" 2>/dev/null' EXIT
        "$TIMEOUT_BIN" 5 "$HS_BIN" -c "correctChromeSteal('$prev_ws')" \
            >> "$DBG" 2>&1
    ) &
    disown
}

main() {
    local prev_ws current_app_name front_win_url win_id url decision

    prev_ws=$(read_last_workspace)
    current_app_name=$(current_app)

    if [ "$current_app_name" != "Google Chrome" ]; then
        write_last_workspace "$(current_workspace)"
        return 0
    fi

    front_win_url=$(chrome_front_window_url)
    if [ -z "$front_win_url" ]; then
        dbg "no chrome front window/url available"
        write_last_workspace "$(current_workspace)"
        return 0
    fi
    win_id=${front_win_url%%$'\t'*}
    url=${front_win_url#*$'\t'}

    if is_reentrant_echo "$win_id"; then
        dbg "ECHO recognized for window=$win_id, skipping correction"
        write_last_workspace "$(current_workspace)"
        return 0
    fi

    if in_startup_grace_period; then
        dbg "startup grace period active, skipping correction for window=$win_id"
        write_last_workspace "$(current_workspace)"
        return 0
    fi

    decision=$(cache_status "$win_id" "$url")
    if [ "$decision" != "unknown" ]; then
        dbg "window=$win_id url=$url cache_status=$decision, no correction"
        write_last_workspace "$(current_workspace)"
        return 0
    fi

    if [ -z "$prev_ws" ]; then
        dbg "window=$win_id url=$url looks like a steal but no prior workspace known (first run), skipping"
        write_last_workspace "$(current_workspace)"
        return 0
    fi

    if [ "$GUARD_ARMED" != "1" ]; then
        dbg "DRY-RUN: would correct window=$win_id url=$url into workspace=$prev_ws"
        write_last_workspace "$(current_workspace)"
        return 0
    fi

    if ! acquire_correction_lock; then
        dbg "correction already in progress (lock held), skipping window=$win_id"
        write_last_workspace "$(current_workspace)"
        return 0
    fi

    dbg "ARMED: correcting window=$win_id url=$url into workspace=$prev_ws"
    run_correction "$prev_ws"
    write_last_workspace "$(current_workspace)"
}

if [ "${GUARD_SOURCE_ONLY:-0}" != "1" ]; then
    main "$@"
fi

