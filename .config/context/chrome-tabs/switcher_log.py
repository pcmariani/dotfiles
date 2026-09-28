"""Shared diagnostic log for the whole chrome-tabs switcher pipeline
(poll.py, active-now.py, activate.py, rank.py, producer.sh), added
2026-09-27 at the user's own request after two persisting, hard-to-pin-
down reports ("stuck on the 2nd position", "switcher shows the wrong
workspace's tabs") that guesswork and isolated fixes hadn't resolved.

ONE shared file so `tail -f` shows the whole story in the ORDER it
actually happened, across processes -- the individual scripts' own prior
ad-hoc debug logs (picker-refresh.debug.log, steal-guard.debug.log) each
cover only their own script, which is exactly what makes a cross-script
race (poll.py vs active-now.py vs producer.sh's read) hard to reconstruct
from logs today.

Millisecond precision, not second precision -- these bugs are races
measured in hundreds of milliseconds; second-precision timestamps would
make every entry in a burst look simultaneous.

Self-capping, same convention as picker-refresh.sh's own debug log.
"""
import time
from pathlib import Path

STATE_DIR = Path.home() / ".local/state/context/chrome-tabs"
LOG_FILE = STATE_DIR / "switcher.debug.log"
MAX_LINES = 4000
TRIM_TO = 1000


def log(component, message):
    """Append one line: HH:MM:SS.mmm [component] message. Never raises --
    a logging failure must not break the thing it's trying to diagnose."""
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        line = f"{time.strftime('%H:%M:%S')}.{int(time.time() * 1000) % 1000:03d} [{component}] {message}\n"
        with open(LOG_FILE, "a") as f:
            f.write(line)
        _maybe_trim()
    except OSError:
        pass


def _maybe_trim():
    try:
        with open(LOG_FILE) as f:
            lines = f.readlines()
        if len(lines) > MAX_LINES:
            with open(LOG_FILE, "w") as f:
                f.writelines(lines[-TRIM_TO:])
    except OSError:
        pass
