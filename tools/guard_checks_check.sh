#!/usr/bin/env bash
#
# `make guard-check`: tools/guard_checks.sh runs its checks side by side, prints each
# one's output in the list's order however they raced, fails naming every check that
# failed while still running the rest, and leaves out a check asked for again on the
# lock the system picks anyway — against lists of stand-in commands.

set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "guard-checks-check: $1" >&2
	fails=1
}

# Two checks that each wait for the other's mark: both end 0 only when they ran
# side by side. The second ends first, and still prints second.
cat >"$WORK/meet" <<EOF
touch '$WORK/a'; for i in \$(seq 100); do [[ -e '$WORK/b' ]] && { sleep 1; echo first; exit 0; }; sleep 0.1; done; exit 1
touch '$WORK/b'; for i in \$(seq 100); do [[ -e '$WORK/a' ]] && { echo second; exit 0; }; sleep 0.1; done; exit 1
EOF
said=$(GUARD_CHECKS="$WORK/meet" GUARD_JOBS=2 "$here/guard_checks.sh" 2>&1)
status=$?
[[ "$status" == 0 ]] || fail "two checks side by side exited $status, not 0: $said"
[[ "$(grep -x -e first -e second <<<"$said" | paste -sd' ' -)" == "first second" ]] ||
	fail "the outputs were not in the list's order: $said"
grep -q '2 checks ok, 2 side by side' <<<"$said" || fail "no closing line for two checks: $said"

# One at a time, the same two can never meet.
rm -f "$WORK/a" "$WORK/b"
cat >"$WORK/alone" <<EOF
touch '$WORK/a'; for i in 1 2 3; do [[ -e '$WORK/b' ]] && exit 1; sleep 0.1; done; rm '$WORK/a'; echo alone
[[ -e '$WORK/a' ]] && exit 1; touch '$WORK/b'; echo after
EOF
said=$(GUARD_CHECKS="$WORK/alone" GUARD_JOBS=1 "$here/guard_checks.sh" 2>&1)
[[ $? == 0 ]] || fail "GUARD_JOBS=1 did not run the checks one after another: $said"

# A failing check is named, its output kept, and the ones after it still run.
cat >"$WORK/red" <<EOF
echo fine
echo broken >&2; exit 3
echo also broken; false
echo last > '$WORK/last'
EOF
said=$(GUARD_CHECKS="$WORK/red" GUARD_JOBS=2 "$here/guard_checks.sh" 2>&1)
status=$?
[[ "$status" == 1 ]] || fail "a failing check exited $status, not 1: $said"
[[ "$(tail -1 <<<"$said")" == "guard-check: FAILED: echo broken >&2; exit 3; echo also broken; false" ]] ||
	fail "the last line did not name the two failed checks: $said"
grep -qx broken <<<"$said" || fail "a failed check's output was lost: $said"
[[ -e "$WORK/last" ]] || fail "the check after a failed one did not run"

# A check asked for again on the lock this system picks anyway is left out; on another
# lock it runs.
picked=$(unset FD_LOCK && source "$here/lib/fd_lock.sh" && echo "$FD_LOCK_TOOL")
cat >"$WORK/locks" <<EOF
echo plain
FD_LOCK=$picked echo twice
FD_LOCK=other echo other
EOF
said=$(GUARD_CHECKS="$WORK/locks" "$here/guard_checks.sh" 2>&1)
[[ $? == 0 ]] || fail "the lock list failed: $said"
grep -qx twice <<<"$said" && fail "a check on the picked lock ($picked) ran again: $said"
grep -q "left out" <<<"$said" || fail "the left-out check was not named: $said"
grep -qx other <<<"$said" || fail "a check on another lock did not run: $said"

said=$(GUARD_CHECKS="$WORK/locks" GUARD_JOBS=0 "$here/guard_checks.sh" 2>&1)
[[ $? == 2 ]] || fail "GUARD_JOBS=0 was not refused: $said"

((fails == 0)) && echo "guard-checks-check: ok"
exit "$fails"
