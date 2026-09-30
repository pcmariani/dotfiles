#!/bin/bash
# LIVE check of the split-size hotkeys (cmd-ctrl-alt-] and [), through the
# REAL bound hotkeys (synthetic key events, not a direct call into the module)
# against disposable Chrome windows in a throwaway workspace on the LG.
#
# Shares are measured here from hs.window frames, independently of
# splitsize.lua's own arithmetic -- the module cannot grade itself.
#
# SAFETY: every press is preceded by a check that the focused window is one of
# THIS run's own disposable windows; otherwise the run aborts rather than
# resize a real window. Cleanup closes only those windows and returns to the
# original workspace.
#
# Needs the screen unlocked and an LG display (Chrome's ~626px minimum width
# clamps a 75% split on the small built-in screen, which would read as a
# failure that is not one).
set -u
AERO=/opt/homebrew/bin/aerospace
HS=/opt/homebrew/bin/hs
TAG="$$"
WS="zz-split-$TAG"
ORIGINAL_WS=$($AERO list-workspaces --focused)
IDS_LIST=""
fails=0

cg_for() { $AERO list-windows --all --format "%{window-id}|%{app-name}|%{window-title}" \
  | awk -F'|' -v p="$1" '$2=="Google Chrome" && index($3,p)==1 {print $1; exit}'; }

cleanup() {
  echo "--- cleanup ---"
  # Switch back FIRST, then close. Closing the last window of the focused
  # workspace bounces focus somewhere else (memory:
  # aerospace-close-last-window-focus-bounce); the first version closed
  # first and left focus parked on the throwaway workspace.
  $AERO workspace "$ORIGINAL_WS" >/dev/null 2>&1
  sleep 0.5
  for id in $IDS_LIST; do
    timeout 10 $HS -c "local w=hs.window($id); if w then w:close() end" >/dev/null 2>&1
  done
  sleep 0.8
  $AERO workspace "$ORIGINAL_WS" >/dev/null 2>&1
  echo "back on: $($AERO list-workspaces --focused)"
}
trap cleanup EXIT

new_window() {  # $1 = letter; echoes CGWindowID
  osascript -e "tell application \"Google Chrome\"
    set w to make new window
    set URL of active tab of w to \"data:text/html,<title>Split$1-$TAG</title>$1\"
  end tell" >/dev/null
  # Poll, don't sleep a fixed time: with a busy Chrome, AeroSpace lists the
  # new window several seconds late (a fixed 1.5s aborted the first run and
  # left two stray windows behind).
  local id="" i
  for i in $(seq 1 24); do
    id=$(cg_for "Split$1-$TAG")
    [ -n "$id" ] && break
    sleep 0.5
  done
  echo "$id"
}

# Prints "id:x:w" for each disposable window.
frames() {
  local ids_lua; ids_lua=$(echo $IDS_LIST | tr ' ' ',')
  timeout 10 $HS -c "local t={} for _,id in ipairs({$ids_lua}) do local f=hs.window(id):frame(); t[#t+1]=id..':'..math.floor(f.x)..':'..math.floor(f.w) end return table.concat(t,' ')" 2>&1
}

# $1 = focused id. Prints the focused window's share of the row span, 1 decimal.
share_of() {
  python3 - "$1" "$(frames)" <<'EOF'
import sys
fid, raw = sys.argv[1], sys.argv[2].split()
rows = [tuple(int(v) for v in r.split(':')) for r in raw]
span = max(x + w for _, x, w in rows) - min(x for _, x, _ in rows)
w = [w for i, _, w in rows if i == int(fid)][0]
print(round(w / span * 100, 1))
EOF
}

focused_id() { $AERO list-windows --focused --format '%{window-id}'; }

guard_focus() {
  local f; f=$(focused_id)
  for id in $IDS_LIST; do [ "$id" = "$f" ] && return 0; done
  echo "ABORT: focus is on window $f, not a disposable one -- refusing to press a resize key"
  exit 3
}

press() {  # $1 = ] or [
  guard_focus
  timeout 10 $HS -c "hs.eventtap.keyStroke({'cmd','ctrl','alt'}, '$1', 0)" >/dev/null 2>&1
  sleep 1.4
}

# $1 label  $2 got  $3 want  $4 tolerance (percentage points)
near() {
  python3 - "$2" "$3" "$4" <<'EOF' || { echo "FAIL: $1: got $2, want $3 +-$4"; fails=$((fails+1)); return 1; }
import sys
got, want, tol = float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3])
sys.exit(0 if abs(got - want) <= tol else 1)
EOF
  echo "   ok: $1: $2% (want $3 +-$4)"
}

setup_workspace() {
  $AERO move-workspace-to-monitor --workspace "$WS" -- LG >/dev/null 2>&1
  $AERO workspace "$WS"; sleep 1
  $AERO move-workspace-to-monitor --workspace "$WS" -- LG 2>&1
  sleep 0.8
  $AERO layout --workspace "$WS" --root tiles 2>&1
  sleep 0.6
  $AERO balance-sizes; sleep 0.8
}

echo "original workspace: $ORIGINAL_WS"
A=$(new_window A); B=$(new_window B)
[ -n "$A" ] && [ -n "$B" ] || { echo "ABORT: could not create windows"; exit 2; }
IDS_LIST="$A $B"
echo "disposable windows: $IDS_LIST"
for id in $IDS_LIST; do $AERO move-node-to-workspace --window-id "$id" "$WS"; done
setup_workspace

MON=$($AERO list-monitors --focused --format '%{monitor-name}')
echo "workspace $WS is on: $MON"
echo "frames: $(frames)"
case "$MON" in *LG*) ;; *) echo "ABORT: workspace is not on the LG"; exit 2;; esac

# Which is left, which is right.
read LEFT RIGHT < <(python3 - "$(frames)" <<'EOF'
import sys
rows = sorted((tuple(int(v) for v in r.split(':')) for r in sys.argv[1].split()), key=lambda r: r[1])
print(rows[0][0], rows[-1][0])
EOF
)
echo "left=$LEFT right=$RIGHT"

echo
echo "=== 2 windows, focus LEFT: ] ] ] then [ [ [ [ [ ==="
$AERO focus --window-id "$LEFT"; sleep 0.5
near "start, even split" "$(share_of $LEFT)" 50 3
press ']'; near "] -> 66" "$(share_of $LEFT)" 66 3
press ']'; near "] -> 75" "$(share_of $LEFT)" 75 3
press ']'; near "] at end of ladder stays 75" "$(share_of $LEFT)" 75 3
press '['; near "[ -> 66" "$(share_of $LEFT)" 66 3
press '['; near "[ -> 50" "$(share_of $LEFT)" 50 3
press '['; near "[ -> 33" "$(share_of $LEFT)" 33 3
press '['; near "[ -> 25" "$(share_of $LEFT)" 25 3
press '['; near "[ at end of ladder stays 25" "$(share_of $LEFT)" 25 3

echo
echo "=== 2 windows, focus RIGHT: ] grows the RIGHT window ==="
$AERO balance-sizes; sleep 0.8
$AERO focus --window-id "$RIGHT"; sleep 0.5
near "start, even split (right window)" "$(share_of $RIGHT)" 50 3
press ']'; near "] grows right window -> 66" "$(share_of $RIGHT)" 66 3
echo "   left window's share is now: $(share_of $LEFT)% (expect ~34)"

echo
echo "=== 3 windows, focus LEFT: informational (others share the remainder) ==="
C=$(new_window C)
[ -n "$C" ] || { echo "ABORT: could not create third window"; exit 2; }
IDS_LIST="$A $B $C"
$AERO move-node-to-workspace --window-id "$C" "$WS"; sleep 0.8
$AERO layout --workspace "$WS" --root tiles; sleep 0.5
$AERO balance-sizes; sleep 0.8
echo "frames: $(frames)"
$AERO focus --window-id "$LEFT"; sleep 0.5
near "start, even thirds" "$(share_of $LEFT)" 33 4
press ']'; echo "   after ] (want ~50): left=$(share_of $LEFT)%  frames: $(frames)"
press ']'; echo "   after ] (want ~66): left=$(share_of $LEFT)%  frames: $(frames)"
press ']'; echo "   after ] (want ~75): left=$(share_of $LEFT)%  frames: $(frames)"

echo
if [ "$fails" -eq 0 ]; then echo "RESULT: PASS (2-window checks; 3-window lines above are informational)"; else echo "RESULT: FAIL ($fails)"; exit 1; fi
