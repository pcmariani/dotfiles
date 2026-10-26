"""A tab's favicon as a PNG file on disk, for the icon column of the
chrome-tabs panel (paneld draws any image path a row names).

Chrome keeps every favicon it has seen in a `Favicons` SQLite file per profile
(`icon_mapping` page url -> icon, `favicon_bitmaps` the PNGs). Reading those
is offline: nothing about a page leaves the machine, unlike a favicon service.
Each database is opened read-only and immutable, which is what lets it be read
while Chrome has it open; a copy of the best bitmap is written once under
CACHE_DIR, named by the hash of its bytes, so the same icon from two profiles
is one file.

A page url is looked up exactly first, then by any page on the same host (a
tab that just navigated may not be mapped yet). The bitmap nearest 32 px from
above wins: paneld draws it at 16 pt, which is 32 px on this screen.
"""
import glob
import hashlib
import os
import sqlite3
from pathlib import Path
from urllib.parse import urlsplit

CHROME_DIR = os.path.expanduser("~/Library/Application Support/Google/Chrome")
CACHE_DIR = str(Path.home() / ".local/state/context/chrome-tabs/favicons")

_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

_BEST = ("select b.image_data from favicon_bitmaps b where b.icon_id = ? "
         "order by b.width < 32, b.width limit 1")


def _databases():
    paths = glob.glob(os.path.join(CHROME_DIR, "Default", "Favicons"))
    paths += sorted(glob.glob(os.path.join(CHROME_DIR, "Profile *", "Favicons")))
    return paths


def _icon_id(conn, url, host_prefixes):
    row = conn.execute("select icon_id from icon_mapping where page_url = ? limit 1", (url,)).fetchone()
    if row:
        return row[0]
    for prefix in host_prefixes:
        # A range on the indexed column, not LIKE: `<prefix>` up to `<prefix>`
        # with its last character ('/') bumped to '0'.
        row = conn.execute(
            "select icon_id from icon_mapping where page_url >= ? and page_url < ? limit 1",
            (prefix, prefix[:-1] + "0")).fetchone()
        if row:
            return row[0]
    return None


def _store(data):
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, hashlib.sha1(data).hexdigest() + ".png")
    if not os.path.exists(path):
        tmp = f"{path}.{os.getpid()}"
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, path)
    return path


def icon_path_for(url):
    """Path of a PNG for the tab at `url`, or "" when Chrome has none."""
    parts = urlsplit(url)
    if parts.scheme not in ("http", "https") or not parts.hostname:
        return ""
    host_prefixes = [f"{scheme}://{parts.netloc}/" for scheme in ("https", "http")]
    for db in _databases():
        try:
            conn = sqlite3.connect(f"file:{db}?immutable=1", uri=True, timeout=1)
            try:
                icon = _icon_id(conn, url, host_prefixes)
                row = conn.execute(_BEST, (icon,)).fetchone() if icon is not None else None
            finally:
                conn.close()
        except (sqlite3.Error, OSError):
            continue
        if row and row[0] and bytes(row[0]).startswith(_PNG_MAGIC):
            try:
                return _store(bytes(row[0]))
            except OSError:
                return ""
    return ""
