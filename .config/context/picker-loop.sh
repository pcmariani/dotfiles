#!/bin/bash
# The picker dispatch loop -- MINIMAL, contexts-only.
#
# This is Ghostty's `command` for the isolated picker instance, so it is the
# only thing in the hot path: Ghostty runs it via
#   /usr/bin/login -flp <user> /bin/bash --noprofile --norc -c exec -l <this>
# so no rc files load. That same `login` wrapper RESETS cwd to $HOME, which is
# why every path here is absolute and nothing relies on the working directory.
#
# Scope today: the `contexts` producer only. There is deliberately no producer
# selection yet, which is why there is no producer name on the channel -- the
# channel carries only "show now". Adding folders/files (plan Task 12) is what
# turns this into a real dispatcher, and that change MUST also flip
# `quick-terminal-autohide` to false in picker.ghostty.
#
# THE CHANNEL DISCIPLINE IS A CORRECTNESS REQUIREMENT, NOT STYLE:
#   1. The loop holds its OWN writer fd open (fd 9, opened <>) so it never sees
#      EOF -- otherwise `while read < fifo` exits on the writer's first close.
#   2. Writers must open NON-BLOCKING and treat ENXIO as "picker not ready".
#      A blocking write waits for a reader, and the loop is a reader only while
#      it sits here -- NOT while fzf is on screen. If the writer were
#      Hammerspoon, that would freeze its entire runloop, taking ctrl-space,
#      contextPicker, the space-tab wrapper and doctor's probe with it.
#   3. Every dismissal path must terminate fzf, so the loop always returns to
#      waiting. Esc is bound to abort below.

set -u

: "${CTX:=/Users/petermariani/projects/context-based-mac/bin/context}"
: "${FZF:=/opt/homebrew/bin/fzf}"
: "${STATE:=/Users/petermariani/.local/state/context}"
: "${HS:=/opt/homebrew/bin/hs}"

FIFO="$STATE/picker.trigger"
MODE_FILE="$STATE/picker.mode"     # "prerender" (default) | "ondemand"

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

TAB=$(printf '\t')
PRE="$STATE/picker.prerendered"
OUT="$STATE/picker.selection"
RETIRED="$STATE/picker.retired"

# Never inherit one from a previous run: a stale marker would swallow the
# user's next real dismissal.
/bin/rm -f "$RETIRED"

# So the refresh script can retire the fzf that is holding stale rows. It
# walks down from here rather than matching on the command line, because
# fzf-lua runs fzf inside nvim and must never be touched.
echo $$ >"$STATE/picker.loop.pid"

# Catppuccin Mocha, to match the Ghostty theme this instance now sets, with
# the pink and mauve deliberately absent -- teal, sky and yellow instead.
#
# `bg:-1` is deliberate: it leaves the background to the terminal, so the
# 0.78 opacity and the 100px blur show through. A literal bg colour here would
# paint an opaque slab over both.
#
# THE LEFT RAIL IS THE GUTTER, and this is the one setting that controls it.
# From fzf(1): "--gutter=CHAR: Character used for the gutter column (default:
# '▌')" with its own colour role, "gutter: Gutter on the left". It is drawn on
# EVERY row; the current row shows --pointer in that column instead, and that
# contrast is what makes the selection readable.
#
# It was bright because `gutter:-1` was set here, and -1 means "terminal
# default", i.e. the default FOREGROUND. Dimming `border`, `list-border` and
# `marker` in turn changed nothing because none of them draws it. (`--marker`
# defaults to '┃' and only ever appears for multi-select, which this never
# uses.)
FZF_COLORS=(
    --color=bg:-1,bg+:#1e1e2e,fg:#cdd6f4,fg+:#ffffff
    --color=hl:#f9e2af,hl+:#f9e2af
    --color=prompt:#94e2d5
    --color=pointer:#89dceb
    --color=marker:#45475a
    --color=info:#585b70,spinner:#94e2d5,header:#89b4fa
    --color=border:#313244
    --color=gutter:#313244
)

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

# Default is prerender: it is the usable arm and the documented OQ2 fallback.
# The measurement flips this file to "ondemand".
mode() { /bin/cat "$MODE_FILE" 2>/dev/null || echo prerender; }

# Write to a temp file and RENAME, so the next fzf either reads the previous
# complete generation or the new one -- never a half-written file. That is what
# makes it safe to run this in the BACKGROUND, which takes its ~120ms off the
# re-arm path: after a dismissal the loop can have fzf waiting again in ~60ms
# instead of ~200ms, so a fast second press never reveals an empty panel.
prerender() {
    "$CTX" pick --rows --source contexts >"$PRE.tmp" 2>/dev/null \
        && /bin/mv -f "$PRE.tmp" "$PRE"
}

# Only the prerender arm keeps a warm file; the on-demand arm must not benefit
# from one existing.
[ "$(mode)" = prerender ] && prerender

# Before the first fzf ever draws: wipe login's banner off the normal screen.
blank_screen

fast=0
burst_start=$SECONDS
while :; do
    # THE TWO OQ2 ARMS.
    #
    # prerender (default, and the usable path): the producer already ran at the
    # end of the previous iteration, so fzf starts NOW and sits waiting on the
    # hidden panel. Showing the panel reveals an fzf that is already up --
    # the producer is off the hot path entirely. Staleness is bounded by the
    # last dismissal, the same class the timer-refreshed Hammerspoon picker
    # already accepts.
    #
    # ondemand: wait for a show-time trigger, THEN run the producer, so it runs
    # concurrently with the panel animating in. This arm needs the channel,
    # because Ghostty's `command` runs once per SURFACE and the quick terminal's
    # surface is created lazily on first show only -- so there is no other
    # signal that a show happened.
    if [ "$(mode)" = prerender ]; then
        rows() { /bin/cat "$PRE"; }
    else
        IFS= read -r -u 9 _trigger || continue
        rows() { "$CTX" pick --rows --source contexts 2>/dev/null; }
    fi

    # `start` fires when fzf begins; `load` fires when its input stream is
    # complete. Both matter: with a pipe, fzf renders BEFORE the producer has
    # finished streaming, so a fast first render can hide a list that is still
    # filling -- and Enter on an incomplete list can enter the wrong context,
    # since tier 1 of the contexts ordering is a running one.
    # Output to a file rather than a command substitution so the selection can
    # be read back after checking why fzf exited.
    #
    # WHY A MARKER FILE AND NOT AN EXIT CODE: fzf TRAPS SIGTERM and exits 130 --
    # byte for byte what it returns when the user presses Esc. Measured. So a
    # retired fzf cannot be told from a dismissal by status, and treating one
    # as the other made the loop "hide" an already-hidden panel, which TOGGLES
    # IT ON. That is why the picker appeared on every alt-tab.
    rows | "$FZF" \
            --read0 --print0 --delimiter="$TAB" --with-nth=2 \
            --ansi \
            --no-mouse \
            --layout=reverse \
            --info=inline-right \
            --border=none \
            --padding=0 \
            --prompt='❯ ' \
            --pointer='▌' \
            --marker='▌' \
            --highlight-line \
            --cycle \
            --no-scrollbar \
            --ellipsis='…' \
            --tiebreak=begin,index \
            "${FZF_COLORS[@]}" \
            --bind esc:abort \
            --bind 'load:down' \
          >"$OUT" 2>/dev/null

    # The refresh script drops this marker immediately BEFORE retiring fzf, so
    # its presence -- not the exit status -- is what says "this was not the
    # user". Consume it and go straight back to waiting: nothing to hide,
    # nothing to enter.
    if [ -f "$RETIRED" ]; then
        /bin/rm -f "$RETIRED"
        blank_screen
        continue
    fi

    sel=$(/usr/bin/tr -d '\0' <"$OUT" | /usr/bin/cut -d"$TAB" -f1)

    # Blank the normal screen the instant fzf lets go of the alternate one,
    # BEFORE hiding: the hide takes ~55ms, and that is exactly the window in
    # which anything left here would be visible.
    blank_screen

    # Hide FIRST, and on every path. Dismissal must not depend on what
    # `context enter` does: the panel was relying on enter moving focus away so
    # autohide would fire, so whenever enter's focus landed nowhere -- the
    # macOS focus bug -- focus never left the panel and it just sat there.
    # Hiding before the switch also reads as instant.
    #
    # The fresh fzf the loop then starts is what clears the query between
    # shows: the same bug hs.chooser had, avoided here because fzf is a new
    # process per show rather than a persistent one.
    hide_panel

    if [ -n "$sel" ]; then
        "$CTX" enter "$sel" >/dev/null 2>&1
    fi

    # This loop is RESIDENT, so a hot spin would burn a core forever. An
    # iteration returning instantly with no selection means fzf died on startup
    # or the row source was empty -- back off rather than respawn a Python
    # producer hundreds of times a second.
    #
    # Timed with bash's own $SECONDS, not perl: this ran twice per iteration and
    # /bin/bash on macOS is 3.2, so there is no $EPOCHREALTIME to read instead.
    # Eight empty dismissals inside two seconds is not a human pressing Esc.
    if [ -z "$sel" ] && [ $((SECONDS - burst_start)) -lt 2 ]; then
        fast=$((fast + 1))
    else
        fast=0
        burst_start=$SECONDS
    fi
    if [ "$fast" -ge 8 ]; then
        /bin/sleep 1
    fi

    # BACKGROUNDED: see prerender(). The loop returns to fzf immediately and
    # the rows for the NEXT show are built behind it.
    [ "$(mode)" = prerender ] && prerender &
done
