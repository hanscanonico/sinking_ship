#!/usr/bin/env bash
#
# `make exactness [BASE=origin/main] [SEED=1701] [SHIP=steamer] [TICKS=1200] [FAST=1]
# [NATIVE=0] [LIMIT=1800]`: does this checkout simulate bit for bit like BASE?
#
# One bots-only match is stepped TICKS ticks on each side by tools/exactness.gd, which
# writes a line per tick — the tick, and a hash of that tick's whole snapshot as bytes
# — and the two files are compared: `exactness: PASS <ticks> ticks`, or `exactness:
# FAIL first differing tick N` and a non-zero exit. The match digest is no stand-in for
# it: it quantizes, and once hid a reordered float sum only the Linux goldens caught
# (#303).
#
# The branch side is this checkout as it stands, uncommitted edits included. The base
# side is a detached worktree of BASE's commit beside the others,
# MAIN-worktrees/exactness-base-<short sha> — made and imported here when it is not
# there, reused when it is, never the main checkout, and nothing is stashed. This
# checkout's tools/exactness.gd runs on both, so a base from before the tool is as good
# as any. BASE is read as the checkout has it: fetch first for the newest origin/main.
# The base's hashes are kept under ~/.cache/sinking_ship/exactness (EXACTNESS_CACHE),
# by its commit, the match's arguments and the tool's own contents, and a kept file
# with TICKS lines or more is read rather than run again.
#
# It fails fast rather than hang (a probe once looped three hours on script load
# errors: its worktree had been rebased onto a new class_name and not imported again):
# - a side whose class cache (.godot/global_script_class_cache.cfg) does not name every
#   `class_name` its scripts declare, where they declare it, is imported first — one
#   grep, so it is asked on every run;
# - each engine runs under tools/engine_guard.sh with ENGINE_GUARD_EARLY, which stops it
#   at the first Parse or Compile Error, and any engine error line fails the run;
# - each engine has LIMIT seconds (1800; 0 for no limit) and is stopped past them;
# - a hash file must hold exactly TICKS lines.
# Every engine takes a test slot (tools/test_slot.sh) and is headless: no window.
#
# NATIVE=0 runs the GDScript on both sides whatever extension (native/) is loaded; each
# side's line says which ran. native/lib is built per checkout and never tracked, so a
# base worktree runs the GDScript until `make native` is run in it.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source tools/lib/require_godot.sh
require_godot exactness

BASE="${BASE:-origin/main}"
SEED="${SEED:-1701}"
SHIP="${SHIP:-steamer}"
TICKS="${TICKS:-1200}"
FAST="${FAST:-}"
NATIVE="${NATIVE:-1}"
LIMIT="${LIMIT:-1800}"
CACHE="${EXACTNESS_CACHE:-$HOME/.cache/sinking_ship/exactness}"

die() {
	echo "exactness: $1" >&2
	exit "${2:-1}"
}
[[ "$TICKS" =~ ^[1-9][0-9]*$ ]] || die "TICKS takes a count of 1 or more, not '$TICKS'" 2
[[ "$SEED" =~ ^[0-9]+$ ]] || die "SEED takes a whole number of 0 or more, not '$SEED'" 2
[[ "$SHIP" =~ ^[A-Za-z0-9_]+$ ]] || die "SHIP takes a ship's name, not '$SHIP'" 2
[[ "$LIMIT" =~ ^[0-9]+$ ]] || die "LIMIT takes seconds, not '$LIMIT'" 2
[[ "$NATIVE" == 0 ]] || NATIVE=1
[[ -z "$FAST" || "$FAST" == 0 ]] && fast=0 || fast=1

# A path as the engine reads it: Windows' own under Git Bash.
engine_path() {
	if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi
}

root="$(pwd -P)"
tool="$root/tools/exactness.gd"
main="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" ||
	die "not in a git checkout"
sha="$(git rev-parse --verify --quiet "$BASE^{commit}")" || die "BASE=$BASE names no commit here"
short="$(git rev-parse --short=10 "$sha")"
base="$main-worktrees/exactness-base-$short"
key="seed$SEED-$SHIP-fast$fast-native$NATIVE"

WORK="$(mktemp -d)"
keep=0
trap '((keep)) || rm -rf "$WORK"' EXIT

# Whether checkout $1's class cache misses a class_name its scripts declare, or the
# script it is declared in.
classes_stale() {
	local cache="$1/.godot/global_script_class_cache.cfg"
	[[ -f "$cache" ]] || return 0
	(cd "$1" && grep -rHE --include='*.gd' --exclude-dir=.godot '^class_name[[:space:]]+[A-Za-z0-9_]+' .) |
		sed -E 's|^\./([^:]+):class_name[[:space:]]+([A-Za-z0-9_]+).*|\2 res://\1|' | sort >"$WORK/declared"
	sed 's/\r$//' "$cache" | awk -F'"' '
		/^"class":/ { name = $4 }
		/^"path":/ { print name, $4 }' | sort >"$WORK/cached"
	[[ -n "$(comm -23 "$WORK/declared" "$WORK/cached")" ]]
}

# Imports checkout $2, the $1 side, when its class cache is stale.
import_if_stale() {
	classes_stale "$2" || return 0
	echo "exactness: importing the $1 side ($2): its class cache is behind its scripts"
	tools/test_slot.sh "$GODOT" --headless --path "$2" --import >"$WORK/$1.import.log" 2>&1 || {
		tail -n 20 "$WORK/$1.import.log" >&2
		die "FAIL the $1 side's import failed"
	}
}

# Steps the match in checkout $2, the $1 side, its hashes into file $3; says which code
# ran, and exits on anything but TICKS lines from a run with no engine error.
run_side() {
	local side="$1" dir="$2" out="$3" log="$WORK/$1.log" lines
	import_if_stale "$side" "$dir"
	rm -f "$out"
	ENGINE_GUARD_EARLY=1 ENGINE_GUARD_LIMIT="$LIMIT" tools/test_slot.sh tools/engine_guard.sh \
		"$GODOT" --headless --no-header --path "$dir" -s "$(engine_path "$tool")" -- \
		--seed="$SEED" --ship="$SHIP" --fast="$fast" --native="$NATIVE" \
		--ticks="$TICKS" --out="$(engine_path "$out")" >"$log" 2>&1 || {
		grep -v '^\[godot_ai' "$log" | tail -n 30 >&2
		die "FAIL the $side side did not run ($dir)"
	}
	said="$(sed 's/\r$//' "$log" | grep -m 1 '^exactness: ' | sed 's/^exactness: //')"
	lines=0
	[[ -f "$out" ]] && lines="$(wc -l <"$out" | tr -d ' ')"
	((lines == TICKS)) || die "FAIL the $side side wrote $lines of $TICKS ticks ($dir)"
	grep -Evq '^[0-9]+ [0-9a-f]+$' "$out" && die "FAIL the $side side wrote a line that is no tick and hash"
	return 0
}

head_short="$(git rev-parse --short=10 HEAD)"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || head_short+=" and uncommitted changes"
echo "exactness: seed $SEED · $SHIP · $TICKS ticks · $([[ $fast == 1 ]] && echo fast || echo paced) clock"

branch_out="$WORK/branch.hashes"
run_side branch "$root" "$branch_out"
echo "exactness: branch $head_short: $said"

# The base's hashes: the kept file when it is long enough, else a run in its worktree.
if [[ ! -d "$base" ]]; then
	echo "exactness: adding the base's worktree $base"
	git worktree add --detach "$base" "$sha" >"$WORK/worktree.log" 2>&1 || {
		cat "$WORK/worktree.log" >&2
		die "FAIL cannot add the base's worktree"
	}
elif [[ "$(git -C "$base" rev-parse HEAD 2>/dev/null)" != "$sha" ]]; then
	die "FAIL $base is not at $short: remove it (git worktree remove) and run again"
fi
lib=0
compgen -G "$base/native/lib/*" >/dev/null && lib=1
kept="$CACHE/$sha-$key-lib$lib-tool$(git hash-object "$tool" | cut -c1-10)"
base_out="$WORK/base.hashes"
if [[ -f "$kept.hashes" ]] && (($(wc -l <"$kept.hashes") >= TICKS)); then
	head -n "$TICKS" "$kept.hashes" >"$base_out"
	said="$(cat "$kept.said" 2>/dev/null), kept from an earlier run"
else
	run_side base "$base" "$base_out"
	mkdir -p "$CACHE" && cp "$base_out" "$kept.hashes.$$" && mv "$kept.hashes.$$" "$kept.hashes" &&
		echo "$said" >"$kept.said"
fi
echo "exactness: base $BASE at $short: $said"

differing="$(awk 'NR == FNR { base[FNR] = $0; next } base[FNR] != $0 { print $1; exit }' \
	<(sed 's/\r$//' "$base_out") <(sed 's/\r$//' "$branch_out"))"
if [[ -n "$differing" ]]; then
	keep=1
	echo "exactness: FAIL first differing tick $differing"
	echo "exactness: the base's hashes are in $base_out, the branch's in $branch_out"
	exit 1
fi
echo "exactness: PASS $TICKS ticks"
