#!/usr/bin/env python3
"""Which test scripts shard K of N runs: `tools/run_tests.sh --shard K/N`.

Every tests/unit/**/test_*.gd lands in exactly one shard. Scripts are weighed by
tests/durations.tsv (seconds on a hosted runner) and dealt longest first to the
lightest shard, so the shards finish close together. A script the file does not
list yet weighs DEFAULT_SECONDS: it still runs, the split is just a little less
even until the file is refreshed.

Usage:  tools/test_shards.py K N         # res:// paths of shard K (1-based), one per line
        tools/test_shards.py --plan N    # every shard's estimated seconds and scripts
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


def plan(count: int) -> list[tuple[float, list[str]]]:
    weights = durations()
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
    if len(argv) == 2 and argv[0] == "--plan":
        for i, (total, members) in enumerate(plan(int(argv[1])), 1):
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
    for script in plan(count)[index - 1][1]:
        print(f"res://{script}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
