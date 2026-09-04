#!/bin/bash
# The picker dispatch loop -- MINIMAL, contexts-only.
#
# This is Ghostty's `command` for the isolated picker instance, so it is the
# only thing in the hot path: Ghostty runs it via
#   /usr/bin/login -flp <user> /bin/bash --noprofile --norc -c exec -l <this>
# so no rc files load. That same `login` wrapper RESETS cwd to $HOME, which is
# why every path here is absolute and nothing relies on the working directory.
#
# The loop knows nothing about producers, fields or verbs: it reads a
# complete shell command off the channel and runs it, then hides the panel.
# `context pick-command <name>` builds that command from `pickers.toml`
# elsewhere -- this script never sees a producer name, only the finished
# command line.
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

set -u

: "${STATE:=/Users/petermariani/.local/state/context}"
: "${HS:=/opt/homebrew/bin/hs}"

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

# Requirement 1: our own writer fd, so the channel never reaches EOF.
exec 9<>"$FIFO"

OUT="$STATE/picker.selection"
RETIRED="$STATE/picker.retired"

# Never inherit one from a previous run: a stale marker would swallow the
# user's next real dismissal.
/bin/rm -f "$RETIRED"

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

fast=0
burst_start=$SECONDS
while :; do
    # THE CHANNEL CARRIES A COMMAND, and the loop never inspects it. That is
    # the whole contract: `context pick-command <name>` built this string from
    # pickers.toml, and the loop's job is to run it and hide afterwards.
    #
    # Channel discipline is unchanged and is a correctness requirement:
    # fd 9 keeps a writer open so `read` never sees EOF, and writers must open
    # NON-BLOCKING and treat ENXIO as "picker not ready" -- the loop is a
    # reader only while it sits here, not while a picker is on screen.
    IFS= read -r -u 9 command || continue
    [ -n "$command" ] || continue

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
