#!/usr/bin/env bash
#
# Several parts of one ship's art-lint side by side on one machine, an engine each:
# what a CI job runs, so a runner's cores all work and the run asks for fewer jobs
# than GitHub runs at once (.github/workflows/verify.yml).
#
# Usage:  tools/art_lint_parts.sh SHIP N K [K…]
#
# Runs `make art-lint SHIP=SHIP PART=K/N COSTS=art-lint-costs-SHIP-K.tsv` for each K
# given, all at once, with a test engine slot for each (TEST_SLOTS). Their output
# comes as they write it, each line prefixed with its part once there are several;
# every part runs to its end, and one that fails fails the run.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if (($# < 3)); then
	echo "art-lint-parts: usage: tools/art_lint_parts.sh SHIP N K [K…]" >&2
	exit 2
fi
ship="$1"
of="$2"
shift 2

export TEST_SLOTS="${TEST_SLOTS:-$#}"

pids=()
for part; do
	if (($# == 1)); then
		make art-lint SHIP="$ship" PART="$part/$of" COSTS="art-lint-costs-$ship-$part.tsv" &
	else
		make art-lint SHIP="$ship" PART="$part/$of" COSTS="art-lint-costs-$ship-$part.tsv" 2>&1 |
			sed "s|^|[$part/$of] |" &
	fi
	pids+=("$!")
done

failed=0
for pid in "${pids[@]}"; do
	wait "$pid" || failed=1
done
exit "$failed"
