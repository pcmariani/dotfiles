#!/bin/bash
#
# ctrl-hjkl, one key that navigates everywhere:
#
#     nvim splits  ->  herdr panes  ->  AeroSpace windows
#
# Bound from config.toml as `type = "shell"`, replacing the plugin action
# `herdr-splits.nav-<dir>`. It does NOT call the plugin's herdr-nav.sh: that
# script lives under a CONTENT-HASHED path
# (~/.config/herdr/plugins/github/herdr-splits-<hash>/) which changes on every
# plugin update, so depending on it would break silently the next time the
# plugin updates. The ~10 lines of its non-vim branch are reimplemented below
# instead, where drift is visible in a diff.
#
# THE NVIM HALF IS NOT HERE. A pane running nvim gets the chord forwarded into
# it, and herdr-splits.nvim owns everything from there -- including the hop to
# AeroSpace, via the `at_edge` function in
# ~/.config/nvim/plugin/herdr-splits-nvim.lua. Both halves are required: nvim's
# plugin calls `herdr pane focus` DIRECTLY (herdr.lua:110) and never returns
# through this script, so a herdr-only fix would leave nvim panes wrapping.
#
# Usage: nav-fallthrough.sh <left|down|up|right>

set -u

dir="${1:?usage: nav-fallthrough.sh <left|down|up|right>}"

HERDR="${HERDR_BIN_PATH:-/opt/homebrew/bin/herdr}"
AEROSPACE="/opt/homebrew/bin/aerospace"

# Must match nav_key_* in the plugin's generated herdr-splits.conf, because
# these are forwarded to nvim and its plugin matches on the chord it receives.
case "$dir" in
    left)  key="ctrl+h" ;;
    down)  key="ctrl+j" ;;
    up)    key="ctrl+k" ;;
    right) key="ctrl+l" ;;
    *) echo "nav-fallthrough.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# HERDR_ACTIVE_PANE_ID, not `--current`. A keybind's shell command does NOT run
# inside a pane, so it gets no HERDR_PANE_ID and `--current` cannot resolve.
# Herdr injects HERDR_ACTIVE_PANE_ID for exactly this case (see the custom
# command keybindings docs).
PANE="${HERDR_ACTIVE_PANE_ID:-}"

# No pane to reason about -- go straight out to the window manager rather than
# doing nothing.
if [ -z "$PANE" ]; then
    exec "$AEROSPACE" focus --boundaries-action fail "$dir"
fi

# A pane running vim/nvim owns its own navigation. Forward the chord and stop:
# the nvim plugin walks its splits, crosses into herdr when it runs out, and
# calls AeroSpace from its `at_edge` hook when both are exhausted. The regex is
# the plugin's own, kept identical so the two agree on what "is vim" means.
if "$HERDR" pane process-info --pane "$PANE" 2>/dev/null \
    | grep -qiE '"name"[[:space:]]*:[[:space:]]*"(g?(view|l?n?vim?x?)(diff)?)"'; then
    exec "$HERDR" pane send-keys "$PANE" "$key"
fi

edges="$("$HERDR" pane edges --pane "$PANE" 2>/dev/null || true)"

# A ZOOMED PANE FILLS THE TAB AND REPORTS ITSELF AT EVERY EDGE, so the flags
# are meaningless until it is unzoomed -- without this, one keypress in a
# zoomed pane would leave herdr entirely instead of moving inside it.
if printf '%s' "$edges" | grep -q '"zoomed":true'; then
    "$HERDR" pane zoom --off --pane "$PANE" >/dev/null 2>&1 || true
    edges="$("$HERDR" pane edges --pane "$PANE" 2>/dev/null || true)"
fi

# Grep rather than a JSON parse, deliberately: this runs on every press of a
# navigation key, and a python start is ~150ms (measured 2026-09-10) against
# ~0ms here. Safe against the nested `layout` object because that carries no
# left/right/up/down keys -- only area/rect/panes/splits/*_id/zoomed. If
# `pane edges` ever nests a direction key, this grep gains a false positive
# and the symptom is leaving herdr when you meant to move inside it.
if printf '%s' "$edges" | grep -q "\"$dir\":true"; then
    # At the herdr edge. Hand off to the window manager; if there is no window
    # that way either, `fail` makes it a no-op rather than a wrap.
    exec "$AEROSPACE" focus --boundaries-action fail "$dir"
fi

exec "$HERDR" pane focus --direction "$dir" --pane "$PANE"
