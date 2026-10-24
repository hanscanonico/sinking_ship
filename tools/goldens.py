#!/usr/bin/env python3
"""Write the goldens a run printed into tests/golden/: `make goldens [RUN=ID]`.

A golden test (Goldens.check, tests/unit/goldens.gd) prints the text it worked out
whenever its platform has no golden or the text is not the golden's: base64 between
a `golden FILE begin BYTES SHA256` line and a `golden FILE end` line. This reads
those blocks back out of a log, checks each against its size and SHA-256, and writes
it as tests/golden/FILE. A log that holds none means every golden it ran matched.

`gh run view ID --log` puts the job, the step and a timestamp before each line's
text, and GUT's colour escapes come either as the escape character or written out
as `^[`; all are cut. Two blocks for one file that disagree stop the run: runs of
one build on one platform that disagree are a determinism bug (D4), not a golden.

Usage:  tools/goldens.py --run ID     # a CI verify run's logs, fetched with gh: CI's goldens
        tools/goldens.py --here       # the golden tests run here: this machine's goldens
        tools/goldens.py --log FILE   # a saved log, - for stdin
        ... [--out DIR]               # write under DIR instead of tests/golden
"""

import base64
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GOLDEN_DIR = ROOT / "tests" / "golden"
# The scripts whose tests hold their text to goldens: what --here runs.
TESTS = [
    "tests/unit/core/test_battle_royale_digests.gd",
    "tests/unit/core/test_determinism.gd",
    "tests/unit/core/test_survival_transcript.gd",
]

STAMP = re.compile(r"^\ufeff?\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z ?(.*)$")
ANSI = re.compile(r"(?:\x1b|\^\[)\[[0-9;]*m")
# A golden's file name is a plain NAME.PLATFORM.txt: nothing that leaves the folder.
BEGIN = re.compile(r"^golden ([a-z0-9_]+\.[a-z0-9_]+-[a-z0-9_]+\.txt) begin (\d+) ([0-9a-f]{64})$")


def text_of(line: str) -> str:
    """A log line's own text: job and step columns, timestamp and colour escapes cut."""
    fields = line.rstrip("\r\n").split("\t", 2)
    text = fields[2] if len(fields) == 3 else line.rstrip("\r\n")
    stamped = STAMP.match(text)
    if stamped:
        text = stamped.group(1)
    return ANSI.sub("", text).strip()


def blocks(lines) -> dict[str, bytes]:
    """Every golden the lines carry, by file name, each checked against its header."""
    found: dict[str, bytes] = {}
    current = None
    for line in lines:
        text = text_of(line)
        if current is None:
            begin = BEGIN.match(text)
            if begin:
                current = (begin.group(1), int(begin.group(2)), begin.group(3), [])
            continue
        name, size, digest, chunks = current
        if text != f"golden {name} end":
            chunks.append(text)
            continue
        try:
            data = base64.b64decode("".join(chunks), validate=True)
        except ValueError:
            sys.exit(f"goldens: {name}'s block is not base64")
        if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
            sys.exit(f"goldens: {name}'s block does not match its size and SHA-256")
        if name in found and found[name] != data:
            sys.exit(f"goldens: two runs printed {name} differently, a determinism bug (D4)")
        found[name] = data
        current = None
    if current is not None:
        sys.exit(f"goldens: the log ends inside {current[0]}'s block")
    return found


def fetch(run: str) -> list[str]:
    result = subprocess.run(
        ["gh", "run", "view", run, "--log"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        sys.exit(f"goldens: gh run view {run} --log failed: {result.stderr.strip()}")
    return result.stdout.splitlines()


def here() -> list[str]:
    """The golden tests' output, run in one engine here. A golden that no longer
    matches fails its test; that is the run this is for, so its status is not read."""
    result = subprocess.run(
        ["bash", "tools/run_tests.sh", "--list", "-"],
        cwd=ROOT,
        input="\n".join(TESTS) + "\n",
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return (result.stdout + "\n" + result.stderr).splitlines()


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(newline="\n")
    out = GOLDEN_DIR
    lines = None
    while argv:
        if argv[0] == "--here":
            lines = here()
            argv = argv[1:]
        elif len(argv) >= 2 and argv[0] == "--run":
            if not argv[1].isdigit():
                sys.exit(f"goldens: {argv[1]} is not a run id")
            lines = fetch(argv[1])
            argv = argv[2:]
        elif len(argv) >= 2 and argv[0] == "--log":
            source = argv[1]
            text = sys.stdin.read() if source == "-" else Path(source).read_text(encoding="utf-8")
            lines = text.splitlines()
            argv = argv[2:]
        elif len(argv) >= 2 and argv[0] == "--out":
            out = Path(argv[1])
            argv = argv[2:]
        else:
            print(__doc__, file=sys.stderr)
            return 2
    if lines is None:
        print(__doc__, file=sys.stderr)
        return 2
    found = blocks(lines)
    if not found:
        print("goldens: the log prints no golden, so every golden it ran matched")
        return 0
    out.mkdir(parents=True, exist_ok=True)
    for name in sorted(found):
        target = out / name
        same = target.exists() and target.read_bytes() == found[name]
        if not same:
            target.write_bytes(found[name])
        shown = target.relative_to(ROOT) if target.is_relative_to(ROOT) else target
        print(f"goldens: {shown.as_posix()} {'unchanged' if same else 'written'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
