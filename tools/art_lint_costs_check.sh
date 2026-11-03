#!/usr/bin/env bash
#
# `make guard-check`: tools/art_lint_costs.py writes tools/art_lint_costs.tsv from a
# run's art-lint-costs-* tables as make art-lint-costs does. Against two runs made
# up here, each of two parts' tables (gh run download's layout, a folder per
# artifact): a check one part timed twice adds up, what every part pays whatever it
# is dealt (her build, her faces, the open spans) drops out, a cheap check is weighed by its kind's cheap ones, and across the runs each
# check weighs the longest either gave it.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "art-lint-costs-check: $1" >&2
	fails=1
}

mkdir -p "$WORK/one/art-lint-costs-titanic-1" "$WORK/one/art-lint-costs-titanic-2" "$WORK/two/art-lint-costs-titanic-1"
printf 'titanic\tbuild\t0\t300000000\ntitanic\tblocker\t2\t149500\ntitanic\tblocker\t10\t300\ntitanic\tstretch\t-3\t4000000\ntitanic\tblocker\t2\t500\n' \
	>"$WORK/one/art-lint-costs-titanic-1/art-lint-costs.tsv"
printf 'titanic\tfaces\t0\t9000000\ntitanic\tspans\t0\t200000000\ntitanic\thull\t0\t72049\ntitanic\tfloor\t7\t12\ntitanic\tfloor\t9\t388\n' \
	>"$WORK/one/art-lint-costs-titanic-2/art-lint-costs.tsv"
printf 'titanic\tblocker\t10\t900\ntitanic\tfloor\t7\t5\n' >"$WORK/two/art-lint-costs-titanic-1/art-lint-costs.tsv"

# Checks of CHEAP (100 ms) or more one by one, then per kind what its cheaper ones
# cost each, as "*".
expected="titanic	blocker	2	150.0
titanic	blocker	*	0.3
titanic	floor	*	0.2
titanic	hull	*	72.0
titanic	stretch	-3	4000.0"
got="$(tools/art_lint_costs.py --costs "$WORK/one" --run 41554654682 --out - | grep -v '^#')"
[[ "$got" == "$expected" ]] || fail "one run read as:
$got"

tools/art_lint_costs.py --costs "$WORK/one" --costs "$WORK/two" --run 1 --run 2 --out "$WORK/two.tsv" 2>/dev/null ||
	fail "reading two runs failed"
got="$(grep -v '^#' "$WORK/two.tsv")"
[[ "$got" == "$(sed 's/blocker\t\*\t0.3$/blocker\t*\t0.9/' <<<"$expected")" ]] || fail "two runs read as:
$got"
grep -q 'make art-lint-costs RUN="1 2"' "$WORK/two.tsv" || fail "the header does not say how to write the file again"

if tools/art_lint_costs.py --costs "$WORK/empty" --out - >/dev/null 2>&1; then
	fail "a run with no tables wrote a file"
fi

if ((fails)); then
	exit 1
fi
echo "art-lint-costs-check: ok"
