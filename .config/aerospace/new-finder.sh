#!/bin/bash

# `make new Finder window`, NOT ⇧⌘N -- that is New Folder in Finder, which
# creates something on disk. This only opens a window, at whatever location
# Finder's own "New windows show" preference names.
#
# `activate` because a new window on a workspace you are not looking at is
# invisible, exactly as in new-chrome.sh.
osascript -e '
tell application "Finder"
    make new Finder window
    activate
end tell
'
