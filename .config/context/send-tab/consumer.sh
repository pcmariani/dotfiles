#!/bin/bash
# send-tab picker consumer -- invoked via `xargs -0` (see pickers.toml),
# which hands this the WHOLE NUL-delimited record as one argument:
# "value<TAB>display", not the value alone -- split it back apart the
# same way chrome-tabs/activate-one.sh does before using either half.
set -euo pipefail
RECORD="$1"
VALUE="${RECORD%%$'\t'*}"

# NOTE: the plan brief for this task wrote `/usr/bin/hs`, but that path
# does not exist on this machine -- `hs` (Hammerspoon's CLI) lives at
# /opt/homebrew/bin/hs (confirmed live this session: `which hs`, and it's
# what every other script in this project already uses -- picker-loop.sh,
# chrome-workspace-steal-guard.sh, torture-steal-guard.sh). Using the real
# path here rather than copying the brief's unverified one.
HS=/opt/homebrew/bin/hs

case "$VALUE" in
  new:*)
    WORKSPACE="${VALUE#new:}"
    "$HS" -c "detachChromeTabAndMoveTo('$WORKSPACE')"
    ;;
  merge:*)
    WINDOW_ID="${VALUE#merge:}"
    "$HS" -c "mergeChromeTabInto($WINDOW_ID)"
    ;;
  *)
    echo "send-tab consumer: unrecognized value '$VALUE'" >&2
    exit 1
    ;;
esac
