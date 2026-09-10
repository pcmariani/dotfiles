#!/bin/bash

# A new Finder window, rooted at the focused workspace's directory.
#
# `make new Finder window`, NOT Finder's own shift-cmd-N -- that is New Folder
# and writes to disk. This only opens a window.
#
# ROOT, the same way `context terminal` roots a Ghostty window. Follows the
# pattern deliberately: arriving in a workspace and asking for its Finder
# should land where asking for its terminal lands.

set -u

# Overridable for testing, the same shape as picker-refresh.sh. Absolute by
# default: a hotkey's child gets PATH=/usr/bin:/bin:/usr/sbin:/sbin, so
# `context` is not on it.
: "${CTX:=/Users/petermariani/projects/context-based-mac/bin/context}"

# `context current --path` is a three-way contract and needs no parsing:
#
#   rooted context        -> directory on STDOUT, exit 0
#   context with no path  -> exit non-zero, message on STDERR
#   not a context at all  -> exit non-zero, NOTHING on either stream
#
# The third case really is silent: cmd_current returns an empty message, and
# __main__.py only prints `if output`. So 2>/dev/null suppresses a message
# that exists on one failure branch and not the other -- do not add
# diagnostics here that assume stderr says why.
#
# THE LOAD-BEARING HALF IS THE EMPTY STDOUT, not the exit code. If either
# failure branch ever printed to stdout, this script would root a Finder
# window at whatever it printed, with no error anywhere -- just the wrong
# directory. cmd_current's docstring says an empty string "would leave a
# caller walking its own cwd"; this is that caller. Pinned upstream by
# tests/test_cli.py:366-384.
DIR="$("$CTX" current --path 2>/dev/null)"

# HOME for rootless (the ambient workspaces -- work, ai, browser, personal)
# and for a workspace this tool does not know. Deliberately explicit rather
# than falling back to a bare `make new Finder window`, which lands on
# whatever Finder's "New windows show" preference names -- Recents, iCloud --
# and so is not stable across machines or preference changes.
#
# ${HOME:-...} because a hotkey's environment is minimal and worth not
# trusting; the literal is the same paranoia as the absolute CTX above.
[ -n "$DIR" ] && [ -d "$DIR" ] || DIR="${HOME:-/Users/petermariani}"

# The path goes in as an ARGUMENT, not interpolated into the script text: a
# directory containing a quote would otherwise break the AppleScript or inject
# into it. `activate` because a new window on a workspace you are not looking
# at is invisible, as in new-chrome.sh.
osascript - "$DIR" <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        make new Finder window to (POSIX file (item 1 of argv) as alias)
        activate
    end tell
end run
APPLESCRIPT
