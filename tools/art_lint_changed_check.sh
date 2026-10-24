#!/usr/bin/env bash
#
# `make guard-check`: tools/art_lint_changed.sh runs the lint a branch's changes can
# reach — the whole lint for a change to the art, one ship's for a change to her data,
# generator or authoring scene (each ship once, committed or not), the whole lint for a
# generator no ship owns, none for anything else — and fails when a ship's lint
# fails, against a throwaway repo and a stand-in make.

set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "art-lint-changed-check: $1" >&2
	fails=1
}

repo="$WORK/repo"
mkdir -p "$repo/tools" "$repo/data/ships" "$repo/scenes/art" "$repo/core" "$repo/authoring/steamer"
cp "$here/art_lint_changed.sh" "$repo/tools/"
for ship in steamer tug; do
	echo "$ship" >"$repo/data/ships/$ship.tres"
	echo "$ship" >"$repo/tools/gen_$ship.py"
done
echo art >"$repo/scenes/art/ship_art.gd"
echo sim >"$repo/core/movement.gd"
echo scene >"$repo/authoring/steamer/steamer.tscn"
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
[[ "\$*" == *"SHIP=\${FAIL_SHIP:-none}"* ]] && exit 1
exit 0
EOF
chmod +x "$WORK/bin/make"

# A branch named $1 off main, changed by the shell commands $2: the lint must run the
# make lines $3 (';' between them, empty for none) and exit $4.
expect() {
	git -C "$repo" checkout -q -B "$1" main
	git -C "$repo" reset -q --hard main
	git -C "$repo" clean -qfd
	(cd "$repo" && eval "$2")
	: >"$WORK/made"
	said=$(cd "$repo" && PATH="$WORK/bin:$PATH" tools/art_lint_changed.sh 2>&1)
	status=$?
	made=$(paste -sd';' - <"$WORK/made")
	[[ "$made" == "$3" ]] || fail "$1: ran '$made', not '$3': $said"
	[[ "$status" == "$4" ]] || fail "$1: exited $status, not $4: $said"
}

whole='--no-print-directory art-lint'
expect art 'echo more >>scenes/art/ship_art.gd' "$whole" 0
expect ship-data 'echo more >>data/ships/tug.tres' "$whole SHIP=tug" 0
expect each-ship-once 'echo more >>tools/gen_steamer.py; echo more >>authoring/steamer/steamer.tscn
	echo more >>data/ships/tug.tres' "$whole SHIP=steamer;$whole SHIP=tug" 0
expect committed 'echo more >>data/ships/steamer.tres; git add -A; git commit -qm change' "$whole SHIP=steamer" 0
expect shared-generator 'echo shared >tools/gen_common.py' "$whole" 0
expect sim-only 'echo more >>core/movement.gd' '' 0
grep -q 'no lint to run' <<<"$said" || fail "sim-only: did not say why no lint ran: $said"
FAIL_SHIP=tug expect a-ship-fails 'echo more >>data/ships/tug.tres; echo more >>data/ships/steamer.tres' \
	"$whole SHIP=steamer;$whole SHIP=tug" 1

((fails == 0)) && echo "art-lint-changed-check: ok"
exit "$fails"
