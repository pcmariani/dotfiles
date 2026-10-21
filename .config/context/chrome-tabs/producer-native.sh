#!/bin/sh
# Producer for the NATIVE chrome-tabs panel (paneld.toml, cmd-backtick).
#
# producer.sh's arm-time work, minus the part that cannot run at the keypress:
# it fired active-now.py and waited up to 1.5 s for it, which was free when the
# panel was armed in advance and is not when the rows are wanted NOW. So this
# only READS what is already known:
#
#   - wait-for-fresh.py returns fresh.tsv at once unless active-now.py is
#     running right now, in which case it waits for it (bounded) -- the
#     answer is then the one that was about to land anyway;
#   - rank.py scopes the cached tabs to those windows and ranks them.
#
# Who keeps fresh.tsv current instead of this script: activate.py writes it
# itself the moment a tab is chosen; on-focus-changed-if-chrome.sh runs
# active-now.py whenever Chrome takes focus; and picker-rearm-others.sh runs it
# once switching between workspaces has gone quiet. NOT fired from here: a run
# in flight makes the commit's own activate.py queue behind Chrome's single
# Apple Event dispatcher, the "nothing happens on the first try" bug.
#
# Output is "win_id:index<TAB>display", NUL-framed, as producer.sh's is.
# Python does the framing: this machine's awk drops a `\0` in printf.
set -u

PY=/Users/petermariani/.local/share/mise/installs/python/3.12/bin/python3
DIR=/Users/petermariani/.config/context/chrome-tabs

CHROME_FRESH_PAIRS="$("$PY" "$DIR/wait-for-fresh.py")"
export CHROME_FRESH_PAIRS

"$PY" "$DIR/rank.py" | "$PY" -c '
import sys
for line in sys.stdin:
    line = line.rstrip("\n")
    win_id, index, display = line.split("\t", 2)
    sys.stdout.buffer.write(f"{win_id}:{index}\t{display}\0".encode())
'
