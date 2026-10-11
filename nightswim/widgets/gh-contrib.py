#!/usr/bin/env python3
"""Cache the last 26 weeks of GitHub contributions for the conky widget.

Uses the `gh` CLI's auth. Writes ~/.cache/nightswim/gh-contrib.txt:
    <login> <total in window> <HH:MM synced>
    <YYYY-MM-DD of week's Sunday> <7 levels 0-4, one char per day; '.' = future>
    ...
Prints nothing (conky calls it through texeci). On failure the old cache stays.
"""
import json
import pathlib
import subprocess
import sys
import time

WEEKS = 26
LEVEL = {"NONE": "0", "FIRST_QUARTILE": "1", "SECOND_QUARTILE": "2",
         "THIRD_QUARTILE": "3", "FOURTH_QUARTILE": "4"}
QUERY = """query { viewer { login contributionsCollection { contributionCalendar {
  weeks { contributionDays { date weekday contributionCount contributionLevel } } } } } }"""


def main():
    # Fixed path (not $XDG_CACHE_HOME): snap terminals override that variable,
    # and the conky reader must agree with whoever ran the fetch.
    out = pathlib.Path.home() / ".cache/nightswim/gh-contrib.txt"
    try:
        raw = subprocess.run(["gh", "api", "graphql", "-f", f"query={QUERY}"],
                             capture_output=True, text=True, timeout=30, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        return 0
    viewer = json.loads(raw)["data"]["viewer"]
    weeks = viewer["contributionsCollection"]["contributionCalendar"]["weeks"][-WEEKS:]
    total = sum(d["contributionCount"] for w in weeks for d in w["contributionDays"])
    lines = [f'{viewer["login"]} {total} {time.strftime("%H:%M")}']
    for w in weeks:
        days = {d["weekday"]: LEVEL.get(d["contributionLevel"], "0") for d in w["contributionDays"]}
        first = w["contributionDays"][0]
        # weekday 0 = Sunday; the first week can start mid-week.
        sunday = time.strftime("%Y-%m-%d", time.localtime(
            time.mktime(time.strptime(first["date"], "%Y-%m-%d")) - first["weekday"] * 86400))
        lines.append(sunday + " " + "".join(days.get(i, ".") for i in range(7)))
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp")
    tmp.write_text("\n".join(lines) + "\n")
    tmp.replace(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
