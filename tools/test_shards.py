#!/usr/bin/env python3
"""Which test scripts shard K of N runs: `tools/run_tests.sh --shard K/N`.

Every tests/unit/**/test_*.gd lands in exactly one shard. Scripts are weighed by
tests/durations.tsv (seconds on a hosted runner, written from a CI verify run's
logs by `make durations RUN=ID`, tools/test_durations.py) and dealt longest first
to the lightest shard, so the shards finish close together. A script the file does
not list yet weighs DEFAULT_SECONDS: it still runs, the split is just a little less
even until the file is written again.

With --from LIST the scripts are LIST's, one per line, instead of every one under
tests/unit: `tools/run_tests.sh --list` deals a chosen few the same way. A line
may be spelled res://; blank lines and repeats drop out, and a line that does not
name a tests/unit/**/test_*.gd on disk is refused, so the count a run is held to is
the scripts it can run.

Usage:  tools/test_shards.py [--from LIST] K N       # res:// paths of shard K (1-based), one per line
        tools/test_shards.py [--from LIST] --plan N  # every shard's estimated seconds and scripts
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEST_DIR = ROOT / "tests" / "unit"
DURATIONS = ROOT / "tests" / "durations.tsv"
DEFAULT_SECONDS = 10


def durations() -> dict[str, float]:
    weights = {}
    if DURATIONS.exists():
        for line in DURATIONS.read_text().splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            path, seconds = line.split("\t")
            weights[path] = float(seconds)
    return weights


def read_list(path: Path) -> list[str]:
    """LIST's scripts, repo-relative, each once; a line naming no test script exits."""
    scripts = set()
    for line in path.read_text().splitlines():
        script = line.strip().removeprefix("res://")
        if not script:
            continue
        name = Path(script)
        if (
            not script.startswith("tests/unit/")
            or not name.name.startswith("test_")
            or name.suffix != ".gd"
            or ".." in name.parts
        ):
            sys.exit(f"test_shards: {script} is not a tests/unit test_*.gd script")
        if not (ROOT / script).is_file():
            sys.exit(f"test_shards: {script} is not there")
        scripts.add(script)
    return sorted(scripts)


def plan(count: int, scripts: list[str] | None = None) -> list[tuple[float, list[str]]]:
    weights = durations()
    if scripts is None:
        scripts = sorted(
            p.relative_to(ROOT).as_posix() for p in TEST_DIR.rglob("test_*.gd")
        )
    # Longest first, ties by path, so every shard computes the same split.
    scripts.sort(key=lambda s: (-weights.get(s, DEFAULT_SECONDS), s))
    shards: list[tuple[float, list[str]]] = [(0.0, []) for _ in range(count)]
    for script in scripts:
        i = min(range(count), key=lambda j: (shards[j][0], len(shards[j][1]), j))
        total, members = shards[i]
        shards[i] = (total + weights.get(script, DEFAULT_SECONDS), members + [script])
    return shards


def main(argv: list[str]) -> int:
    scripts = None
    if len(argv) >= 2 and argv[0] == "--from":
        scripts = read_list(Path(argv[1]))
        argv = argv[2:]
    if len(argv) == 2 and argv[0] == "--plan":
        for i, (total, members) in enumerate(plan(int(argv[1]), scripts), 1):
            print(f"shard {i}: {total / 60:5.1f} min, {len(members)} scripts")
            for script in members:
                print(f"    {script}")
        return 0
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    index, count = int(argv[0]), int(argv[1])
    if not 1 <= index <= count:
        print(f"test_shards: shard {index} is not in 1..{count}", file=sys.stderr)
        return 2
    for script in plan(count, scripts)[index - 1][1]:
        print(f"res://{script}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
