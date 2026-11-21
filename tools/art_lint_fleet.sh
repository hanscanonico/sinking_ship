#!/usr/bin/env bash
#
# The fleet's art-lint side by side on one machine: her ships in one engine and what
# plays a match dealt over N more — what CI's art-lint fleet job runs
# (.github/workflows/verify.yml). In one engine the match's checks waited behind the
# ships and took four fifths of the job (run 44900242066).
#
# Usage:  tools/art_lint_fleet.sh SKIP N
#
# Runs `make art-lint SKIP=SKIP MATCH=no` and `make art-lint MATCH=K/N` for K from 1
# to N, all at once, with a test engine slot for each (TEST_SLOTS). Their output
# comes as they write it, each line prefixed with what it checks; every engine runs
# to its end, and one that fails fails the run.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if (($# != 2)) || [[ ! "$2" =~ ^[1-9][0-9]*$ ]]; then
	echo "art-lint-fleet: usage: tools/art_lint_fleet.sh SKIP N" >&2
	exit 2
fi
skip="$1"
of="$2"

export TEST_SLOTS="${TEST_SLOTS:-$((of + 1))}"

pids=()
make art-lint SKIP="$skip" MATCH=no 2>&1 | sed "s|^|[ships] |" &
pids+=("$!")
for ((k = 1; k <= of; k++)); do
	make art-lint MATCH="$k/$of" 2>&1 | sed "s|^|[match $k/$of] |" &
	pids+=("$!")
done

failed=0
for pid in "${pids[@]}"; do
	wait "$pid" || failed=1
done
exit "$failed"
