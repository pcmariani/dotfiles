#!/bin/bash
# Smoke checks for active-now.py, 2026-09-25 through 2026-09-28.
#
# Check 1 -- the title-matching fix (2026-09-25): AeroSpace's window title
# carries decoration (memory-usage warnings, unread counts) that Chrome's
# own AppleScript `title of tab` does not have, so exact-match (`tab_title
# == target_title`) silently failed whenever a window happened to be
# decorated. Fixed by matching PREFIX instead (the window's decorated
# title starts with the tab's undecorated title) -- see this file's own
# docstring and docs/superpowers/specs/2026-09-25-chrome-tabs-hammerspoon-active-window-design.md
# for the full story, including a same-day Hammerspoon detour that turned
# out not to be needed.
#
# Check 2 -- the fresh.tsv write (2026-09-26): a real, measured latency
# bug (0.75-0.84s per call) meant producer.sh calling this SYNCHRONOUSLY
# blocked rank.py's output from reaching fzf at all, so the panel showed
# up empty and cycle keypresses landed on a not-yet-populated fzf and were
# silently dropped -- the user's own words: "doesn't respond when I
# hammer... speed is the product." Fixed by backgrounding this script
# (matching poll.py's own pattern) and having it write its answer to
# fresh.tsv for producer.sh to read instantly instead of waiting on it.
#
# STATE_DIR/FRESH_FILE/LOCK_FILE are monkeypatched to a throwaway tmpdir
# for every check below -- this script must NEVER touch the real
# ~/.local/state/context/chrome-tabs/fresh.tsv a live producer.sh could be
# reading at the same time (see memory tests-never-touch-real-state.md:
# an earlier version of this file, before this isolation was added, wrote
# a fake win_id/tab_id straight into the real file).
#
# switcher_log's STATE_DIR/LOG_FILE ALSO redirected, 2026-09-27, same
# reason: active-now.py's own `from switcher_log import log` (inside
# main(), imported fresh each call) was writing every check's fixture data
# into the REAL switcher.debug.log -- the file HANDOFF.md calls "the
# primary diagnostic tool for this bug", polluted by every test run before
# this fix. Must be imported and patched BEFORE m.main() runs (it's
# imported lazily inside main(), not at module top level, unlike
# activate.py/rank.py) -- python caches modules by name in sys.modules, so
# main()'s own later `from switcher_log import log` finds this same,
# already-patched module object rather than re-executing it.
#
# REWRITTEN 2026-09-28 for per-workspace scope: every fake_aerospace mock
# below now answers `list-windows --workspace focused --json` (a JSON
# array of {app-name, window-id, window-title}) instead of
# `list-windows --focused --format ...` (a single decorated title
# string). Check 5, which used to ENFORCE the single-literal-focused-
# window decision as a regression guard, is replaced: the reversal this
# rewrite implements is exactly what that old check would have failed.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "   ok: $1"; pass=$((pass+1)); }

one_chrome_window_json() {
    python3 -c "
import json
print(json.dumps([{'app-name': 'Google Chrome', 'window-id': 1, 'window-title': '''$1'''}]))
"
}

run_case() {
    python3 -c "
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('active_now', '$HERE/active-now.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.LOCK_FILE = m.STATE_DIR / 'active-now.lock'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

def fake_aerospace(*args):
    if args[0] == 'list-windows' and '--workspace' in args and '--json' in args:
        return '''$(one_chrome_window_json "Inbox (827) - pmariani@boomi.com - Boomi, LP Mail - High memory usage - 1.8 GB - Google Chrome - Peter")'''
    raise AssertionError('unexpected aerospace call: ' + repr(args))
m.aerospace = fake_aerospace

class FakeProc:
    returncode = 0
    stdout = '9369\nInbox (827) - pmariani@boomi.com - Boomi, LP Mail\n994908248'

def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

raise SystemExit(m.main())
"
}

out="$(run_case)"
case "$out" in
    "9369	994908248") ok "prefix match finds the decorated window's active tab" ;;
    *) fail "expected win_id/tab_id from prefix match, got: [$out]" ;;
esac

fresh_contents="$(cat "$TMP/fresh.tsv" 2>/dev/null)"
case "$fresh_contents" in
    "9369	994908248") ok "fresh.tsv is written on a real match, for producer.sh to read instantly" ;;
    *) fail "expected fresh.tsv to contain '9369\\t994908248', got: [$fresh_contents]" ;;
esac

# Check 3 -- the race guard (2026-09-26): activate.py now writes fresh.tsv
# itself, instantly, the moment a switch commits. A background
# active-now.py run already in flight when that happens must NOT clobber
# that fresher answer with the stale one it spent ~0.8s computing. Proven
# by writing a "fresher" fresh.tsv and artificially back-dating this run's
# own notion of when it started (main() stamps start_time BEFORE any
# work), so the file's mtime looks newer than the run -- exactly the
# in-flight-clobber scenario.
run_race_case() {
    python3 -c "
import importlib.util, pathlib, sys, time
spec = importlib.util.spec_from_file_location('active_now', '$HERE/active-now.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.LOCK_FILE = m.STATE_DIR / 'active-now.lock'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'
m.FRESH_FILE.write_text('9999\t111\n')  # activate.py's fresher answer

def fake_aerospace(*args):
    if args[0] == 'list-windows' and '--workspace' in args and '--json' in args:
        return '''$(one_chrome_window_json "Inbox (827) - pmariani@boomi.com - Boomi, LP Mail - High memory usage - 1.8 GB - Google Chrome - Peter")'''
    raise AssertionError('unexpected aerospace call: ' + repr(args))
m.aerospace = fake_aerospace

class FakeProc:
    returncode = 0
    stdout = '9369\nInbox (827) - pmariani@boomi.com - Boomi, LP Mail\n994908248'
def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

real_time = m.time.time
m.time.time = lambda: real_time() - 10  # this run 'started' 10s in the past
raise SystemExit(m.main())
"
}
run_race_case >/dev/null
race_contents="$(cat "$TMP/fresh.tsv" 2>/dev/null)"
case "$race_contents" in
    "9999	111") ok "a slower in-flight run does not clobber a fresher answer already on disk" ;;
    *) fail "expected fresh.tsv to still hold activate.py's '9999\\t111', got: [$race_contents]" ;;
esac

# Check 4 -- the first-match-wins bug (2026-09-26, adversarial review):
# the enumeration loop returned on the FIRST prefix match in Chrome's own
# internal window order (front-to-back MRU, unrelated to AeroSpace
# workspaces), not the best/longest one. A short, generic active-tab
# title elsewhere in Chrome (a bare "GitHub" dashboard tab, entirely
# plausible) can be a literal string-prefix of the TRUE target title and
# sit earlier in enumeration order, so it wins even though the true
# window's own tab title is a far longer, far more specific prefix match.
# This is deterministic, not a timing race -- it reproduces any time a
# short title anywhere in Chrome happens to prefix the real target.
run_ambiguous_prefix_case() {
    python3 -c "
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('active_now', '$HERE/active-now.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.LOCK_FILE = m.STATE_DIR / 'active-now.lock'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

def fake_aerospace(*args):
    if args[0] == 'list-windows' and '--workspace' in args and '--json' in args:
        return '''$(one_chrome_window_json "GitHub - Pull Request #123 - Google Chrome - Peter")'''
    raise AssertionError('unexpected aerospace call: ' + repr(args))
m.aerospace = fake_aerospace

class FakeProc:
    returncode = 0
    # FALSE candidate (short, generic, coincidental prefix) enumerated
    # BEFORE the TRUE candidate -- Chrome's own internal window order,
    # unrelated to which one is actually correct.
    stdout = (
        '1111\t9369\n'
        'GitHub\tGitHub - Pull Request #123\n'
        '2222\t994908248'
    )
def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

raise SystemExit(m.main())
"
}
out="$(run_ambiguous_prefix_case)"
case "$out" in
    "9369	994908248") ok "the longer, more specific prefix match wins over an earlier, shorter coincidental match" ;;
    *) fail "expected the TRUE (longer-prefix) window 9369/994908248, got: [$out] -- first-match-wins picked the wrong window" ;;
esac

# Check 5 -- REPLACES the old "two Chrome windows, same workspace" guard,
# which used to ENFORCE the single-literal-focused-window decision this
# rewrite reverses (see git history if that account is needed again).
# Now: two Chrome windows in the SAME focused workspace must BOTH be
# matched and BOTH appear in fresh.tsv/stdout -- the whole point of the
# per-workspace scope change.
run_two_windows_same_workspace_case() {
    python3 -c "
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('active_now', '$HERE/active-now.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.LOCK_FILE = m.STATE_DIR / 'active-now.lock'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

def fake_aerospace(*args):
    if args[0] == 'list-windows' and '--workspace' in args and '--json' in args:
        return json.dumps([
            {'app-name': 'Google Chrome', 'window-id': 1, 'window-title': 'Config Surface Spec - Google Chrome - Peter'},
            {'app-name': 'Google Chrome', 'window-id': 2, 'window-title': 'Zoo Giraffe Encounter - Google Chrome - Peter'},
            {'app-name': 'Slack', 'window-id': 3, 'window-title': 'general - Boomi - Slack'},
        ])
    raise AssertionError('unexpected aerospace call: ' + repr(args))
m.aerospace = fake_aerospace

class FakeProc:
    returncode = 0
    stdout = (
        '9369\t2483\n'
        'Config Surface Spec\tZoo Giraffe Encounter\n'
        '994908248\t994907952'
    )
def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

raise SystemExit(m.main())
"
}
out="$(run_two_windows_same_workspace_case)"
case "$out" in
    *"9369	994908248"*) ok "the first workspace window (Config Surface Spec) is matched" ;;
    *) fail "expected 9369/994908248 among the results, got: [$out]" ;;
esac
case "$out" in
    *"2483	994907952"*) ok "the second workspace window (Zoo Giraffe Encounter) is ALSO matched, not dropped" ;;
    *) fail "expected 2483/994907952 among the results, got: [$out]" ;;
esac
line_count="$(printf '%s\n' "$out" | grep -c .)"
[ "$line_count" -eq 2 ] || fail "expected exactly 2 matched lines (one per workspace Chrome window), got $line_count: [$out]"
ok "exactly 2 lines -- the non-Chrome Slack window in the workspace is correctly excluded"

fresh_contents="$(cat "$TMP/fresh.tsv" 2>/dev/null)"
fresh_line_count="$(printf '%s\n' "$fresh_contents" | grep -c .)"
[ "$fresh_line_count" -eq 2 ] || fail "expected fresh.tsv to hold both pairs, got $fresh_line_count line(s): [$fresh_contents]"
ok "fresh.tsv holds both windows' pairs, not just one"

# Check 6 -- osascript's own trailing newline, 2026-09-28: `return` always
# comes back with a trailing "\n" appended (confirmed live: `return "a" &
# linefeed & "b"` -> 'a\nb\n', not 'a\nb'), which every HAND-WRITTEN mock
# above never had, so none of them could have caught this. A real
# invocation aborted with "returned 4 lines, expected 3" the very first
# time this ran against real Chrome output outside a mock.
run_trailing_newline_case() {
    python3 -c "
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('active_now', '$HERE/active-now.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.LOCK_FILE = m.STATE_DIR / 'active-now.lock'
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

def fake_aerospace(*args):
    if args[0] == 'list-windows' and '--workspace' in args and '--json' in args:
        return '''$(one_chrome_window_json "GitHub - Pull Request #123 - Google Chrome - Peter")'''
    raise AssertionError('unexpected aerospace call: ' + repr(args))
m.aerospace = fake_aerospace

class FakeProc:
    returncode = 0
    # A REAL osascript-shaped payload -- trailing newline included, same
    # as subprocess.run would actually capture it.
    stdout = '9369\nGitHub - Pull Request #123\n994908248\n'
def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

raise SystemExit(m.main())
"
}
out="$(run_trailing_newline_case)"
case "$out" in
    "9369	994908248") ok "osascript's own trailing newline on the enumeration output is handled, not mistaken for a 4th column group" ;;
    *) fail "expected 9369/994908248 despite the trailing newline, got: [$out]" ;;
esac

# Check 7 -- a confirmed-empty workspace (2026-09-28, new): AeroSpace
# reporting zero Chrome windows in the focused workspace is a real fact,
# not a miss, and must overwrite fresh.tsv with an empty file so a stale
# multi-window answer from before the user closed everything does not
# linger forever.
run_confirmed_empty_case() {
    python3 -c "
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('active_now', '$HERE/active-now.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.LOCK_FILE = m.STATE_DIR / 'active-now.lock'
m.FRESH_FILE.write_text('9369\t994908248\n')  # a stale prior answer
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

def fake_aerospace(*args):
    if args[0] == 'list-windows' and '--workspace' in args and '--json' in args:
        return json.dumps([{'app-name': 'Slack', 'window-id': 3, 'window-title': 'general - Boomi - Slack'}])
    raise AssertionError('unexpected aerospace call: ' + repr(args))
m.aerospace = fake_aerospace

def fake_run(*a, **k):
    raise AssertionError('ENUMERATE_ACTIVE_TABS must not run when the workspace has no Chrome windows at all')
m.subprocess.run = fake_run

raise SystemExit(m.main())
"
}
run_confirmed_empty_case >/dev/null
empty_contents="$(cat "$TMP/fresh.tsv" 2>/dev/null)"
[ -z "$empty_contents" ] || fail "expected fresh.tsv to become empty (confirmed no Chrome windows), got: [$empty_contents]"
ok "a confirmed-empty workspace overwrites a stale fresh.tsv with empty, not left alone"

# Check 8 -- a partial match failure leaves fresh.tsv untouched (2026-09-28,
# new): if AeroSpace reports 2 Chrome windows but only one can be matched
# against the bulk enumeration (a transient title-format miss), this must
# be treated as a WHOLE-RUN failure, not a partial write -- otherwise a
# still-good second window's entry could be silently dropped from
# fresh.tsv by a transient miss on an unrelated window.
run_partial_failure_case() {
    python3 -c "
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('active_now', '$HERE/active-now.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

m.STATE_DIR = pathlib.Path('$TMP')
m.FRESH_FILE = m.STATE_DIR / 'fresh.tsv'
m.LOCK_FILE = m.STATE_DIR / 'active-now.lock'
m.FRESH_FILE.write_text('7777\t888\n')  # a still-good prior answer
sys.path.insert(0, '$HERE')
import switcher_log
switcher_log.STATE_DIR = m.STATE_DIR
switcher_log.LOG_FILE = m.STATE_DIR / 'switcher.debug.log'

def fake_aerospace(*args):
    if args[0] == 'list-windows' and '--workspace' in args and '--json' in args:
        return json.dumps([
            {'app-name': 'Google Chrome', 'window-id': 1, 'window-title': 'Config Surface Spec - Google Chrome - Peter'},
            {'app-name': 'Google Chrome', 'window-id': 2, 'window-title': 'Totally Unmatched Title - Google Chrome - Peter'},
        ])
    raise AssertionError('unexpected aerospace call: ' + repr(args))
m.aerospace = fake_aerospace

class FakeProc:
    returncode = 0
    # Only ONE of the two targets has a real candidate in the bulk
    # enumeration -- 'Totally Unmatched Title' matches nothing.
    stdout = '9369\nConfig Surface Spec\n994908248'
def fake_run(*a, **k):
    return FakeProc()
m.subprocess.run = fake_run

raise SystemExit(m.main())
"
}
run_partial_failure_case >/dev/null
partial_contents="$(cat "$TMP/fresh.tsv" 2>/dev/null)"
case "$partial_contents" in
    "7777	888") ok "a partial match failure leaves the still-good prior fresh.tsv untouched" ;;
    *) fail "expected fresh.tsv to still hold the prior '7777\\t888' (whole-run failure), got: [$partial_contents]" ;;
esac

echo "smoke-active-now: $pass checks passed"
