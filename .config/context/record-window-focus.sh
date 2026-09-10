#!/bin/zsh -f
# Record the window that just took focus, for `context enter`.
#
# Called from on-focus-changed in aerospace.toml, which fires on EVERY window
# focus change -- including re-fires for a window that already HAD focus, when
# an app raises itself. Measured 2026-09-10: one window fired 4x in a row that
# way. Nothing filters them; the reader dedupes.
#
# READS AEROSPACE_WINDOW_ID FROM THE ENVIRONMENT, and must never ask AeroSpace
# which window is focused. exec-and-forget is asynchronous, so by the time this
# runs focus may have moved on and the answer would describe the present rather
# than the event: 7 of 9 such reads were wrong under rapid switching. Worse,
# the first such measurement looked PERFECT -- 10 firings agreeing exactly --
# because every one of them was uniformly wrong. See Spec 8 Decision 2.
#
# NO FORKS. `-f` skips rc files (faster, and a login shell's config then cannot
# change what is written); zsh/datetime supplies $EPOCHREALTIME without
# spawning `date`. ~12ms against a ~10ms bare-spawn floor; forking `date` is
# ~18ms. For scale, the borders entry already on this hook costs ~33ms.
#
# APPEND ONLY. Nothing may ever rewrite this file. A read-modify-write races
# these appends and silently loses whichever entries land mid-rewrite -- and
# those are the newest ones. See Spec 8 Decision 6.

zmodload zsh/datetime

# No id means nothing to record. Exit 0: this runs on a hot path and a
# non-zero exit from a hook is noise, not information.
[[ -n "$AEROSPACE_WINDOW_ID" ]] || exit 0

STATE="$HOME/.cache/context"

# On a fresh machine nothing has created this yet -- `context` itself only
# makes it when something records a workspace -- so without this the first
# writes vanish silently.
[[ -d "$STATE" ]] || mkdir -p "$STATE" 2>/dev/null || exit 0

printf '%s\t%s\n' "$EPOCHREALTIME" "$AEROSPACE_WINDOW_ID" \
    >> "$STATE/window-recent"
