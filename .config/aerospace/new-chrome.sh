#!/bin/bash

# A new Chrome window. In a workspace named for a Chrome profile (amneal,
# csc-sugar, ...) it is that profile's window; anywhere else, and whenever
# `context chrome-new` does not open one, it is the plain AppleScript window
# below, exactly as before.
#
# Absolute CTX: a hotkey's child gets PATH=/usr/bin:/bin:/usr/sbin:/sbin, so
# `context` is not on it. Overridable for testing, as in new-finder.sh.
: "${CTX:=/Users/petermariani/projects/context-based-mac/bin/context}"

"$CTX" chrome-new 2>/dev/null && exit 0

osascript -e '
tell application "Google Chrome"
    make new window
    activate
end tell
'
