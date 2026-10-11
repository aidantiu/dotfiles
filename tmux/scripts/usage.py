#!/usr/bin/env python3
"""tmux status-right pill: Claude 5h / weekly plan usage + Cursor monthly usage.

Claude : https://api.anthropic.com/api/oauth/usage   (token: ~/.claude/.credentials.json)
Cursor : https://cursor.com/api/usage-summary        (token: Cursor's state.vscdb)

Results are cached in ~/.cache/tmux-usage.json (TTL 120s). A failed fetch keeps the
last good value, so a flaky network or an expired Claude token never blanks the bar.
Toggle visibility with prefix+u (flips the tmux option @usage_show; see tmux.conf).
"""
import base64
import json
import os
import sqlite3
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

TTL = 120
CACHE = os.path.expanduser("~/.cache/tmux-usage.json")
CLAUDE_CREDS = os.path.expanduser("~/.claude/.credentials.json")
CURSOR_DB = os.path.expanduser("~/.config/Cursor/User/globalStorage/state.vscdb")

PILL, TEXT = "#2a2f55", "#d6cfe8"
OK, WARN, ERR = "#8cc4d4", "#e8a95b", "#c9566b"
CAP_L, CAP_R = "\ue0b6", "\ue0b4"


def get_json(url, headers):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", **headers})
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.load(r)


def fetch_claude():
    with open(CLAUDE_CREDS) as f:
        token = json.load(f)["claudeAiOauth"]["accessToken"]
    d = get_json(
        "https://api.anthropic.com/api/oauth/usage",
        {"Authorization": f"Bearer {token}", "anthropic-beta": "oauth-2025-04-20"},
    )
    return {k: d[k]["utilization"] for k in ("five_hour", "seven_day") if d.get(k)}


def fetch_cursor():
    db = sqlite3.connect(f"file:{CURSOR_DB}?mode=ro", uri=True)
    token = db.execute(
        "select value from ItemTable where key='cursorAuth/accessToken'"
    ).fetchone()[0]
    payload = token.split(".")[1]
    sub = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))["sub"]
    uid = sub.split("|")[-1]
    d = get_json(
        "https://cursor.com/api/usage-summary",
        {"Cookie": f"WorkosCursorSessionToken={uid}%3A%3A{token}"},
    )
    return {"total": d["individualUsage"]["plan"]["totalPercentUsed"]}


def load_cache():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def refresh(cache):
    now = time.time()
    jobs = {
        n: fn
        for n, fn in (("claude", fetch_claude), ("cursor", fetch_cursor))
        if now - cache.get(n, {}).get("ts", 0) >= TTL
    }
    if not jobs:
        return cache
    with ThreadPoolExecutor() as ex:
        futs = {n: ex.submit(fn) for n, fn in jobs.items()}
    for n, fut in futs.items():
        try:
            cache[n] = {"ts": now, "data": fut.result()}
        except Exception:
            # keep last good data, back off one TTL (retry in ~30s)
            old = cache.get(n, {})
            cache[n] = {"ts": now - TTL + 30, "data": old.get("data")}
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = f"{CACHE}.{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(cache, f)
    os.replace(tmp, CACHE)
    return cache


def colour(p):
    return ERR if p >= 80 else WARN if p >= 60 else OK


def part(label, p):
    if p is None:
        return f"#[fg={TEXT}]{label} ?"
    return f"#[fg={TEXT}]{label} #[fg={colour(p)}]{round(p)}%"


def main():
    cache = refresh(load_cache())
    claude = (cache.get("claude") or {}).get("data") or {}
    cursor = (cache.get("cursor") or {}).get("data") or {}
    parts = [
        part("5h", claude.get("five_hour")),
        part("wk", claude.get("seven_day")),
        part("cur", cursor.get("total")),
    ]
    body = f"#[fg={TEXT}] \u00b7 ".join(parts)
    print(
        f"#[fg={PILL},bg=default]{CAP_L}#[bg={PILL}]\uf080 {body} "
        f"#[fg={PILL},bg=default]{CAP_R} ",
        end="",
    )


if __name__ == "__main__":
    main()
