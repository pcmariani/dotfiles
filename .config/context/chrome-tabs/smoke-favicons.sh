#!/bin/bash
# Checks for favicons.py: tab url -> a cached PNG made from Chrome's own
# `Favicons` databases (one per profile). Everything runs on a fake Chrome
# directory and a throwaway cache directory; the real ones are never touched
# (tests-never-touch-real-state).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 - "$HERE" <<'PY'
import hashlib, os, sqlite3, sys, tempfile
sys.path.insert(0, sys.argv[1])
import favicons

tmp = tempfile.mkdtemp()
chrome = os.path.join(tmp, "Chrome"); cache = os.path.join(tmp, "cache")
favicons.CHROME_DIR = chrome; favicons.CACHE_DIR = cache
PNG = lambda tag: b"\x89PNG\r\n\x1a\n" + tag.encode()

def make_db(profile, rows):
    """rows: (page_url, icon_id, width, tag)"""
    d = os.path.join(chrome, profile); os.makedirs(d)
    c = sqlite3.connect(os.path.join(d, "Favicons"))
    c.execute("create table icon_mapping(id integer primary key, page_url longvarchar, icon_id integer)")
    c.execute("create table favicon_bitmaps(id integer primary key, icon_id integer, width integer, image_data blob)")
    for url, icon, width, tag in rows:
        c.execute("insert into icon_mapping(page_url, icon_id) values (?,?)", (url, icon))
        c.execute("insert into favicon_bitmaps(icon_id, width, image_data) values (?,?,?)", (icon, width, PNG(tag)))
    c.commit(); c.close()

make_db("Default", [
    ("https://mail.google.com/mail/u/1/#inbox", 1, 16, "mail16"),
    ("https://mail.google.com/mail/u/1/#inbox", 1, 32, "mail32"),
    ("https://mail.google.com/mail/u/1/#inbox", 1, 64, "mail64"),
    ("https://docs.example.com/a", 2, 16, "docs16"),
    ("https://only16.example/", 3, 16, "only16"),
])
make_db("Profile 2", [("https://other.example/x", 4, 32, "other32")])
os.makedirs(os.path.join(chrome, "Profile 9")); open(os.path.join(chrome, "Profile 9", "Favicons"), "w").write("not sqlite")

fails = []
def check(name, cond, detail=""):
    if cond: print(f"   ok: {name}")
    else: fails.append(f"{name} {detail}")

def content(path): return open(path, "rb").read()
def cached(tag): return os.path.join(cache, hashlib.sha1(PNG(tag)).hexdigest() + ".png")

p = favicons.icon_path_for("https://mail.google.com/mail/u/1/#inbox")
check("exact page url hits", p != "", p)
check("prefers the 32 px bitmap over 16 and 64", p == cached("mail32"), p)
check("the cached file holds the png", p and content(p) == PNG("mail32"))
check("any page on the host is the fallback", favicons.icon_path_for("https://docs.example.com/other/page") == cached("docs16"))
check("a lone 16 px bitmap is better than none", favicons.icon_path_for("https://only16.example/") == cached("only16"))
check("another profile's database is searched", favicons.icon_path_for("https://other.example/x") == cached("other32"))
check("unknown host is empty", favicons.icon_path_for("https://nowhere.example/") == "")
check("chrome:// pages are empty", favicons.icon_path_for("chrome://newtab/") == "")
check("a second lookup reuses the cached file", favicons.icon_path_for("https://other.example/x") == cached("other32"))
check("a prefix of the host is not the host", favicons.icon_path_for("https://docs.example.com.evil/a") == "")
favicons.CHROME_DIR = os.path.join(tmp, "missing")
check("no Chrome directory is empty, not an error", favicons.icon_path_for("https://mail.google.com/") == "")

if fails:
    print("\n".join("FAIL: " + f for f in fails), file=sys.stderr); sys.exit(1)
print("all favicon checks passed")
PY
