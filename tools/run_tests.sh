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
#         tools/run_tests.sh -gselect=test_water_level.gd
#         tools/run_tests.sh -gselect=test_water_level.gd -gunit_test_name=maximum
#
# Any argument is handed to GUT verbatim, and the count check is skipped.
# Narrow with -gselect (a filename substring), not -gtest: -gtest adds a script
# on top of the config's directory scan instead of replacing it.

set -uo pipefail

# Sourced before the cd: $0 may be a relative path, and it is the caller's
# working directory that makes it resolve.
source "$(dirname "$0")/lib/require_godot.sh" || exit 1

cd "$(dirname "$0")/.." || exit 1

TEST_DIR="tests/unit"

require_godot test

if (($#)); then
	exec "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd "$@"
fi

on_disk="$(find "$TEST_DIR" -name 'test_*.gd' 2>/dev/null | wc -l | tr -d ' ')"
if ((on_disk == 0)); then
	echo "test: no test scripts under $TEST_DIR" >&2
	exit 1
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd 2>&1 | tee "$LOG"
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

if ((ran != on_disk)); then
	echo "test: ran $ran scripts, but $TEST_DIR holds $on_disk" >&2
	exit 1
fi

echo "test: all tests passed"
