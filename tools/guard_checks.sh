#!/usr/bin/env bash
#
# `make guard-check`: every check of the tooling, GUARD_JOBS of them side by side —
# half the cores by default, four at most, and one at least. Each is a script of its own
# against stand-ins in a temp directory of its own, so they share nothing; one after
# another they took 7.7 minutes on the Windows box, most of it their sleeps.
#
# Each check's output is kept and printed whole, in the list's order, once all are
# done, so a run reads the same however they raced. It fails when one does, naming
# every one that did on its last line.
#
# A check run again on Perl's lock (FD_LOCK=perl), the one Git Bash on Windows takes,
# is left out where Perl's is the lock this system picks anyway (tools/lib/fd_lock.sh):
# there the two runs are one check twice.
#
# GUARD_CHECKS=FILE takes the list from FILE instead, a command a line
# (tools/guard_checks_check.sh).
#
# Usage:  tools/guard_checks.sh

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# One check of a run under way: `--one WORK N` runs $WORK/N.cmd, keeping what it says
# and how it ends. Always exits 0, so xargs runs the rest.
if [[ "${1-}" == --one ]]; then
	bash "$2/$3.cmd" >"$2/$3.out" 2>&1
	echo $? >"$2/$3.rc"
	exit 0
fi

checks() {
	if [[ -n "${GUARD_CHECKS-}" ]]; then
		cat "$GUARD_CHECKS"
		return
	fi
	cat <<'EOF'
tools/engine_guard_check.sh
tools/window_lock_check.sh
tools/test_slot_check.sh
FD_LOCK=perl tools/window_lock_check.sh
FD_LOCK=perl tools/test_slot_check.sh
tools/fps_split_check.sh
tools/fps_samples_check.sh
tools/run_tests_check.sh
tools/native_ensure_check.sh
tools/ship_check_once.sh
tools/test_durations_check.sh
tools/art_lint_costs_check.sh
tools/goldens_check.sh
tools/lint_warmup_check.sh
tools/test_changed_check.sh
tools/test_changed.py --check-sites
tools/fixtures_reach_check.sh
tools/prune_worktrees_check.sh
tools/ci_wait_check.sh
tools/ci_tree_verified_check.sh
tools/merge_train_check.sh
FD_LOCK=perl tools/merge_train_check.sh
tools/art_lint_changed_check.sh
tools/art_lint_all_check.sh
tools/gate_changed_check.sh
tools/guard_checks_check.sh
tools/exactness_check.sh
python3 tools/titanic_plates/deck_check.py
EOF
}

if [[ -n "${GUARD_JOBS-}" ]]; then
	if [[ ! "$GUARD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
		echo "guard-check: GUARD_JOBS takes a count of 1 or more, not '$GUARD_JOBS'" >&2
		exit 2
	fi
	jobs=$GUARD_JOBS
else
	cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
	jobs=$((${cores:-2} / 2))
	((jobs <= 4)) || jobs=4
	((jobs >= 1)) || jobs=1
fi

picked=$(unset FD_LOCK && source tools/lib/fd_lock.sh && echo "$FD_LOCK_TOOL")

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

count=0
names=()
while IFS= read -r line; do
	[[ -n "$line" ]] || continue
	if [[ "$line" == "FD_LOCK=$picked "* ]]; then
		echo "guard-check: '$line' left out: $picked's is the lock this system takes anyway"
		continue
	fi
	count=$((count + 1))
	names[count]=$line
	printf '%s\n' "$line" >"$WORK/$count.cmd"
	echo "$count" >>"$WORK/order"
done < <(checks)

if ((count == 0)); then
	echo "guard-check: no checks to run" >&2
	exit 1
fi

xargs -P "$jobs" -n 1 bash "$0" --one "$WORK" <"$WORK/order"

failed=()
for ((i = 1; i <= count; i++)); do
	echo "${names[i]}"
	[[ -f "$WORK/$i.out" ]] && cat "$WORK/$i.out"
	[[ "$(cat "$WORK/$i.rc" 2>/dev/null)" == 0 ]] || failed+=("${names[i]}")
done
if ((${#failed[@]} > 0)); then
	echo "guard-check: FAILED: $(printf '%s; ' "${failed[@]}" | sed 's/; $//')" >&2
	exit 1
fi
echo "guard-check: $count checks ok, $jobs side by side"
