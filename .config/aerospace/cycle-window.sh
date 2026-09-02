#!/bin/bash
# space-tab, instrumented.
#
# TEMPORARY. Wraps `focus dfs-next` to catch an intermittent bug: focus
# sometimes lands on a window in a DIFFERENT workspace, reportedly after a
# workspace has just moved monitors. Direct reproduction failed across ~14
# attempts on 2026-09-02, including a no-delay race test, so this captures the
# evidence in real use instead.
#
# space-tab must NEVER change the focused workspace. When it does, the line is
# tagged so it can be found with one grep:
#
#     grep ANOMALY ~/.local/state/context/space-tab.log
#
# Costs ~50ms of aerospace calls per keypress. Once the log has caught an
# occurrence, delete this file and point :tab straight back at
# `focus dfs-next --wrap-around` in karabiner.edn.

# AeroSpace and Karabiner give children PATH=/usr/bin:/bin:/usr/sbin:/sbin,
# so Homebrew is not on PATH here.
AEROSPACE=/opt/homebrew/bin/aerospace
LOG="$HOME/.local/state/context/space-tab.log"

focused() {
    "$AEROSPACE" list-windows --focused \
        --format '%{monitor-id}|%{workspace}|%{window-id}|%{app-name}' \
        2>/dev/null | head -1
}

visible() {
    "$AEROSPACE" list-workspaces --visible --monitor all \
        --format '%{monitor-id}:%{workspace}' 2>/dev/null | tr '\n' ',' | sed 's/,$//'
}

# Only the BEFORE snapshot may block the keypress, and only the one call whose
# value the anomaly check needs. Four sequential aerospace calls measured 222ms
# per press, which is far too sluggish for a window-cycle key; everything after
# the focus is written from a background subshell instead, so the perceived
# cost is one ~50ms call.
before_focused=$(focused)

# The actual binding. Runs even if logging fails -- instrumentation must never
# break the key.
"$AEROSPACE" focus dfs-next --wrap-around
status=$?

{
    after_focused=$(focused)

    before_ws=$(printf '%s' "$before_focused" | cut -d'|' -f2)
    after_ws=$(printf '%s' "$after_focused" | cut -d'|' -f2)

    flag=""
    if [ -n "$before_ws" ] && [ -n "$after_ws" ] \
        && [ "$before_ws" != "$after_ws" ]; then
        flag=" ANOMALY:workspace-changed:${before_ws}->${after_ws}"
    fi

    mkdir -p "$(dirname "$LOG")" 2>/dev/null
    printf '%s exit=%s before=[%s] after=[%s] vis=[%s]%s\n' \
        "$(date +%Y-%m-%dT%H:%M:%S)" "$status" \
        "${before_focused:-NONE}" "${after_focused:-NONE}" \
        "$(visible)" "$flag" >>"$LOG" 2>/dev/null
} &

exit "$status"
