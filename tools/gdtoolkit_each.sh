#!/usr/bin/env bash
#
# `make lint`, `make format-check` and `make format`: one gdtoolkit command over
# every .gd file that is ours, NPROC workers of 60 files each, fed NUL-delimited.
#
# Usage:  tools/gdtoolkit_each.sh gdlint
#         tools/gdtoolkit_each.sh gdformat --check
#         tools/gdtoolkit_each.sh --list      # the files, NUL-delimited, and nothing run
#
# A script, not a make recipe: under GNU make on Windows the recipe's
# `printf … | xargs` fan-out never ran, so lint and format-check checked their
# warm-up file alone and passed. Here the list goes from find to xargs through a
# file, the same on every platform.
#
# Every .gd file that is actually ours: skips the engine cache, vendored addons,
# the engine binary, and .claude/worktrees, which holds whole nested checkouts of
# this same repo and would otherwise be linted as if it were project source.
#
# The first file goes alone, before the fan-out, and its failure fails the run:
# gdtoolkit builds its parser cache directory (~/.cache/gdtoolkit on Linux,
# ~/Library/Caches/gdtoolkit on macOS) with a check-then-makedirs, so on a fresh
# machine — every CI runner — parallel workers race to create it and the losers
# report "Cannot open file '…': File exists" as a problem. The warm-up creates the
# directory and its parser pickles first; do not remove it.
#
# xargs exits 123 when any one invocation fails, so a problem in a single chunk
# still fails the run. Workers' output interleaves; each chunk also prints its own
# summary line. tools/lint_warmup_check.sh holds all of this, against a stand-in tool.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if (($# == 0)); then
	echo "gdtoolkit-each: name the tool and its flags, e.g. gdlint or gdformat --check" >&2
	exit 2
fi

sources() {
	find . -name '*.gd' \
		-not -path './.godot/*' \
		-not -path './addons/*' \
		-not -path './bin/*' \
		-not -path './.claude/*' \
		-print0 |
		LC_ALL=C sort -z
}

if [[ "$1" == "--list" ]]; then
	sources
	exit 0
fi

NPROC="${NPROC:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

first=""
while IFS= read -r -d '' file; do
	if [[ -z "$first" ]]; then
		first="$file"
	else
		printf '%s\0' "$file"
	fi
done < <(sources) >"$WORK/rest"

if [[ -z "$first" ]]; then
	echo "gdtoolkit-each: no .gd files found" >&2
	exit 1
fi

"$@" "$first" </dev/null || exit 1
[[ -s "$WORK/rest" ]] || exit 0
xargs -0 -P "$NPROC" -n 60 "$@" <"$WORK/rest"
