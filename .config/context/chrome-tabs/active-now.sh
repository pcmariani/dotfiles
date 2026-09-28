#!/bin/sh
# RETIRED 2026-09-25, the same afternoon it was written -- NOT called by
# producer.sh any more. Kept beside active-now.py as a documented mistake
# rather than silently deleted.
#
# THE BUG: "front window" here is CHROME'S OWN internal focus history --
# whichever window Chrome itself last considered key -- and has nothing
# to do with which monitor or AeroSpace workspace the user is actually
# looking at. Reproduced exactly, live: invoking the switcher from Chrome
# in the CURRENT workspace targeted a completely different Chrome window
# on another monitor, because THAT window happened to be Chrome's
# "window 1" from earlier testing in this same session -- and every
# later switch stayed locked to the wrong window, because nothing
# re-evaluated which one was correct.
#
# See active-now.py for the replacement: it asks AeroSpace which Chrome
# window is in the FOCUSED workspace (AeroSpace already tracks every
# window's real workspace/monitor, and is the authoritative source this
# whole project trusts elsewhere), then matches that window's title
# against Chrome's own window list -- rather than trusting Chrome's own
# idea of "front" at all.
#
# Original comment, for the part that's still true (the SPEED reasoning
# for why this runs synchronously rather than backgrounded like poll.py):
# a targeted query is ~160-175ms vs 1.6-2.8s for poll.py's full
# enumeration (every tab's title+url) -- cheap enough to run on every
# reveal, unlike the full enumeration.
set -u

osascript -e '
tell application "Google Chrome"
    set w to front window
    return (id of w as text) & "	" & (id of (active tab of w) as text)
end tell
' 2>/dev/null
