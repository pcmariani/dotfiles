"""Pure row-generation logic for the send-tab picker. No AeroSpace or
Chrome calls in this file -- producer.sh does the real enumeration and
calls build_rows() with the results, so this stays testable with plain
fixture data, matching this directory's chrome-tabs/rank.py precedent.
"""


def build_rows(workspaces, chrome_windows, source_window_id):
    """`workspaces`: list of known workspace names (str), in the order
    they should be offered (producer.sh sources this from `context list`,
    already ordered however that command orders it -- unchanged here).

    `chrome_windows`: list of dicts, one per real Chrome window found
    machine-wide, each `{"workspace": str, "window_id": int, "title": str}`
    -- as `aerospace list-windows --all --json` naturally gives, mapped to
    this shape by producer.sh.

    `source_window_id`: the window_id of the tab being sent -- excluded
    from every count, since it hasn't gone anywhere yet.

    Returns a list of (display, value) pairs. `value` is one of:
      "new:<workspace>"   -- create a new window there (0 other windows)
      "merge:<window_id>" -- merge directly into that window (1, or a
                             specific one of several)
    """
    by_workspace = {}
    for w in chrome_windows:
        if w["window_id"] == source_window_id:
            continue
        by_workspace.setdefault(w["workspace"], []).append(w)

    # Titles that appear more than once ACROSS THE WHOLE MACHINE (not just
    # within one workspace's own list) get a disambiguating suffix on
    # their row label -- display-only, since the merge itself is keyed by
    # window_id and needs no disambiguation to act correctly (see the
    # plan's "Refinements over the spec").
    title_counts = {}
    for w in chrome_windows:
        if w["window_id"] == source_window_id:
            continue
        title_counts[w["title"]] = title_counts.get(w["title"], 0) + 1

    def label_for(window):
        if title_counts[window["title"]] > 1:
            return f'{window["title"]} ({window["workspace"]})'
        return window["title"]

    rows = []
    for ws in workspaces:
        windows = by_workspace.get(ws, [])
        if len(windows) == 0:
            rows.append((ws, f"new:{ws}"))
        elif len(windows) == 1:
            rows.append((ws, f"merge:{windows[0]['window_id']}"))
        else:
            for w in windows:
                rows.append((label_for(w), f"merge:{w['window_id']}"))
    return rows
