#!/bin/bash
# send-tab picker producer -- FRESH every reveal, no cache (this panel is
# non-armed; see the design spec's "Panel arming" section for why).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

SOURCE_ID=$(/opt/homebrew/bin/aerospace list-windows --focused --format "%{window-id}")

# `context list` has no bare-name-list flag (checked this session: its only
# flag is `--json`, and the plain-text form is a formatted table, not a
# parseable name list) -- `--json` gives `[{"name": ..., "path": ..., ...}]`
# (context/format.py's `format_json`), so names are pulled out of that.
export SEND_TAB_WORKSPACES_JSON
SEND_TAB_WORKSPACES_JSON=$(/Users/petermariani/.local/bin/context list --json)

export SEND_TAB_CHROME_WINDOWS_JSON
SEND_TAB_CHROME_WINDOWS_JSON=$(/opt/homebrew/bin/aerospace list-windows --all --json \
  --format "%{workspace} %{app-name} %{window-id} %{window-title}")

export SEND_TAB_SOURCE_ID="$SOURCE_ID"

# Passed via environment, not interpolated into the Python source string --
# a workspace name or window title containing a quote character would
# otherwise silently corrupt the script (this project has been burned by
# exactly this class of cross-process string-handling bug before, e.g. the
# chrome-tabs switcher's NUL-delimited-record handling).
python3 -c "
import json, os, sys
sys.path.insert(0, '$HERE')
from rows import build_rows

workspaces = [c['name'] for c in json.loads(os.environ['SEND_TAB_WORKSPACES_JSON'])]
raw = json.loads(os.environ['SEND_TAB_CHROME_WINDOWS_JSON'])
windows = [
    {'workspace': w['workspace'], 'window_id': w['window-id'], 'title': w['window-title']}
    for w in raw if w['app-name'] == 'Google Chrome'
]
source_id = int(os.environ['SEND_TAB_SOURCE_ID'])
rows = build_rows(workspaces, windows, source_window_id=source_id)
for display, value in rows:
    sys.stdout.write(value + '\t' + display + '\0')
"
