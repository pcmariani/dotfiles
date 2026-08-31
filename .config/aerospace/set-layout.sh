#!/bin/bash

STATE_FILE="$HOME/.config/aerospace/layout-preferences"
LAYOUT="$1"

# Karabiner launches this with a minimal PATH that has no Homebrew,
# so call AeroSpace by absolute path.
AEROSPACE="/opt/homebrew/bin/aerospace"

if [[ "$LAYOUT" != "tiles" && "$LAYOUT" != "accordion" ]]; then
  echo "Usage: $0 tiles|accordion" >&2
  exit 1
fi

mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

workspace=$("$AEROSPACE" list-workspaces --focused --format '%{workspace}')
monitor=$("$AEROSPACE" list-monitors --focused --format '%{monitor-name}')

# Remember manual layout choices made on the small display.
if [[ "$monitor" == "Built-in Retina Display" ]]; then
  tmp="${STATE_FILE}.tmp"

  awk -F= -v ws="$workspace" -v layout="$LAYOUT" '
        $1 != ws { print }
        END { print ws "=" layout }
    ' "$STATE_FILE" >"$tmp"

  mv "$tmp" "$STATE_FILE"
fi

# Apply the requested layout using your existing orientation behavior.
"$AEROSPACE" layout "$LAYOUT" horizontal vertical
