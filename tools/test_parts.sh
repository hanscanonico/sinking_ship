#!/usr/bin/env bash
#
# Several shards of the suite side by side on one machine, an engine each: what a CI
# test job runs, so a runner's cores all work (.github/workflows/verify.yml). In one
# engine a runner's shard left three of its four cores idle.
#
# Usage:  tools/test_parts.sh N K [K…]
#
# Runs `make test SHARD=K/N` for each K given, all at once, with a test engine slot
# for each (TEST_SLOTS). Their output comes as they write it, line by line, each
# line prefixed with its shard ("[K/N] ") once there are several: make durations
# and make goldens read a job's log by that prefix, a shard at a time
# (tools/test_durations.py, tools/goldens.py), and the first times each script by
# the stamps its lines were logged at. Every shard runs to its end, and one that
# fails fails the run.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if (($# < 2)); then
	echo "test-parts: usage: tools/test_parts.sh N K [K…]" >&2
	exit 2
fi
of="$1"
shift

export TEST_SLOTS="${TEST_SLOTS:-$#}"

pids=()
for part; do
	if (($# == 1)); then
		make test SHARD="$part/$of" &
	else
		# Unbuffered: a line held back in a pipe would be stamped late.
		make test SHARD="$part/$of" 2>&1 | sed -u "s|^|[$part/$of] |" &
	fi
	pids+=("$!")
done

failed=0
for pid in "${pids[@]}"; do
	wait "$pid" || failed=1
done
exit "$failed"
