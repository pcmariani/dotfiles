#!/bin/bash
# Checks for tab_label.py -- the first two columns of the chrome-tabs panel
# (2026-10-25, the user: "column 1: the tab's app, col 2: description, col 3:
# url", url cut at 80 characters with an ellipsis). Pure functions, no state.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

python3 - "$HERE" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import tab_label as t

fails = []
def check(name, got, want):
    if got != want:
        fails.append(f"{name}: got {got!r}, want {want!r}")
    else:
        print(f"   ok: {name}")

# app by url
check("gmail", t.app_for("https://mail.google.com/mail/u/1/#inbox"), "Gmail")
check("calendar", t.app_for("https://calendar.google.com/calendar/u/1/r/week/2026/10/19"), "Calendar")
check("chat", t.app_for("https://chat.google.com/u/1/app/chat/xzaT"), "Chat")
check("sheets by path", t.app_for("https://docs.google.com/spreadsheets/d/1Cb/edit?gid=1"), "Google Sheets")
check("docs by path", t.app_for("https://docs.google.com/document/d/1Cb/edit"), "Google Docs")
check("gemini", t.app_for("https://gemini.google.com/app/f05a"), "Gemini")
check("no app", t.app_for("https://www.homerow.app/"), "")
check("chrome page", t.app_for("chrome://newtab/"), "")
check("host is not a substring match", t.app_for("https://notmail.google.com.evil.example/"), "")

# description: the title minus the app and account noise
check("gmail desc", t.describe("Inbox (1) - pmariani@boomi.com - Boomi, LP Mail", "Gmail"), "Inbox (1)")
check("gmail personal desc", t.describe("Inbox (26,311) - pcmariani@gmail.com - Gmail", "Gmail"), "Inbox (26,311)")
check("calendar desc", t.describe("Boomi, LP - Calendar - Week of October 19, 2026", "Calendar"), "Boomi, LP - Week of October 19, 2026")
check("chat desc", t.describe("Kayla Simmons - Chat", "Chat"), "Kayla Simmons")
check("sheets desc", t.describe("Wintersteiger Mapping & Rental Alias Table - Google Sheets", "Google Sheets"), "Wintersteiger Mapping & Rental Alias Table")
check("gemini desc", t.describe("Reviewing a Check-in Message - Google Gemini", "Gemini"), "Reviewing a Check-in Message")
check("no app keeps the title", t.describe("Homerow — Keyboard shortcuts for every button in macOS", ""), "Homerow — Keyboard shortcuts for every button in macOS")
check("never empty", t.describe("Gmail", "Gmail"), "Gmail")

# url truncation
long = "https://example.com/" + "a" * 100
check("short url untouched", t.shorten_url("https://example.com/x"), "https://example.com/x")
check("exactly 35 untouched", t.shorten_url("h" * 35), "h" * 35)
check("36 cut to 35 plus ellipsis", t.shorten_url("h" * 36), "h" * 35 + "…")
check("long url", t.shorten_url(long), long[:35] + "…")
check("okta by sso host", t.app_for("https://sso.boomi.com/app/UserHome?session_hint=AUTHENTICATED"), "Okta")

# one display row
row = t.columns("Gmail", "Inbox (1)", "https://mail.google.com/mail/u/1/#inbox")
check("columns pad app and description", row[:18], "Gmail" + " " * 13)
check("five spaces after the app, even the longest", t.columns("Google Sheets", "x", "u")[:18], "Google Sheets" + " " * 5)
check("five spaces after a cut description", t.columns("", "d" * 60, "u")[18:67].endswith("…" + " " * 5), True)
# the row after the icon: mark column, five spaces, then the columns
plain = t.row(False, "T", False)
check("hidden tab: blank mark column then the gap", plain, " " * 3 + " " + " " * 5 + "T")
check("active tab: dot mark", t.row(True, "T", False)[:4], "   ●")
check("current row dimmed whole", t.row(True, "T", True), "\033[2m" + "   ●" + " " * 5 + "T" + "\033[0m")
if fails:
    print("\n".join("FAIL: " + f for f in fails), file=sys.stderr)
    sys.exit(1)
print("all tab_label checks passed")
PY
