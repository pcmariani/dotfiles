#!/bin/bash
# Chrome tab frecency picker -- v1 prototype, NOT wired into paneld.
#
# Reads the last full poll (poll.py, meant to run on a timer -- no
# LaunchAgent installed yet, see the handoff notes) ranked by frecency
# (rank.py), lets you fuzzy-pick one in fzf, and jumps Chrome to it
# (activate.py). Runs in whatever terminal invokes it; bound to a keybind
# below via a new Ghostty window (`ghostty -e`), because fzf needs a real
# TTY and this project's own panels get that from paneld/libghostty, which
# this prototype does not integrate with yet.
#
# NO BACKGROUND POLLER IS RUNNING (see chrome-tabs/README-handoff.md): the
# LaunchAgent that would keep frecency current between invocations is
# built but left UNLOADED, because launchd spawning python3 directly hit a
# TCC Automation denial for Google Chrome (confirmed in TCC.db, not
# guessed) that this script's own path does not: karabiner's `:run` goes
# through karabiner_console_user_server, already Chrome-authorized, so a
# key-press invocation is a different, already-working responsible-process
# identity than a bare launchd agent is. The tradeoff: this poll.py call
# below runs SYNCHRONOUSLY, in the foreground, every time you press the
# key -- 1.6-2.8s of real latency (measured 2026-09-25) before the list
# even appears, because there is no warm background cache to read instead.
set -euo pipefail

PY=/Users/petermariani/.local/share/mise/installs/python/3.12/bin/python3
DIR=/Users/petermariani/.config/context/chrome-tabs

"$PY" "$DIR/poll.py" >/dev/null 2>&1 || true

selected=$("$PY" "$DIR/rank.py" | fzf --ansi --no-sort --prompt="chrome tab> " --height=100%)

if [ -z "$selected" ]; then
    exit 0
fi

win_id=$(echo "$selected" | cut -f1)
tab_index=$(echo "$selected" | cut -f2)

"$PY" "$DIR/activate.py" "$win_id" "$tab_index"
