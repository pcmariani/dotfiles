"""The text of one chrome-tabs row, left of the active-tab marker's column:

    <app>     <description>     <url, cut at 35 characters>

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

AFTER_ICON = 3          # spaces between the favicon and the mark (2026-10-26, the user: two more)
MARK_GAP = 1            # spaces between the mark and the app name (2026-10-27, the user: "only one space")
GAP = 5                 # spaces between two columns, as in the workspace picker (2026-10-26, the user: breathing room)
APP_WIDTH = 13          # "Google Sheets" is the longest name, 13
CAP = 120               # characters of one title column kept, then an ellipsis (paneld cuts to its room)
URL_LIMIT = 35          # characters kept, then an ellipsis (was 80, then 50)

DIM_ON = "\033[2m"
DIM_OFF = "\033[0m"

# The tab showing in its window. The same dot the workspace picker uses for
# "has something"; blank for a hidden tab, and blank for every tab when the
# workspace has only one Chrome window (2026-10-27, the user: the dot only
# tells windows apart, so one window needs none).
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
    """`text` padded to `width`, then GAP spaces. Never cut: paneld cuts a name to
    the room it has, and the panel is as wide as its rows ask (the producer's own
    44-character cut hid the end of a title the panel had room for)."""
    return text.ljust(width) + " " * GAP


def _cap(text):
    """A title past CAP characters ends in an ellipsis, so a runaway title cannot
    ask the panel for a whole screen."""
    return text if len(text) <= CAP else text[: CAP - 1] + "…"


_SEPARATORS = (" - ", " – ", " — ", ": ")


_DASH = re.compile(r" [-–—] ")


def _is_boomi_platform(url):
    host = (urlsplit(url).hostname or "").lower()
    return host == "platform.boomi.com" or host.endswith(".platform.boomi.com")


def _boomi_split(title):
    """Boomi platform tabs read `<account> - <page> - Boomi Enterprise Platform`:
    the page (everything between the first and last dash) is the main title, the
    account and the product the sub (2026-11-05, the user, a Boomi developer).
    None when the title has fewer than three parts or an empty one.

    A title the bridge extension's boomi-title.js already rewrote reads `<page> — <account>` (an em
    dash): the last em dash divides it, the page keeps any dash of its own."""
    if " — " in title:
        page, _, account = title.rpartition(" — ")
        if page.strip() and account.strip():
            return page.strip(), account.strip()
    parts = _DASH.split(title)
    if len(parts) < 3 or not all(p.strip() for p in parts):
        return None
    dashes = list(_DASH.finditer(title))
    middle = title[dashes[0].end():dashes[-1].start()]
    return middle.strip(), f"{parts[0].strip()} - {parts[-1].strip()}"


def split_title(title, url=""):
    """(main, sub): the title cut at its first spaced hyphen, en dash or em dash,
    or its first colon followed by a blank (2026-11-05, the user: "a main title and
    a sub title in grey", then "just ':' for now"; a colon with no blank after it
    is a time or a url). No separator, or nothing on one side of it, leaves the
    whole title as the main. A Boomi platform tab (by its url) has its own rule."""
    if _is_boomi_platform(url):
        boomi = _boomi_split(title)
        if boomi:
            return boomi
    found = [(i, len(sep)) for sep in _SEPARATORS for i in [title.find(sep)] if i >= 0]
    if found:
        at, width = min(found)
        main, sub = title[:at].strip(), title[at + width:].strip()
        if main and sub:
            return main, sub
    return title.strip(), ""


def columns(app, description, url):
    """Two text columns, then the dim url. A tab with an app reads `<app>
    <description>`; one without reads `<main title> <sub title>`."""
    first, second = (app, description) if app else split_title(description, url)
    return (f"{_fit(_cap(first), APP_WIDTH)}{_fit(_cap(second), 0)}"
            f"{DIM_ON}{shorten_url(url)}{DIM_OFF}")


def row(active, text, current, show_mark=True):
    """The display after the icon request: a mark column, then `text`. The
    current tab (the one you are on, row 1) is dimmed whole, as the workspace
    picker dims the workspace you stand in. `show_mark` False keeps the column
    (blank) so the text stays where it is; rank.py passes it only when the
    tabs listed span more than one Chrome window."""
    mark = ACTIVE_MARK if active and show_mark else " "
    body = f"{' ' * AFTER_ICON}{mark}{' ' * MARK_GAP}{text}"
    return f"{DIM_ON}{body}{DIM_OFF}" if current else body
