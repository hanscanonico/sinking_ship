#!/usr/bin/env python3
"""Write tools/art_lint_costs.tsv from CI verify runs: `make art-lint-costs RUN="ID …"`.

Each of the Titanic's art-lint parts (`make art-lint SHIP=titanic PART=K/N
COSTS=FILE`) appends, per check it makes, "ship\tkind\tindex\tmicroseconds" to
FILE, and CI keeps each part's FILE as an artifact named art-lint-costs-*. The
parts between them make every check once, so one run's artifacts time them all.
tools/art_lint.gd deals her checks among the parts by this table's milliseconds
(tools/art_lint_costs.gd), the dearest first to the part with the least so far.

Only the checks a part is dealt are written: what each part pays whatever it is
dealt — her build, her faces filed, the false-floor faces, the open spans' own
build and check — is the same in every part, and no deal moves it. Given several
runs, each check weighs the longest any of them timed it, as make durations
weighs a test script.

Usage:  tools/art_lint_costs.py --run ID [--run ID …]   # fetch each run's artifacts with gh, write the file
        tools/art_lint_costs.py --costs DIR [--costs DIR …] [--run ID …]
                                                     # read saved runs instead, each DIR one run's
                                                     # tables (as gh run download writes them); the
                                                     # runs, if given, only name them in the header
        ... [--out FILE]                             # write FILE instead (- for stdout)
"""

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = ROOT / "tools" / "art_lint_costs.tsv"
# What every part pays whatever it is dealt (tools/art_lint.gd's _costs.timed).
OVERHEAD = {"build", "faces", "furnished", "shown", "spans"}
# A check under CHEAP milliseconds is not listed: its kind's "*" row, what its cheap
# ones cost each, weighs it. The Titanic's 13,200 checks timed one by one were a
# 332 KB table; the some 460 of 100 ms or more hold 80% of her dealt time.
CHEAP = 100.0


def parse(lines) -> dict[tuple[str, str, int], float]:
    """Each dealt check's milliseconds, by (ship, kind, index)."""
    costs: dict[tuple[str, str, int], float] = {}
    for line in lines:
        fields = line.strip().split("\t")
        if len(fields) != 4 or fields[1] in OVERHEAD:
            continue
        ship, kind, index, micro = fields
        key = (ship, kind, int(index))
        costs[key] = costs.get(key, 0.0) + int(micro) / 1000.0
    return costs


def tables(folder: Path) -> list[str]:
    """The lines of every .tsv under [folder], one run's parts: their checks add up."""
    return [line for table in sorted(folder.rglob("*.tsv")) for line in table.read_text(encoding="utf-8").splitlines()]


def fetch(run: str) -> list[str]:
    """Every art-lint-costs-* artifact's lines of verify run [run]."""
    with tempfile.TemporaryDirectory() as work:
        result = subprocess.run(
            ["gh", "run", "download", run, "--pattern", "art-lint-costs-*", "--dir", work],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode != 0:
            sys.exit(f"art_lint_costs: gh run download {run} failed: {result.stderr.strip()}")
        lines = tables(Path(work))
        if not lines:
            sys.exit(f"art_lint_costs: run {run} kept no art-lint-costs-* artifact")
        return lines


def render(costs: dict[tuple[str, str, int], float], runs: list[str]) -> str:
    if len(runs) > 1:
        source = f"verify runs {', '.join(runs)}, each check's longest"
        command = f'make art-lint-costs RUN="{" ".join(runs)}"'
    elif runs:
        source = f"verify run {runs[0]}"
        command = f"make art-lint-costs RUN={runs[0]}"
    else:
        source = "saved runs"
        command = "tools/art_lint_costs.py"
    lines = [
        f"# Milliseconds each of art-lint's dealt ship checks took on a hosted CI runner ({source}), written by `{command}`.",
        f"# ship, kind, index, milliseconds; tools/art_lint.gd deals a ship's parts (--part) by them. A check under {CHEAP:.0f} ms is not listed: its kind's * row is what each of those cost.",
        "# Regenerate the file when her parts drift apart.",
    ]
    cheap: dict[tuple[str, str], list[float]] = {}
    rows = []
    for (ship, kind, index), took in costs.items():
        if took < CHEAP:
            cheap.setdefault((ship, kind), []).append(took)
        else:
            rows.append(((ship, kind, 0, index), str(index), took))
    for (ship, kind), took in cheap.items():
        rows.append(((ship, kind, 1, 0), "*", sum(took) / len(took)))
    for (ship, kind, _, _), index, took in sorted(rows):
        lines.append(f"{ship}\t{kind}\t{index}\t{took:.1f}")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    runs: list[str] = []
    folders: list[str] = []
    out = str(TABLE)
    while argv:
        if len(argv) < 2 or argv[0] not in ("--run", "--costs", "--out"):
            print(__doc__, file=sys.stderr)
            return 2
        flag, value = argv[0], argv[1]
        argv = argv[2:]
        if flag == "--run":
            if not value.isdigit():
                sys.exit(f"art_lint_costs: {value} is not a run id")
            runs.append(value)
        elif flag == "--costs":
            folders.append(value)
        else:
            out = value
    if folders:
        sources = [tables(Path(folder)) for folder in folders]
    elif runs:
        sources = [fetch(run) for run in runs]
    else:
        print(__doc__, file=sys.stderr)
        return 2
    costs: dict[tuple[str, str, int], float] = {}
    for lines in sources:
        for key, took in parse(lines).items():
            costs[key] = max(costs.get(key, 0.0), took)
    if not costs:
        sys.exit("art_lint_costs: the tables time no dealt check")
    text = render(costs, runs)
    # LF whatever the platform, as tools/test_durations.py writes.
    if out == "-":
        sys.stdout.reconfigure(newline="\n")
        sys.stdout.write(text)
    else:
        Path(out).write_text(text, encoding="utf-8", newline="\n")
        print(f"art_lint_costs: {len(costs)} checks to {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
