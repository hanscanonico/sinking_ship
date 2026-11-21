#!/usr/bin/env bash
#
# `make guard-check`: tools/art_lint_all.sh deals the lint over engines — the whole
# lint as each Titanic's parts, the match's two shares and the fleet's other ships; a
# ship alone as her parts, or one engine when she is no Titanic — with as many parts
# as the test slots are worth, and fails, naming the engine, when one fails. Against a
# stand-in make.

set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "art-lint-all-check: $1" >&2
	fails=1
}

mkdir "$WORK/bin"
cat >"$WORK/bin/make" <<EOF
#!/usr/bin/env bash
echo "\$*" >>'$WORK/made'
echo "\$TEST_SLOTS" >>'$WORK/slots'
echo "checked \$*"
[[ "\$*" == *"\${FAIL_ON:-none}"* ]] && exit 1
exit 0
EOF
chmod +x "$WORK/bin/make"

# Memory for any number of engines, until a case says otherwise.
echo 999999 >"$WORK/free"

# With TEST_SLOTS=$1 and the arguments $2, the script must run the make lines $3
# (';' between them, sorted) and exit $4.
expect() {
	: >"$WORK/made"
	# $2 unquoted: none is no argument at all.
	# shellcheck disable=SC2086
	said=$(PATH="$WORK/bin:$PATH" TEST_SLOTS="$1" FREE_MEMORY_FILE="$WORK/free" \
		TEST_SLOT_MIN_FREE_MB=1000 ART_LINT_ENGINE_MB=3000 "$here/art_lint_all.sh" $2 2>&1)
	status=$?
	made=$(sed 's/^--no-print-directory art-lint //' "$WORK/made" | LC_ALL=C sort | paste -sd';' -)
	[[ "$made" == "$3" ]] || fail "slots $1, '$2': ran '$made', not '$3': $said"
	[[ "$status" == "$4" ]] || fail "slots $1, '$2': exited $status, not $4: $said"
}

# Ship $1's $2 parts, as the sorted make lines.
parts() {
	local k out=""
	for ((k = 1; k <= $2; k++)); do
		out+="${out:+;}SHIP=$1 PART=$k/$2"
	done
	echo "$out"
}
rest='MATCH=1/2;MATCH=2/2'
ships='SKIP=titanic,small_titanic MATCH=no'

expect 10 '' "$rest;$(parts small_titanic 3);$(parts titanic 8);$ships" 0
grep -q '^\[titanic 8/8\] checked ' <<<"$said" || fail "an engine's lines do not carry its name: $said"
grep -q 'every part OK (14 engines)' <<<"$said" || fail "a green run does not end on its count: $said"
expect 4 '' "$rest;$(parts small_titanic 2);$(parts titanic 3);$ships" 0
expect 1 '' "$rest;$(parts small_titanic 2);$(parts titanic 2);$ships" 0
expect 4 titanic "$(parts titanic 5)" 0
expect 40 titanic "$(parts titanic 16 | tr ';' '\n' | LC_ALL=C sort | paste -sd';' -)" 0
expect 40 small_titanic "$(parts small_titanic 4)" 0
expect 1 titanic 'SHIP=titanic PART=1/1' 0
expect 10 tug 'SHIP=tug PART=1/1' 0

FAIL_ON='PART=2/2' expect 1 '' "$rest;$(parts small_titanic 2);$(parts titanic 2);$ships" 1
grep -q 'FAILED in titanic 2/2, small_titanic 2/2$' <<<"$said" || fail "a red run does not name its engines: $said"

# No more engines than there is memory for over the slots' floor, and the engines keep
# to that many slots: 10 000 MB free is three of 3 000 over a floor of 1 000.
echo 10000 >"$WORK/free"
: >"$WORK/slots"
expect 10 '' "$rest;$(parts small_titanic 2);$(parts titanic 2);$ships" 0
grep -q '^art-lint: 3 engines at once, not 10: 10000 MB free' <<<"$said" || fail "a run cut for memory does not say so: $said"
[[ "$(sort -u "$WORK/slots")" == 3 ]] || fail "the engines were not held to 3 slots: $(sort -u "$WORK/slots" | paste -sd' ' -)"
expect 10 titanic "$(parts titanic 4)" 0
echo 500 >"$WORK/free"
expect 10 titanic 'SHIP=titanic PART=1/1' 0
echo 999999 >"$WORK/free"

said=$(TEST_SLOTS=none "$here/art_lint_all.sh" 2>&1)
[[ $? == 2 ]] || fail "a TEST_SLOTS that is no count was taken: $said"

((fails == 0)) && echo "art-lint-all-check: ok"
exit "$fails"
