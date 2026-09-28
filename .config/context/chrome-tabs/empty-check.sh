#!/bin/sh
# paneld's on_empty hook for the chrome-tabs panel (paneld.toml). Run
# synchronously by paneld, bounded by a short timeout, right as the panel's
# reveal timer fires -- exit 0 means "confirmed empty, I already showed a
# toast, don't reveal"; exit 1 (or a timeout) means "not empty, reveal
# normally." See PanelController.swift's own isEmpty() for the timeout/
# fail-open contract.
#
# Deliberately NOT the same query active-now.py runs (list-windows --json
# + a title-match against Chrome's bulk tab enumeration): this only needs
# a yes/no answer to "is there any Chrome window here at all", so a plain
# --format app-name listing plus grep is enough, and skips both the JSON
# parse and the AppleScript round trip entirely -- the common (non-empty)
# case must stay well inside paneld's own timeout budget.
#
# terminal-notifier over Hammerspoon's own hs.alert.show (the user's own
# call, 2026-09-28): a real macOS notification, not an in-app overlay.
# Verified live: a cold first call can take long enough to race past
# paneld's 150ms check-timeout (the panel shows instead of the toast that
# one time) -- fails open exactly as designed, and every call after warms
# up and is reliably fast. Same binary herdr's own "system" toast delivery
# already uses (~/.config/herdr/config.toml).
AEROSPACE=/opt/homebrew/bin/aerospace
NOTIFIER=/opt/homebrew/bin/terminal-notifier

if "$AEROSPACE" list-windows --workspace focused --format '%{app-name}' 2>/dev/null \
    | /usr/bin/grep -qx "Google Chrome"
then
    exit 1
fi

"$NOTIFIER" -title "chrome-tabs" -message "No Chrome windows in this workspace" -sound default >/dev/null 2>&1
exit 0
