#!/usr/bin/env bash
#
# `make guard-check`: tools/exactness.sh against a throwaway repo and a stand-in
# engine, whose "match" is its checkout's sim.txt, a line a tick. Two sides that
# simulate alike pass, naming the ticks, with the base run in a worktree of its own
# beside the others and never in the main checkout; the base's hashes are kept, and
# served again to a run of as many ticks or fewer; a differing tick fails and is named;
# a script load error fails; a hash file short of TICKS fails; a checkout whose class
# cache is behind a class_name is imported before its match runs; and a BASE that
# names no commit fails before any engine starts. No Godot runs.

set -uo pipefail
tools="$(cd "$(dirname "$0")" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export TEST_SLOT_LOCK="$WORK/slot" TEST_SLOTS=4 TEST_SLOT_MIN_FREE_MB=0
export EXACTNESS_CACHE="$WORK/cache" RECORD="$WORK/record"
unset TEST_SLOT_NOTICE_FD TEST_SLOT_NAME BASE SEED SHIP TICKS FAST NATIVE LIMIT

fails=0
fail() {
	echo "exactness-check: $1" >&2
	fails=1
}

# The stand-in: `--import` writes --path's class cache from its scripts' class_name
# lines; a run records "run PATH", prints a Parse Error when the class cache misses a
# declared class or the checkout holds a file named broken, and else writes the first
# --ticks lines of the checkout's sim.txt to --out, numbered.
export GODOT="$WORK/godot"
cat >"$GODOT" <<'STANDIN'
#!/usr/bin/env bash
path="" ticks=0 out="" import=0
while (($#)); do
	case "$1" in
	--path) path="$2" && shift ;;
	--import) import=1 ;;
	--ticks=*) ticks="${1#--ticks=}" ;;
	--out=*) out="${1#--out=}" ;;
	esac
	shift
done
cache="$path/.godot/global_script_class_cache.cfg"
classes() {
	(cd "$path" && grep -rHE --include='*.gd' --exclude-dir=.godot '^class_name ' .) |
		sed -E 's|^\./([^:]+):class_name ([A-Za-z0-9_]+).*|\2 \1|'
}
if ((import)); then
	echo "import $(basename "$path")" >>"$RECORD"
	mkdir -p "$path/.godot"
	classes | while read -r name script; do
		printf '"class": &"%s",\n"path": "res://%s"\n}, {\n' "$name" "$script"
	done >"$cache"
	exit 0
fi
echo "run $(basename "$path")" >>"$RECORD"
echo "exactness: the GDScript ran, no extension loaded"
while read -r name script; do
	grep -q "&\"$name\"" "$cache" || {
		echo "SCRIPT ERROR: Parse Error: Could not find type \"$name\" in the current scope."
		exit 0
	}
done < <(classes)
if [[ -e "$path/broken" ]]; then
	echo 'SCRIPT ERROR: Parse Error: Unexpected "Identifier" in class body.'
	exit 0
fi
head -n "$ticks" "$path/sim.txt" | awk '{ print NR, $0 }' >"$out"
STANDIN
chmod +x "$GODOT"

repo="$WORK/main"
git init -q "$repo"
git -C "$repo" config user.name check
git -C "$repo" config user.email check@example.com
git -C "$repo" config core.autocrlf false
mkdir -p "$repo/tools" "$repo/core"
cp "$tools/exactness.sh" "$tools/exactness.gd" "$tools/engine_guard.sh" "$tools/test_slot.sh" "$repo/tools/"
cp -r "$tools/lib" "$repo/tools/lib"
printf 'class_name Thing\n' >"$repo/core/thing.gd"
printf 'aa\nbb\ncc\ndd\nee\n' >"$repo/sim.txt"
printf '.godot/\n' >"$repo/.gitignore"
git -C "$repo" add -A
git -C "$repo" commit -qm base
git -C "$repo" branch -M main
tree="$WORK/main-worktrees/branch"
git -C "$repo" worktree add -q "$tree" -b branch main
short="$(git -C "$repo" rev-parse --short=10 main)"
base="exactness-base-$short"

# Runs the driver in the branch's worktree with arguments $2… as its environment,
# into $WORK/$1.out and a fresh record; its exit status is the driver's.
run() {
	local name="$1"
	shift
	: >"$RECORD"
	env BASE=main "$@" "$tree/tools/exactness.sh" >"$WORK/$name.out" 2>&1
}

# How many lines of the record are exactly $1.
recorded() {
	grep -cx "$1" "$RECORD"
}

# Alike: a pass naming the ticks, the base run in its own worktree, each side imported.
run equal TICKS=5 || fail "two sides alike failed: $(cat "$WORK/equal.out")"
grep -qx 'exactness: PASS 5 ticks' "$WORK/equal.out" || fail "two sides alike did not say PASS 5 ticks"
[[ -d "$WORK/main-worktrees/$base" ]] || fail "the base's worktree is not $base beside the others"
(($(recorded "run $base") == 1 && $(recorded "run branch") == 1)) || fail "two sides alike ran $(paste -sd, "$RECORD")"
(($(recorded "import $base") == 1 && $(recorded "import branch") == 1)) || fail "a fresh checkout was not imported once a side"
(($(recorded "run main") + $(recorded "import main") == 0)) || fail "an engine ran in the main checkout"
[[ -z "$(git -C "$repo" stash list)" ]] || fail "something was stashed"

# Again: the base's hashes are kept, its worktree reused, nothing imported twice.
run again TICKS=5 || fail "a second run failed: $(cat "$WORK/again.out")"
(($(recorded "run $base") == 0 && $(recorded "run branch") == 1)) || fail "a second run ran $(paste -sd, "$RECORD")"
(($(grep -c '^import' "$RECORD") == 0)) || fail "a second run imported again"

# Fewer ticks are served from the kept file; a kept file too short runs the base again.
run fewer TICKS=3 || fail "fewer ticks failed: $(cat "$WORK/fewer.out")"
grep -qx 'exactness: PASS 3 ticks' "$WORK/fewer.out" || fail "fewer ticks did not say PASS 3 ticks"
(($(recorded "run $base") == 0)) || fail "fewer ticks ran the base again"
for kept in "$WORK"/cache/*.hashes; do
	printf '1 aa\n2 bb\n3 cc\n' >"$kept"
done
run more TICKS=5 || fail "a kept file too short failed: $(cat "$WORK/more.out")"
(($(recorded "run $base") == 1)) || fail "a kept file too short did not run the base again"

# Other arguments are another match: the base runs for them.
run seed TICKS=5 SEED=7 || fail "another seed failed: $(cat "$WORK/seed.out")"
(($(recorded "run $base") == 1)) || fail "another seed was served the first seed's hashes"

# A differing tick fails, and is named; the ticks before it still pass.
printf 'aa\nbb\ncc\nd0\nee\n' >"$tree/sim.txt"
run differs TICKS=5 && fail "a differing tick passed"
grep -qx 'exactness: FAIL first differing tick 4' "$WORK/differs.out" || fail "a differing tick said: $(cat "$WORK/differs.out")"
run before TICKS=3 || fail "the ticks before the differing one failed: $(cat "$WORK/before.out")"
git -C "$tree" checkout -q sim.txt

# A script load error fails, whatever the hashes.
touch "$tree/broken"
run broken TICKS=5 && fail "a script load error passed"
grep -q 'exactness: FAIL the branch side did not run' "$WORK/broken.out" || fail "a script load error said: $(cat "$WORK/broken.out")"
grep -q 'PASS' "$WORK/broken.out" && fail "a script load error said PASS"
rm "$tree/broken"

# A hash file short of TICKS fails.
printf 'aa\nbb\ncc\n' >"$tree/sim.txt"
run short TICKS=5 && fail "a short hash file passed"
grep -q 'exactness: FAIL the branch side wrote 3 of 5 ticks' "$WORK/short.out" || fail "a short hash file said: $(cat "$WORK/short.out")"
git -C "$tree" checkout -q sim.txt

# A class_name the class cache has not seen: imported before the match, which passes.
printf 'class_name Late\n' >"$tree/core/late.gd"
run late TICKS=5 || fail "a new class_name failed: $(cat "$WORK/late.out")"
[[ "$(head -n 1 "$RECORD")" == "import branch" ]] || fail "a new class_name was not imported before the match"

# A BASE that names no commit, and a TICKS that is no count: no engine.
run nobase TICKS=5 BASE=no-such-ref && fail "a BASE that names no commit passed"
run noticks TICKS=many && fail "TICKS=many passed"
[[ ! -s "$RECORD" ]] || fail "a refused run started an engine"

((fails == 0)) && echo "exactness-check: ok"
exit "$fails"
