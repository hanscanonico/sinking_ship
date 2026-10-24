#!/usr/bin/env bash
#
# `make guard-check`, its eighth part: `make lint`, `make format-check` and `make
# format` run tools/gdtoolkit_each.sh, which runs their tool once on a single file
# before fanning the rest out through xargs, so gdtoolkit's parser cache directory
# exists before parallel workers race to makedirs it (the losers print "File
# exists" and fail). Held against a stand-in tool that notes the files each run is
# handed: the warm-up runs alone and done before any worker starts; every file
# reaches the tool exactly once — under GNU make on Windows the old recipe's fan-out
# never ran, and lint passed having read the warm-up's file alone —; no run takes
# more than 60; and a failure, the warm-up's or a worker's, fails the whole run.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "lint-warmup-check: $1" >&2
	fails=1
}

# Each target hands the script its tool and that tool's flags, nothing more.
for pair in "lint:gdlint" "format-check:gdformat --check" "format:gdformat"; do
	target=${pair%%:*}
	tool=${pair#*:}
	make -n "$target" | grep -qE "tools/gdtoolkit_each\.sh $tool\$" ||
		fail "make $target does not run tools/gdtoolkit_each.sh $tool"
done

tools/gdtoolkit_each.sh --list | tr '\0' '\n' >"$WORK/files"
first=$(head -n 1 "$WORK/files")
count=$(grep -c . "$WORK/files")
((count > 61)) || fail "the list holds $count files, too few to fan out over more than one worker"
case $first in
./*.gd) ;;
*) fail "the list's first entry is '$first', not a .gd file" ;;
esac
grep -q '^\./addons/' "$WORK/files" && fail "the list holds vendored addons"

# The stand-in: each run notes its files, one a line, in a file of its own. The
# warm-up, the list's first file alone, takes a moment and then leaves a mark; a
# worker that starts before the mark is there notes that it raced the warm-up.
cat >"$WORK/tool" <<'EOF'
#!/usr/bin/env bash
note=$(mktemp "$RUNS/run.XXXXXX")
if [[ $# -eq 1 && "$1" == "$FIRST" ]]; then
	sleep 0.3
	touch "$RUNS/warm"
elif [[ ! -e "$RUNS/warm" ]]; then
	echo raced >"$note.raced"
fi
printf '%s\n' "$@" >"$note"
for file in "$@"; do
	[[ "$file" == "${FAIL_ON:-}" ]] && exit 1
done
exit 0
EOF
chmod +x "$WORK/tool"

# Runs the script with the stand-in over a fresh notes folder; its status.
run() {
	rm -rf "$WORK/runs" && mkdir "$WORK/runs"
	RUNS="$WORK/runs" FIRST="$first" FAIL_ON="${1:-}" NPROC=4 \
		tools/gdtoolkit_each.sh "$WORK/tool" >/dev/null 2>&1
}

run || fail "a clean run failed"
ls "$WORK"/runs/*.raced >/dev/null 2>&1 && fail "a worker started before the warm-up was done"
warmups=0
for note in "$WORK"/runs/run.*; do
	[[ "$note" == *.raced ]] && continue
	lines=$(grep -c . "$note")
	((lines > 60)) && fail "a run was handed $lines files, more than 60"
	[[ $lines -eq 1 && "$(cat "$note")" == "$first" ]] && warmups=$((warmups + 1))
done
((warmups == 1)) || fail "the list's first file ran alone $warmups times, not once"
find "$WORK/runs" -name 'run.*' ! -name '*.raced' -exec cat {} + | sort >"$WORK/handed"
sort "$WORK/files" >"$WORK/listed"
cmp -s "$WORK/handed" "$WORK/listed" || fail "the tool was not handed every file exactly once:
$(diff "$WORK/listed" "$WORK/handed" | head -5)"

# A worker's failure fails the run; the warm-up's fails it before any worker runs.
last=$(tail -n 1 "$WORK/files")
run "$last" && fail "a failing worker passed the run"
run "$first" && fail "a failing warm-up passed the run"
[[ $(find "$WORK/runs" -name 'run.*' ! -name '*.raced' | wc -l) -eq 1 ]] || fail "workers ran after the warm-up failed"

((fails == 0)) && echo "lint-warmup-check: ok"
exit "$fails"
