"""The text of one chrome-tabs row, left of the active-tab marker's column:

    <app>     <description>     <url, cut at 50 characters>

(2026-10-25, the user: "column 1: the tab's app (if there is one), col 2:
description, col 3: url".) The app comes from the URL alone, by host and, for
Google Docs' shared host, by the first path segment; a tab with no known app
gets a blank first column. The description is the page title with the app's own
name and account noise taken out ("Inbox (1) - pmariani@boomi.com - Boomi, LP
Mail" is just "Inbox (1)"), and never empty: a title that is nothing but noise
stays whole.

Add an app by adding a line to APPS (host, optional path prefix, name).
"""
import re
from urllib.parse import urlsplit

GAP = 5                 # spaces between two columns, as in the workspace picker (2026-10-26, the user: breathing room)
APP_WIDTH = 13          # "Google Sheets" is the longest name, 13
DESCRIPTION_WIDTH = 44
URL_LIMIT = 50          # characters kept, then an ellipsis (was 80)

DIM_ON = "\033[2m"
DIM_OFF = "\033[0m"

# The tab showing in its window. The same dot the workspace picker uses for
# "has something"; blank for a hidden tab.
ACTIVE_MARK = "●"

# (host, path prefix or "", app). Host must match exactly or be a subdomain of
# it; the longest path prefix for a host wins.
APPS = [
    ("mail.google.com", "", "Gmail"),
    ("calendar.google.com", "", "Calendar"),
    ("chat.google.com", "", "Chat"),
    ("meet.google.com", "", "Meet"),
    ("drive.google.com", "", "Drive"),
    ("docs.google.com", "/spreadsheets", "Google Sheets"),
    ("docs.google.com", "/document", "Google Docs"),
    ("docs.google.com", "/presentation", "Google Slides"),
    ("docs.google.com", "/forms", "Google Forms"),
    ("gemini.google.com", "", "Gemini"),
    ("chatgpt.com", "", "ChatGPT"),
    ("claude.ai", "", "Claude"),
    ("github.com", "", "GitHub"),
    ("app.slack.com", "", "Slack"),
    ("sso.boomi.com", "", "Okta"),
    ("boomi.okta.com", "", "Okta"),
]

_EMAIL = re.compile(r"^\S+@\S+\.\S+$")


def app_for(url):
    parts = urlsplit(url)
    host = (parts.hostname or "").lower()
    best, best_len = "", -1
    for app_host, prefix, name in APPS:
        if host != app_host:
            continue
        if prefix and not parts.path.startswith(prefix):
            continue
        if len(prefix) > best_len:
            best, best_len = name, len(prefix)
    return best


def describe(title, app):
    """`title` without the segments that only say which app or account this is;
    the whole title when nothing else is left."""
    if not app:
        return title
    own = {app.lower(), "google " + app.lower()}
    kept = []
    for seg in title.split(" - "):
        low = seg.strip().lower()
        if low in own or _EMAIL.match(seg.strip()) or low.endswith(" mail"):
            continue
        kept.append(seg)
    return " - ".join(kept) if kept else title


def shorten_url(url):
    return url if len(url) <= URL_LIMIT else url[:URL_LIMIT] + "…"


def _fit(text, width):
    """`text` padded or cut to `width` characters, then GAP spaces."""
    if len(text) <= width:
        return text.ljust(width) + " " * GAP
    return text[: width - 1] + "…" + " " * GAP


def columns(app, description, url):
    return (f"{_fit(app, APP_WIDTH)}{_fit(description, DESCRIPTION_WIDTH)}"
            f"{DIM_ON}{shorten_url(url)}{DIM_OFF}")


def row(active, text, current):
    """The display after the icon request: a mark column, then `text`. The
    current tab (the one you are on, row 1) is dimmed whole, as the workspace
    picker dims the workspace you stand in."""
    body = f" {ACTIVE_MARK if active else ' '}{' ' * GAP}{text}"
    return f"{DIM_ON}{body}{DIM_OFF}" if current else body
