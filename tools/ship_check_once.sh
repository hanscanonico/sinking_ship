#!/usr/bin/env bash
#
# `make guard-check`, its sixth part: `make verify` runs the float test
# (tests/unit/core/test_ship_check.gd) once, inside test's directory scan, and
# never again by name — verify holds the ships to their generators with
# ship-gen-check, not ship-check. `make verify-changed` names it no more: its
# test-changed picks the scripts at run time, so it runs the float test once
# when the change reaches it. `make ship-check` alone still names it, once.
# Read off `make -n`, so no engine runs.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fails=0
# How many times the dry run of the target given names the float test; a dry
# run that fails prints nothing, so a broken Makefile cannot pass for a clean one.
named() {
	local plan
	plan=$(make -n "$1" GODOT=godot TEST=) || {
		echo "ship-check-once: make -n $1 fails" >&2
		echo x
		return
	}
	grep -c -- '-gselect=test_ship_check.gd' <<<"$plan"
}

count=$(named verify)
[ "$count" = 0 ] || {
	echo "ship-check-once: make verify names test_ship_check.gd $count times, not 0 — the suite already runs it" >&2
	fails=1
}
count=$(named verify-changed)
[ "$count" = 0 ] || {
	echo "ship-check-once: make verify-changed names test_ship_check.gd $count times, not 0 — test-changed already runs it when reached" >&2
	fails=1
}
count=$(named ship-check)
[ "$count" = 1 ] || {
	echo "ship-check-once: make ship-check names test_ship_check.gd $count times, not 1" >&2
	fails=1
}
exit "$fails"
