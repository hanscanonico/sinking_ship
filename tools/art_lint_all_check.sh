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
echo "checked \$*"
[[ "\$*" == *"\${FAIL_ON:-none}"* ]] && exit 1
exit 0
EOF
chmod +x "$WORK/bin/make"

# With TEST_SLOTS=$1 and the arguments $2, the script must run the make lines $3
# (';' between them, sorted) and exit $4.
expect() {
	: >"$WORK/made"
	# $2 unquoted: none is no argument at all.
	# shellcheck disable=SC2086
	said=$(PATH="$WORK/bin:$PATH" TEST_SLOTS="$1" "$here/art_lint_all.sh" $2 2>&1)
	status=$?
	made=$(sed 's/^--no-print-directory art-lint //' "$WORK/made" | LC_ALL=C sort | paste -sd';' -)
	[[ "$made" == "$3" ]] || fail "slots $1, '$2': ran '$made', not '$3': $said"
	[[ "$status" == "$4" ]] || fail "slots $1, '$2': exited $status, not $4: $said"
}

rest='MATCH=1/2;MATCH=2/2'
ships='SKIP=titanic,small_titanic MATCH=no'
small2='SHIP=small_titanic PART=1/2;SHIP=small_titanic PART=2/2'
small3='SHIP=small_titanic PART=1/3;SHIP=small_titanic PART=2/3;SHIP=small_titanic PART=3/3'
titanic2='SHIP=titanic PART=1/2;SHIP=titanic PART=2/2'
titanic4='SHIP=titanic PART=1/4;SHIP=titanic PART=2/4;SHIP=titanic PART=3/4;SHIP=titanic PART=4/4'
titanic6="SHIP=titanic PART=1/6;SHIP=titanic PART=2/6;SHIP=titanic PART=3/6;SHIP=titanic PART=4/6"
titanic6+=";SHIP=titanic PART=5/6;SHIP=titanic PART=6/6"

expect 10 '' "$rest;$small3;$titanic6;$ships" 0
grep -q '^\[titanic 6/6\] checked ' <<<"$said" || fail "an engine's lines do not carry its name: $said"
grep -q 'every part OK (12 engines)' <<<"$said" || fail "a green run does not end on its count: $said"
expect 1 '' "$rest;$small2;$titanic2;$ships" 0
expect 4 titanic "$titanic4" 0
expect 40 small_titanic 'SHIP=small_titanic PART=1/4;SHIP=small_titanic PART=2/4;SHIP=small_titanic PART=3/4;SHIP=small_titanic PART=4/4' 0
expect 1 titanic 'SHIP=titanic PART=1/1' 0
expect 10 tug 'SHIP=tug PART=1/1' 0

FAIL_ON='PART=2/2' expect 1 '' "$rest;$small2;$titanic2;$ships" 1
grep -q 'FAILED in titanic 2/2, small_titanic 2/2$' <<<"$said" || fail "a red run does not name its engines: $said"

said=$(TEST_SLOTS=none "$here/art_lint_all.sh" 2>&1)
[[ $? == 2 ]] || fail "a TEST_SLOTS that is no count was taken: $said"

((fails == 0)) && echo "art-lint-all-check: ok"
exit "$fails"
