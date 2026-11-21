#!/usr/bin/env bash
#
# `make guard-check`: tools/gate_changed.sh runs the whole guard-check or ship-gen-check
# when a branch's changes reach what the step reads (committed or not), and otherwise
# none, saying so — still checking the runtime load sites in guard-check's place — and
# hands on the step's failure, against a throwaway repo, a stand-in make and a stand-in
# tools/test_changed.py.

set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "gate-changed-check: $1" >&2
	fails=1
}

repo="$WORK/repo"
mkdir -p "$repo/tools" "$repo/data/ships" "$repo/data/rules" "$repo/core" "$repo/tests/golden" \
	"$repo/tests/fixtures/ships" "$repo/tests/unit" "$repo/docs"
cp "$here/gate_changed.sh" "$repo/tools/"
cat >"$repo/tools/test_changed.py" <<EOF
#!/usr/bin/env bash
echo "sites \$*" >>'$WORK/made'
exit "\${FAIL_SITES:-0}"
EOF
chmod +x "$repo/tools/test_changed.py"
echo tug >"$repo/data/ships/tug.tres"
echo rules >"$repo/data/rules/brawl.tres"
echo gen >"$repo/tools/gen_tug.py"
echo sim >"$repo/core/movement.gd"
echo golden >"$repo/tests/golden/match.txt"
echo hull >"$repo/tests/fixtures/ships/tug_weak.tres"
echo test >"$repo/tests/unit/test_ticks.gd"
echo notes >"$repo/docs/notes.md"
echo make >"$repo/Makefile"
git -C "$repo" init -q
git -C "$repo" config user.name check
git -C "$repo" config user.email check@example.com
git -C "$repo" config core.autocrlf false
git -C "$repo" add -A
git -C "$repo" commit -qm base
git -C "$repo" branch -M main
git -C "$repo" update-ref refs/remotes/origin/main main

mkdir "$WORK/bin"
cat >"$WORK/bin/make" <<EOF
#!/usr/bin/env bash
echo "\$*" >>'$WORK/made'
exit "\${FAIL_MAKE:-0}"
EOF
chmod +x "$WORK/bin/make"

# A branch named $1 off main, changed by the shell commands $2: step $3 must run the
# lines $4 (';' between them, empty for none) and exit $5.
expect() {
	git -C "$repo" checkout -q -B "$1" main
	git -C "$repo" reset -q --hard main
	git -C "$repo" clean -qfd
	(cd "$repo" && eval "$2")
	: >"$WORK/made"
	said=$(cd "$repo" && PATH="$WORK/bin:$PATH" tools/gate_changed.sh "$3" 2>&1)
	status=$?
	made=$(paste -sd';' - <"$WORK/made")
	[[ "$made" == "$4" ]] || fail "$1 ($3): ran '$made', not '$4': $said"
	[[ "$status" == "$5" ]] || fail "$1 ($3): exited $status, not $5: $said"
}

guard='--no-print-directory guard-check'
gen='--no-print-directory ship-gen-check'
sites='sites --check-sites'

expect sim-only 'echo more >>core/movement.gd' guard-check "$sites" 0
grep -q 'not run' <<<"$said" || fail "sim-only: did not say guard-check was not run: $said"
expect sim-only 'echo more >>core/movement.gd' ship-gen-check '' 0
grep -q 'not run' <<<"$said" || fail "sim-only: did not say ship-gen-check was not run: $said"
expect docs-and-tests 'echo more >>docs/notes.md; echo more >>tests/unit/test_ticks.gd' guard-check "$sites" 0
expect docs-and-tests 'echo more >>docs/notes.md; echo more >>tests/unit/test_ticks.gd' ship-gen-check '' 0
FAIL_SITES=1 expect sites-fail 'echo more >>core/movement.gd' guard-check "$sites" 1

expect tool 'echo more >>tools/gen_tug.py' guard-check "$guard" 0
expect tool 'echo more >>tools/gen_tug.py' ship-gen-check "$gen" 0
expect new-tool 'echo new >tools/new_check.sh' guard-check "$guard" 0
expect makefile 'echo more >>Makefile; git add -A; git commit -qm change' guard-check "$guard" 0
expect makefile 'echo more >>Makefile; git add -A; git commit -qm change' ship-gen-check "$gen" 0
expect golden 'echo more >>tests/golden/match.txt' guard-check "$guard" 0
expect golden 'echo more >>tests/golden/match.txt' ship-gen-check '' 0
expect ship-data 'echo more >>data/ships/tug.tres' ship-gen-check "$gen" 0
expect ship-data 'echo more >>data/ships/tug.tres' guard-check "$sites" 0
expect rules 'echo more >>data/rules/brawl.tres' ship-gen-check "$gen" 0
expect test-hull 'echo more >>tests/fixtures/ships/tug_weak.tres' ship-gen-check "$gen" 0
FAIL_MAKE=1 expect step-fails 'echo more >>tools/gen_tug.py' guard-check "$guard" 1
FAIL_MAKE=1 expect step-fails 'echo more >>tools/gen_tug.py' ship-gen-check "$gen" 1

: >"$WORK/made"
(cd "$repo" && PATH="$WORK/bin:$PATH" tools/gate_changed.sh art-lint >/dev/null 2>&1)
[[ $? == 2 && ! -s "$WORK/made" ]] || fail "an unknown step did not exit 2 having run nothing"

((fails == 0)) && echo "gate-changed-check: ok"
exit "$fails"
