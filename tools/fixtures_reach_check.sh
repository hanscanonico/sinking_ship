#!/usr/bin/env bash
#
# `make guard-check`: the sim tests' shared fixtures (tests/unit/sim_fixtures.gd) reach
# nothing under scenes/. Nearly every sim test uses them, so one scene class named
# there makes each of those tests count as reaching the scenes, and `make test-changed`
# then runs them all on every change to the art: one call of ShipPieces did, and a
# change to scenes/art selected 284 of the suite's 387 scripts where 143 reach it.
#
# Asked of the selector itself (tools/test_changed.py), with every script and scene
# under scenes/ given as changed: tests/unit/core/test_ticks.gd, a sim test that reaches
# the scenes through the fixtures or not at all, must not be selected. No engine runs.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

canary=tests/unit/core/test_ticks.gd
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if ! grep -q SimFixtures "$canary"; then
	echo "fixtures-reach-check: $canary no longer uses SimFixtures — name another sim test here" >&2
	exit 1
fi
git ls-files -z -- 'scenes/*.gd' 'scenes/*.tscn' |
	xargs -0 tools/test_changed.py --list "$WORK/list" --changed >"$WORK/report" 2>&1 || {
	cat "$WORK/report" >&2
	echo "fixtures-reach-check: tools/test_changed.py failed" >&2
	exit 1
}
if [[ "$(cat "$WORK/list")" == ALL ]]; then
	cat "$WORK/report" >&2
	echo "fixtures-reach-check: a change to scenes/ selects the whole suite" >&2
	exit 1
fi
if grep -qx "$canary" "$WORK/list"; then
	echo "fixtures-reach-check: $canary reaches scenes/, by this chain — keep scene classes out of what the sim tests share:" >&2
	awk -v canary="$canary" '
		$1 == canary { on = 1; print; next }
		on && $1 == "->" { print; next }
		{ on = 0 }
	' "$WORK/report" >&2
	exit 1
fi
echo "fixtures-reach-check: ok"
