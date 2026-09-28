#!/bin/sh
# Consumer target for the "chrome-tabs" picker, invoked as
# `xargs -0 activate-one.sh` (pickers.toml's consumer line). `xargs -0`
# does the NUL-splitting and hands the whole "value<TAB>display" record
# as ONE argument, tab and all intact -- the same way the `apps` picker's
# consumer already relies on `-0` to protect spaces in app names.
#
# `value` is "win_id:tab_index" (producer.sh's own format). Split on the
# FIRST literal tab, then on the FIRST colon -- NAME_RE-style safety isn't
# available here since these aren't context names, but Chrome's own
# numeric window/tab ids never contain a tab or colon, so this is safe
# for the values this producer actually emits.
set -u

record="$1"
value="${record%%	*}"
win_id="${value%%:*}"
tab_index="${value#*:}"

PY=/Users/petermariani/.local/share/mise/installs/python/3.12/bin/python3
exec "$PY" /Users/petermariani/.config/context/chrome-tabs/activate.py "$win_id" "$tab_index"
