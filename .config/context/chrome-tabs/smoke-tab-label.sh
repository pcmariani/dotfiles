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
# a tab with no app: the title splits at the first spaced dash, en dash or em dash into
# a main title and a sub title (2026-11-05, the user), each a column paneld lines up
check("split on a hyphen", t.split_title("CSC Sugar, LLC - Process Reporting - Boomi"), ("CSC Sugar, LLC", "Process Reporting - Boomi"))
check("split on an em dash", t.split_title("Homerow — Keyboard shortcuts"), ("Homerow", "Keyboard shortcuts"))
check("split on an en dash", t.split_title("A – B"), ("A", "B"))
check("the earliest separator wins", t.split_title("A — B - C"), ("A", "B - C"))
check("a hyphen inside a word is not a separator", t.split_title("Check-in notes"), ("Check-in notes", ""))
check("no separator: whole title is the main", t.split_title("Project Unity Interfaces"), ("Project Unity Interfaces", ""))
check("an empty side is no split", t.split_title("A - "), ("A -", ""))
check("title that starts with a dash is no split", t.split_title(" - B"), ("- B", ""))
nm = t.columns("", "CSC Sugar, LLC - Process Reporting", "u")
check("no app: main, five spaces, sub, five spaces", nm[:14 + 5 + 17 + 5], "CSC Sugar, LLC" + " " * 5 + "Process Reporting" + " " * 5)
check("no app: main longer than the app column is not cut", t.columns("", "x" * 40 + " - y", "u")[:40], "x" * 40)
check("an app row keeps app and description", t.columns("Gmail", "Inbox - Today", "u")[18:31], "Inbox - Today")
check("a very long sub title is cut with an ellipsis", t.columns("", "m - " + "s" * 300, "u").count("s") < 300, True)
# the row after the icon: mark column, ONE space, then the columns
plain = t.row(False, "T", False)
check("hidden tab: blank mark column then one space", plain, " " * 3 + " " + " " + "T")
check("active tab: dot mark, one space", t.row(True, "T", False), "   ● T")
check("current row dimmed whole", t.row(True, "T", True), "\033[2m" + "   ● T" + "\033[0m")
check("single window: no dot, same layout", t.row(True, "T", False, show_mark=False), " " * 3 + " " + " " + "T")
if fails:
    print("\n".join("FAIL: " + f for f in fails), file=sys.stderr)
    sys.exit(1)
print("all tab_label checks passed")
PY
