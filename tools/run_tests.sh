#!/usr/bin/env bash
#
# `make test`: the GUT suite, headless, in one engine.
#
# GUT's exit status says whether a test failed. What it cannot say is that a
# script on disk never ran — a file GUT could not load drops out of the run
# quietly — so a full run also holds the "Scripts" count of GUT's summary to the
# test_*.gd files under tests/unit.
#
# Usage:  tools/run_tests.sh                    # the whole suite (.gutconfig.json)
#         tools/run_tests.sh -gselect=test_sink_schedule.gd
#         tools/run_tests.sh -gselect=test_sink_schedule.gd -gunit_test_name=timeline
#         tools/run_tests.sh --shard 2/8        # one CI shard (tools/test_shards.py)
#         tools/run_tests.sh --jobs 4           # every shard of 4, side by side
#
# A shard runs only its share of the scripts and holds the count to that share;
# the shards of one N together run every script once. Any other argument is
# handed to GUT verbatim, and the count check is skipped.
# Narrow with -gselect (a filename substring), not -gtest: -gtest adds a script
# on top of the config's directory scan instead of replacing it.

set -uo pipefail

# Sourced before the cd: $0 may be a relative path, and it is the caller's
# working directory that makes it resolve.
source "$(dirname "$0")/lib/require_godot.sh" || exit 1

cd "$(dirname "$0")/.." || exit 1

TEST_DIR="tests/unit"

# Tests provoke engine errors on purpose (push_error under assert_push_error), and GUT
# already fails a test on one it did not expect — so of the engine's output the suite is
# held to a script that failed to run, not to every ERROR: line.
export ENGINE_GUARD_PATTERN='SCRIPT ERROR:|Parse Error:'

require_godot test

# Every shard of N at once, one engine each, their output held in a log apiece
# and shown for a shard that fails: the whole suite in a fraction of the time on
# a machine with the cores. Each shard holds its own count, so together they
# still prove every script ran.
if [[ "${1:-}" == "--jobs" ]]; then
	if [[ ! "${2:-}" =~ ^[1-9][0-9]*$ ]]; then
		echo "test: --jobs takes a count, e.g. --jobs 4" >&2
		exit 1
	fi
	jobs="$2"
	logs="$(mktemp -d)"
	echo "test: $jobs shards side by side, logs in $logs"
	pids=()
	for ((k = 1; k <= jobs; k++)); do
		"$0" --shard "$k/$jobs" >"$logs/shard_$k.log" 2>&1 &
		pids+=("$!")
	done
	failed=0
	for ((k = 1; k <= jobs; k++)); do
		if wait "${pids[k - 1]}"; then
			echo "test: shard $k/$jobs passed"
		else
			echo "test: shard $k/$jobs FAILED — $logs/shard_$k.log" >&2
			sed $'s/\033\[[0-9;]*m//g' "$logs/shard_$k.log" | tail -60 >&2
			failed=1
		fi
	done
	if ((failed)); then
		exit 1
	fi
	rm -rf "$logs"
	echo "test: all tests passed"
	exit 0
fi

gut_args=()
expected=""
if [[ "${1:-}" == "--shard" ]]; then
	if [[ ! "${2:-}" =~ ^([0-9]+)/([0-9]+)$ ]]; then
		echo "test: --shard takes K/N, e.g. --shard 2/8" >&2
		exit 1
	fi
	shard="$(tools/test_shards.py "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")" || exit 1
	if [[ -z "$shard" ]]; then
		echo "test: shard $2 holds no scripts" >&2
		exit 1
	fi
	expected="$(printf '%s\n' "$shard" | wc -l | tr -d ' ')"
	# No config file: its directory scan would add every script back.
	gut_args=(-gconfig= -gexit -glog=1 "-gtest=$(printf '%s' "$shard" | paste -sd, -)")
	echo "test: shard $2 runs $expected scripts"
elif (($#)); then
	exec tools/engine_guard.sh "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd "$@"
fi

if [[ -z "$expected" ]]; then
	expected="$(find "$TEST_DIR" -name 'test_*.gd' 2>/dev/null | wc -l | tr -d ' ')"
	if ((expected == 0)); then
		echo "test: no test scripts under $TEST_DIR" >&2
		exit 1
	fi
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

tools/engine_guard.sh "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd ${gut_args[@]+"${gut_args[@]}"} 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

# GUT's "Scripts" summary line, with the colour escapes it paints it with cut off.
ran="$(
	sed $'s/\033\[[0-9;]*m//g' "$LOG" |
		awk '
			/^Scripts  / {
				value = $NF
				sub(/^.*\//, "", value)
				print value + 0
				found = 1
				exit
			}
			END { if (!found) print 0 }
		'
)"

if ((status != 0)); then
	echo "test: GUT exited $status" >&2
	exit 1
fi

if ((ran != expected)); then
	echo "test: ran $ran scripts, but expected $expected" >&2
	exit 1
fi

echo "test: all tests passed"
