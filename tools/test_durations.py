#!/usr/bin/env python3
"""Write tests/durations.tsv from a CI verify run's logs: `make durations RUN=ID`.

Every GitHub Actions log line carries an ISO timestamp. A test script's seconds
run from GUT's header line for it (its res://tests/unit/... path, alone on the
line) to the line that ends it ("N/M passed."), so its before_all and whatever it
works out first in its engine count, as they do in a shard. A script whose every
test is pending prints no such line: it ends where the next script, or the
summary, begins. A job's log is read
only up to GUT's "= Run Summary" banner: the summary reprints the path of every
script with a pending or failing test, and that reprint is no run.

`gh run view ID --log` prefixes each line with its job and step, tab-separated;
each job is read on its own. A bare log, one job's lines as they are, reads too.

Usage:  tools/test_durations.py --run ID              # fetch run ID's logs with gh, write the file
        tools/test_durations.py --log FILE [--run ID]  # read a saved log (- for stdin) instead
        ... [--out FILE]                               # write FILE instead (- for stdout)
"""

import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DURATIONS = ROOT / "tests" / "durations.tsv"

STAMP = re.compile(r"^\ufeff?(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?)Z ?(.*)$")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
HEADER = re.compile(r"^res://(tests/unit/\S+/test_\w+\.gd)\s*$")
END = re.compile(r"^\d+/\d+ (?:passed|failed)")
SUMMARY = "= Run Summary"


def stamp(text: str) -> datetime:
    """An Actions timestamp, its fraction cut to microseconds."""
    whole, _, fraction = text.partition(".")
    return datetime.fromisoformat(f"{whole}.{(fraction + '000000')[:6]}")


def parse(lines) -> tuple[dict[str, float], str]:
    """Each script's seconds, and the date of the log's first stamped line."""
    seconds: dict[str, float] = {}
    open_scripts: dict[str, tuple[str, datetime]] = {}
    finished: set[str] = set()
    first_day = ""
    for raw in lines:
        raw = raw.rstrip("\r\n")
        fields = raw.split("\t", 2)
        job, rest = (fields[0], fields[2]) if len(fields) == 3 else ("", raw)
        match = STAMP.match(rest)
        if not match:
            continue
        when = stamp(match.group(1))
        first_day = first_day or when.date().isoformat()
        if job in finished:
            continue
        text = ANSI.sub("", match.group(2)).strip()
        header = HEADER.match(text)
        summary = text.startswith(SUMMARY)
        if (header or summary or END.match(text)) and job in open_scripts:
            script, start = open_scripts.pop(job)
            took = (when - start).total_seconds()
            seconds[script] = max(seconds.get(script, 0.0), took)
        if summary:
            finished.add(job)
        elif header:
            open_scripts[job] = (header.group(1), when)
    return seconds, first_day


def render(seconds: dict[str, float], run: str, day: str) -> str:
    source = f"verify run {run}, {day}" if run else f"a verify log, {day}"
    command = f"make durations RUN={run}" if run else "tools/test_durations.py"
    lines = [
        f"# Seconds each test script took on a hosted CI runner ({source}), written by `{command}`.",
        "# Timed from GUT's header line for the script to its passed line, or to the next script's when every test is pending; whole seconds.",
        "# A script that reads SimFixtures.match_hits pays for working the hits out in its own engine, as it does in a shard.",
        "# tools/test_shards.py balances the shards by these; regenerate the file when the split drifts.",
    ]
    for script in sorted(seconds):
        lines.append(f"{script}\t{int(seconds[script] + 0.5)}")
    return "\n".join(lines) + "\n"


def fetch(run: str) -> list[str]:
    result = subprocess.run(
        ["gh", "run", "view", run, "--log"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        sys.exit(f"test_durations: gh run view {run} --log failed: {result.stderr.strip()}")
    return result.stdout.splitlines()


def main(argv: list[str]) -> int:
    options = {"--run": "", "--log": "", "--out": str(DURATIONS)}
    while argv:
        if len(argv) < 2 or argv[0] not in options:
            print(__doc__, file=sys.stderr)
            return 2
        options[argv[0]] = argv[1]
        argv = argv[2:]
    run, log, out = options["--run"], options["--log"], options["--out"]
    if run and not run.isdigit():
        sys.exit(f"test_durations: {run} is not a run id")
    if log == "-":
        lines = sys.stdin.read().splitlines()
    elif log:
        lines = Path(log).read_text(encoding="utf-8").splitlines()
    elif run:
        lines = fetch(run)
    else:
        print(__doc__, file=sys.stderr)
        return 2
    seconds, day = parse(lines)
    if not seconds:
        sys.exit("test_durations: the log times no test script")
    text = render(seconds, run, day)
    if out == "-":
        sys.stdout.write(text)
    else:
        Path(out).write_text(text, encoding="utf-8")
        print(f"test_durations: {len(seconds)} scripts to {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
