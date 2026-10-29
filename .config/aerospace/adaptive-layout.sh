#!/bin/bash
#
# Set each visible workspace's root layout from the monitor it is on:
#   LG HDR WQHD              -> tiles, always
#   Built-in Retina Display  -> the saved per-workspace preference
#                               (~/.config/aerospace/layout-preferences, written
#                               by set-layout.sh), accordion when there is none
#
# Runs from on-focused-monitor-changed and at startup.
#
# IT ASKS ONCE, ABOUT EVERY VISIBLE WORKSPACE, AND NEVER ABOUT "WHAT IS FOCUSED".
# The first version asked for the focused workspace and, in a second call about
# 33 ms later, the focused monitor. Cross monitors again inside that gap (ctrl-j,
# ctrl-k held or tapped quickly) and it paired one workspace with the other
# monitor's rule, flipping a workspace between tiles and accordion until a later
# crossing fixed it (seen 2026-10-29). Here the workspace, its monitor and its
# current layout come back in ONE reply, so a late or overlapping run applies the
# same correct answer as an early one. It also changes only what is wrong, so a
# crossing that needs nothing costs one AeroSpace call, not three.
#
# Tests: tests/test_adaptive_layout.py in context-based-mac (stubs aerospace).

STATE_FILE="${LAYOUT_PREFERENCES:-$HOME/.config/aerospace/layout-preferences}"

# AeroSpace's own PATH is /usr/bin:/bin:/usr/sbin:/sbin, and
# exec-and-forget children inherit it, so Homebrew is not on PATH
# here. Call AeroSpace by absolute path.
AEROSPACE="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"

visible=$("$AEROSPACE" list-workspaces --monitor all --visible \
    --format '%{workspace}|%{monitor-name}|%{workspace-root-container-layout}') || exit 1

while IFS='|' read -r workspace monitor current; do
    [ -n "$workspace" ] || continue

    case "$monitor" in
        "LG HDR WQHD")
            # Big screen: always use a tiled root.
            want=tiles
            ;;
        "Built-in Retina Display")
            # Small screen: use the user's saved preference, accordion by default.
            want=$(awk -F= -v ws="$workspace" '$1 == ws { print $2 }' "$STATE_FILE" 2>/dev/null | tail -n 1)
            [ "$want" = tiles ] || want=accordion
            ;;
        *)
            continue
            ;;
    esac

    # `current` is h_tiles, v_tiles, h_accordion or v_accordion.
    [ "${current#*_}" = "$want" ] && continue
    "$AEROSPACE" layout --workspace "$workspace" --root "$want"
done <<EOF
$visible
EOF
