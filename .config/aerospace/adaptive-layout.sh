#!/bin/bash

STATE_FILE="$HOME/.config/aerospace/layout-preferences"

# AeroSpace's own PATH is /usr/bin:/bin:/usr/sbin:/sbin, and
# exec-and-forget children inherit it, so Homebrew is not on PATH
# here. Call AeroSpace by absolute path.
AEROSPACE="/opt/homebrew/bin/aerospace"

# When called by on-focused-monitor-changed, AeroSpace provides
# AEROSPACE_WORKSPACE. Fall back to the currently focused workspace
# when called from startup.
workspace="${AEROSPACE_WORKSPACE:-$("$AEROSPACE" list-workspaces --focused --format '%{workspace}')}"

monitor=$("$AEROSPACE" list-monitors --focused --format '%{monitor-name}')

case "$monitor" in

  "LG HDR WQHD")
    # Big screen: always use a tiled root.
    "$AEROSPACE" layout --workspace "$workspace" --root tiles
    ;;

  "Built-in Retina Display")
    # Small screen: use the user's saved preference.
    preference=$(awk -F= -v ws="$workspace" '$1 == ws { print $2 }' "$STATE_FILE" 2>/dev/null)

    case "$preference" in
      tiles)
        "$AEROSPACE" layout --workspace "$workspace" --root tiles
        ;;
      accordion)
        "$AEROSPACE" layout --workspace "$workspace" --root accordion
        ;;
      *)
        # No preference yet: accordion is the default.
        "$AEROSPACE" layout --workspace "$workspace" --root accordion
        ;;
    esac
    ;;

esac
