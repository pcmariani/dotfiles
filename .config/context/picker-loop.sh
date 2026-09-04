#!/bin/bash
# The picker dispatch loop -- MINIMAL, contexts-only.
#
# This is Ghostty's `command` for the isolated picker instance, so it is the
# only thing in the hot path: Ghostty runs it via
#   /usr/bin/login -flp <user> /bin/bash --noprofile --norc -c exec -l <this>
# so no rc files load. That same `login` wrapper RESETS cwd to $HOME, which is
# why every path here is absolute and nothing relies on the working directory.
#
# The loop knows nothing about producers, fields or verbs: it runs a complete
# shell command and hides the panel afterwards. `context pick-command <name>`
# builds that command from `pickers.toml` elsewhere -- this script never sees
# a producer name, only the finished command line, and PICKER_DEFAULT below
# is the only picker NAME it ever mentions.
#
# NOTHING WRITES TO THE FIFO TODAY. No hotkey, no Hammerspoon binding, no
# refresh script sends a command down it -- it exists for a future control
# channel (paneld) that can hand this loop a DIFFERENT picker for one show.
# So the loop cannot simply block reading it, or ctrl-shift-space would show
# an empty panel forever. Instead it composes ONE default pipeline at
# startup and runs THAT every iteration, checking without blocking whether
# something has since arrived on the channel to override it for that show.
#
# THE CHANNEL DISCIPLINE IS A CORRECTNESS REQUIREMENT, NOT STYLE:
#   1. The loop holds its OWN writer fd open (fd 9, opened <>) so it never sees
#      EOF -- otherwise `while read < fifo` exits on the writer's first close.
#   2. Writers must open NON-BLOCKING and treat ENXIO as "picker not ready".
#      A blocking write waits for a reader, and the loop is a reader only while
#      it sits here -- NOT while the composed command is on screen. If the
#      writer were Hammerspoon, that would freeze its entire runloop, taking
#      ctrl-space, contextPicker, the space-tab wrapper and doctor's probe
#      with it.
#   3. The MAIN loop's own check of the channel must not block either, for the
#      same reason -- but it does NOT use `read -t 0`. Ghostty invokes this
#      script under macOS's stock /bin/bash (3.2.57, frozen pre-GPLv3), and
#      that version's `read -t 0` is not the bash-4+ "is input ready?" poll:
#      measured here, it returns failure in single-digit milliseconds whether
#      or not data is waiting, so it can never actually see a write -- a
#      literal `read -t 0 -u 9` would compile, never block, and never work.
#      The equivalent that DOES work on this bash: a persistent background
#      reader (below) holds the blocking read on fd 9 -- which functions
#      normally, exactly as the original single-command loop's did -- and
#      drops whatever it reads into $OVERRIDE via the write-temp-then-rename
#      pattern picker-refresh.sh already uses for the same reason (no reader
#      ever sees a half-written file). The main loop's own check is then just
#      `[ -f "$OVERRIDE" ]`, a stat() call, never a wait.

set -u

: "${STATE:=/Users/petermariani/.local/state/context}"
: "${HS:=/opt/homebrew/bin/hs}"
: "${CTX:=/Users/petermariani/projects/context-based-mac/bin/context}"
# The ONLY picker name this script ever mentions. It knows nothing about
# producers, fields or verbs -- `context pick-command` resolves the name into
# a full pipeline, once, below.
: "${PICKER_DEFAULT:=contexts}"

FIFO="$STATE/picker.trigger"

# NOTHING ELSE RUNS ON THE SHOW PATH. The OQ2 timestamp binds that used to sit
# here spawned a perl process on fzf's `start` AND on its `load` -- two process
# spawns on the hot path, every single show, to write numbers nobody reads any
# more. Re-add them only while actually measuring.

/bin/mkdir -p "$STATE"

# Recreate the channel if it is missing or is not a FIFO.
if [ ! -p "$FIFO" ]; then
    /bin/rm -f "$FIFO"
    /usr/bin/mkfifo -m 600 "$FIFO"
fi

READER_PID_FILE="$STATE/picker.reader.pid"

# REAP AN ORPHANED READER BEFORE OPENING fd 9. The EXIT trap below kills the
# reader on a normal exit, but SIGKILL -- Force Quit, OOM, a crash -- bypasses
# traps entirely, and nothing else would ever notice a stray reader left
# holding this FIFO open. A FIFO with two readers splits writes between them
# unpredictably, so an orphan here would silently swallow some future loop's
# override -- "the picker sometimes ignores me", hours to diagnose.
#
# The bare pid is not enough: it can be recycled onto some unrelated process
# by the time we check it, and killing THAT would be a much worse bug than
# the one this guards against. Verified the way picker-refresh.sh verifies
# fzf before killing it -- matched on the command, not trusted by number
# alone. `comm=` alone would just say "bash" here (this is a shell subshell,
# not a distinct binary), so the full command line is matched instead: a
# stray reader's argv is this script's own invocation, inherited by the
# subshell fork below.
stale_reader=$(/bin/cat "$READER_PID_FILE" 2>/dev/null)
if [ -n "${stale_reader:-}" ] && /bin/kill -0 "$stale_reader" 2>/dev/null; then
    case "$(/bin/ps -o args= -p "$stale_reader" 2>/dev/null)" in
        *picker-loop.sh*) /bin/kill "$stale_reader" 2>/dev/null ;;
    esac
fi

# Requirement 1: our own writer fd, so the channel never reaches EOF.
exec 9<>"$FIFO"

OUT="$STATE/picker.selection"
RETIRED="$STATE/picker.retired"
OVERRIDE="$STATE/picker.override"

# Never inherit one from a previous run: a stale marker would swallow the
# user's next real dismissal, and a stale override would run a command from
# a process that no longer exists.
/bin/rm -f "$RETIRED" "$OVERRIDE" "$OVERRIDE.tmp"

# THE BACKGROUND READER. Its blocking `read -u 9` is the same call the main
# loop used before this change -- correct and unremarkable on its own, which
# is exactly why it is safe to park here instead of in the hot path. It never
# sees EOF for the same reason the rest of this file doesn't: fd 9 stays open
# for both ends, inherited across the fork below. Nothing writes to the FIFO
# today, so in practice this sits blocked forever, at zero cost, until a
# future control channel (paneld) starts using it.
(
    while IFS= read -r -u 9 line; do
        printf '%s' "$line" >"$OVERRIDE.tmp" && /bin/mv -f "$OVERRIDE.tmp" "$OVERRIDE"
    done
) &
reader_pid=$!
echo "$reader_pid" >"$READER_PID_FILE"
trap '/bin/kill "$reader_pid" 2>/dev/null; /bin/rm -f "$READER_PID_FILE"' EXIT

# So the refresh script can retire the fzf that is holding stale rows. It
# walks down from here rather than matching on the command line, because
# fzf-lua runs fzf inside nvim and must never be touched.
echo $$ >"$STATE/picker.loop.pid"

# Hiding the panel needs a synthesized hyper-P: Ghostty 1.3.1 exposes NO
# CLI or IPC way to toggle the quick terminal in a running instance (checked
# `+list-actions` and the action list -- `toggle_quick_terminal` exists only as
# a keybind action). Hammerspoon already holds the Accessibility grant that
# synthesis needs, and this runs only on dismissal, never on the hot path.
# The third argument, 0, is the DELAY BETWEEN KEYDOWN AND KEYUP in
# microseconds, and Hammerspoon defaults it to 200000 -- a fifth of a second
# spent holding a synthetic key down. Measured here: 261-271ms per hide with
# the default, 54-63ms with 0. That 200ms was the whole of the panel's slow
# teardown after fzf exited.
# NOTHING may ever be visible on the normal screen.
#
# fzf draws on the ALTERNATE screen, so each time it exits the normal screen is
# revealed for the few tens of milliseconds before the panel hides or the next
# fzf starts. `/usr/bin/login` -- which Ghostty wraps `command` in, and which
# has no option to skip -- printed "Last login: ... on ttys00N" there once when
# this surface was created, so that line flickered on every single dismissal.
#
#   2J  clear the screen
#   3J  clear the SCROLLBACK too, or the line is one scroll away forever
#   H   cursor home
#   ?25l hide the cursor, so a block cursor cannot blink on the blank screen
#
# A blank normal screen is indistinguishable from the panel being closed, which
# is what makes the transition invisible. (`~/.hushlogin` would suppress the
# banner globally, but that changes every login shell on the machine; this is
# local to the picker.)
blank_screen() { printf '\033[2J\033[3J\033[H\033[?25l'; }

hide_panel() {
    "$HS" -c \
        'hs.eventtap.keyStroke({"cmd","ctrl","alt","shift"}, "p", 0); return "hidden"' \
        >/dev/null 2>&1
}

# Before the first fzf ever draws: wipe login's banner off the normal screen.
blank_screen

# Composed ONCE, before the loop, never inside it: a Python interpreter start
# is ~190ms, sanctioned here because it happens once at startup, forbidden on
# a per-keypress path. The loop knows nothing about producers, fields or
# verbs before or after this line -- PICKER_DEFAULT is the only name it reads,
# and this is the only place it reads it.
default_command=$("$CTX" pick-command "$PICKER_DEFAULT" 2>/dev/null)

fast=0
burst_start=$SECONDS
while :; do
    # THE CHANNEL CARRIES A COMMAND, and the loop never inspects it. That is
    # the whole contract: `context pick-command <name>` built this string from
    # pickers.toml, and the loop's job is to run it and hide afterwards.
    #
    # NON-BLOCKING: `[ -f "$OVERRIDE" ]` is a stat() call, never a wait -- see
    # the background reader above for why this isn't `read -t 0` on fd 9
    # directly. A command that HAS arrived overrides the default for this one
    # iteration only; it is consumed (renamed away) below, so the loop reverts
    # to the default again immediately afterwards.
    if [ -f "$OVERRIDE" ]; then
        # Moved away, not just read, before the reader can land a NEXT write
        # on the same name in the gap between the check and the read.
        consuming="$OVERRIDE.reading.$$"
        /bin/mv -f "$OVERRIDE" "$consuming"
        command=$(/bin/cat "$consuming")
        /bin/rm -f "$consuming"
    else
        command="$default_command"
    fi

    if [ -z "$command" ]; then
        # Composition failed -- e.g. no pickers.toml yet, or `context` itself
        # is broken -- and nothing is waiting on the FIFO to fix that. Do NOT
        # spin: back off and retry composing, so a misconfigured machine
        # burns a sleep instead of a core.
        /bin/sleep 1
        default_command=$("$CTX" pick-command "$PICKER_DEFAULT" 2>/dev/null)
        continue
    fi

    /bin/bash -c "$command" >"$OUT" 2>/dev/null

    # The refresh script drops this marker immediately BEFORE retiring fzf,
    # because fzf TRAPS SIGTERM and exits 130 -- byte for byte what Esc
    # returns -- so exit status cannot tell them apart. Getting this wrong
    # made the loop hide an ALREADY-HIDDEN panel, and hiding TOGGLES, which is
    # what made the picker pop open on every alt-tab.
    if [ -f "$RETIRED" ]; then
        /bin/rm -f "$RETIRED"
        blank_screen
        continue
    fi

    # Blank the normal screen the instant fzf lets go of the alternate one,
    # BEFORE hiding: the hide takes ~55ms and that is exactly the window in
    # which anything left here would be visible.
    blank_screen

    # Hide on EVERY path, including a failed command. The panel must never
    # depend on what the consumer does -- it used to rely on `context enter`
    # moving focus away so autohide would fire, and whenever enter's focus
    # landed nowhere the panel just sat there.
    hide_panel

    # RESIDENT loop: a hot spin would burn a core forever. Eight instant
    # empty iterations inside two seconds is not a human pressing Esc.
    if [ $((SECONDS - burst_start)) -lt 2 ]; then
        fast=$((fast + 1))
    else
        fast=0
        burst_start=$SECONDS
    fi
    [ "$fast" -ge 8 ] && /bin/sleep 1
done
