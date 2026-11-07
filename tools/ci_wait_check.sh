#!/usr/bin/env bash
#
# `make guard-check`: tools/ci_wait.sh against a stand-in gh that answers from a
# sequence of CI snapshots. It waits out pending checks and a job reported late,
# says all passed and exits 0; on a failure it names the check, prints the failing
# lines of its log without timestamps, colours or the runner's own closing error,
# and exits 1; it exits 3 when the time runs out and 2 for a PR that does not exist.
# A head with no check past the grace exits 4 with why: the PR conflicts with main
# (asked again while GitHub has not worked it out), no workflow ran for it, or every
# run ended without a check; a run still on its way for the head is waited for.

set -uo pipefail
tool="$(cd "$(dirname "$0")" && pwd)/ci_wait.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "ci-wait-check: $1" >&2
	fails=1
}

sha=abc1234def5678abc1234def5678abc1234def56
mkdir "$WORK/bin"
cat >"$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
# Each 'pr checks' call answers with the next snapshot, then with the last one again,
# and each ask of whether the PR merges with the next of 'merges' the same way. 'run
# list' names the head's runs only when asked for its whole SHA: gh finds none by a
# short one.
next() {
	n=\$(cat "\$1.calls" 2>/dev/null || echo 0)
	n=\$((n + 1))
	echo "\$n" >"\$1.calls"
	f=\$1.\$n
	[[ -e "\$f" ]] || f=\$1.\$(ls "\$1".[0-9]* | wc -l)
	cat "\$f"
}
case "\$1 \$2" in
"pr view")
	[[ "\$3" == 404 ]] && exit 1
	case "\$*" in
	*mergeable*) next '$WORK/merges' ;;
	*headRefOid*) echo abc1234 ;;
	*) echo "\${3:-7}" | sed 's/^--json\$/7/' ;;
	esac
	;;
"pr checks") next '$WORK/snap' ;;
"run list")
	[[ "\$*" == *"--commit $sha "* ]] && cat '$WORK/runs'
	exit 0
	;;
"run view") cat '$WORK/job.log' ;;
*) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/gh"

snaps() { # each argument a snapshot, its checks separated by ';'
	rm -f "$WORK"/snap.*
	local i=0 s
	for s in "$@"; do
		i=$((i + 1))
		printf '%s' "$s" | tr ';' '\n' >"$WORK/snap.$i"
	done
}
merges() { # each argument what one ask of whether the PR merges says, in turn
	rm -f "$WORK"/merges.*
	local i=0 s
	for s in "$@"; do
		i=$((i + 1))
		printf '%s\t%s\tmain\tfix/x\n' "$sha" "$s" >"$WORK/merges.$i"
	done
}
runs() { # the head's workflow runs, status<TAB>name<TAB>conclusion, separated by ';'
	printf '%s' "$1" | tr ';' '\n' >"$WORK/runs"
}
run() {
	said=$(PATH="$WORK/bin:$PATH" CI_WAIT_POLL=0 "$tool" "$@" 2>&1)
	status=$?
}
link=https://github.com/o/r/actions/runs/11/job/22
P=$'\t'
merges MERGEABLE
runs ""

# Pending, then a job the others wait on reported late, then all passed.
snaps "pending${P}lint${P}$link;pending${P}test 1/8${P}$link" \
	"pass${P}lint${P}$link;pass${P}test 1/8${P}$link" \
	"pass${P}lint${P}$link;pass${P}test 1/8${P}$link;pending${P}verify${P}$link" \
	"pass${P}lint${P}$link;pass${P}test 1/8${P}$link;pass${P}verify${P}$link"
run 5
((status == 0)) || fail "all passed came back $status: $said"
grep -q 'PR #5 at abc1234: all 3 checks passed' <<<"$said" ||
	fail "all passed did not count the late verify job: $said"

# A failed shard: its line, then what its log says failed.
esc=$'\033'
printf '%s\n' \
	"test 3/8${P}test${P}2026-10-23T16:27:28.1Z res://tests/unit/core/test_x.gd" \
	"test 3/8${P}test${P}2026-10-23T16:27:28.2Z ${esc}[31m    [Failed]: [1] expected to equal [2]${esc}[0m" \
	"test 3/8${P}test${P}2026-10-23T16:27:28.3Z ^[[1m- test_the_thing^[[0m" \
	"test 3/8${P}test${P}2026-10-23T16:27:28.4Z just noise" \
	"test 3/8${P}test${P}2026-10-23T16:27:28.5Z ##[error]Process completed with exit code 2." >"$WORK/job.log"
snaps "pending${P}test 3/8${P}$link;pass${P}lint${P}$link" "fail${P}test 3/8${P}$link;pass${P}lint${P}$link"
run 5
((status == 1)) || fail "a failure came back $status: $said"
grep -q "PR #5 at abc1234: 1 of 2 checks passed" <<<"$said" || fail "a failure was not counted: $said"
grep -qF "fail  test 3/8  $link" <<<"$said" || fail "the failed check was not named: $said"
grep -qF '    [Failed]: [1] expected to equal [2]' <<<"$said" ||
	fail "the failed test's line was not printed bare: $said"
grep -qF '    - test_the_thing' <<<"$said" || fail "a colour written as text was left on: $said"
grep -q 'res://tests/unit/core/test_x.gd' <<<"$said" || fail "the failing script was not printed: $said"
grep -q -e 'just noise' -e 'Process completed' -e '2026-10-23T' <<<"$said" &&
	fail "noise, a timestamp or the runner's closing error was printed: $said"

# Out of time, and no such PR.
snaps "pending${P}lint${P}$link"
CI_WAIT_MINUTES=0 run 5
((status == 3)) || fail "out of time came back $status: $said"
grep -q 'still running after 0 min: lint' <<<"$said" || fail "out of time did not name what still runs: $said"
run 404
((status == 2)) || fail "a PR that does not exist came back $status: $said"

# No check yet, but within the grace: nothing asked, even of a PR that conflicts.
merges CONFLICTING
snaps "" "pending${P}lint${P}$link" "pass${P}lint${P}$link"
run 5
((status == 0)) || fail "a check reported within the grace came back $status: $said"
grep -q 'PR #5 at abc1234: all 1 checks passed' <<<"$said" ||
	fail "a check reported within the grace was not waited for: $said"

# Past the grace with no check, on a PR that conflicts with main: GitHub runs none.
snaps ""
CI_WAIT_GRACE=0 CI_WAIT_MINUTES=1 run 5
((status == 4)) || fail "a PR that conflicts came back $status: $said"
[[ "$said" == "ci-wait: PR #5 at abc1234 has no CI run: it conflicts with main; merge main" ]] ||
	fail "a PR that conflicts was not said to: $said"

# GitHub has not worked out whether it merges: asked again until it has.
merges UNKNOWN UNKNOWN CONFLICTING
CI_WAIT_GRACE=0 CI_WAIT_MINUTES=1 run 5
((status == 4)) || fail "a conflict worked out late came back $status: $said"
grep -q 'has no CI run: it conflicts with main' <<<"$said" ||
	fail "a conflict worked out late was not waited for: $said"

# No run for the head of a PR that merges: the workflow was skipped.
merges MERGEABLE
CI_WAIT_GRACE=0 CI_WAIT_MINUTES=1 run 5
((status == 4)) || fail "a skipped workflow came back $status: $said"
grep -q '^ci-wait: PR #5 at abc1234 has no CI run: no workflow ran for its head' <<<"$said" ||
	fail "a skipped workflow was not said to be: $said"
grep -qF 'gh workflow run verify.yml --ref fix/x' <<<"$said" ||
	fail "a skipped workflow did not say how to start one: $said"

# Still not worked out after four asks more: said as no run, not waited out.
merges UNKNOWN
CI_WAIT_GRACE=0 CI_WAIT_MINUTES=1 run 5
((status == 4)) || fail "a PR GitHub never works out came back $status: $said"
grep -q 'has no CI run: no workflow ran for its head' <<<"$said" ||
	fail "a PR GitHub never works out was not said to have no run: $said"
asked=$(cat "$WORK/merges.calls" 2>/dev/null)
[[ "$asked" == 5 ]] || fail "a PR GitHub never works out was asked ${asked:-no} times, not 5"

# A run on its way for the head, asked for by its whole SHA: waited for, then its checks.
merges MERGEABLE
runs "queued${P}verify${P}"
snaps "" "" "pending${P}lint${P}$link" "pass${P}lint${P}$link"
CI_WAIT_GRACE=0 run 5
((status == 0)) || fail "a run on its way came back $status: $said"
grep -q 'PR #5 at abc1234: all 1 checks passed' <<<"$said" || fail "a run on its way was not waited for: $said"

# It never reports a check: out of time, said so.
snaps ""
CI_WAIT_GRACE=0 CI_WAIT_MINUTES=0 run 5
((status == 3)) || fail "a run that reports nothing came back $status: $said"
grep -q 'still running after 0 min: no check reported yet' <<<"$said" ||
	fail "a run that reports nothing was not said to have none: $said"

# Every run on the head ended without a check: said, not waited out.
runs "completed${P}verify${P}startup_failure"
CI_WAIT_GRACE=0 CI_WAIT_MINUTES=1 run 5
((status == 4)) || fail "runs that ended without a check came back $status: $said"
want="ci-wait: PR #5 at abc1234 has no checks: every run on its head ended without one"
[[ "$said" == "$want (verify: startup_failure)" ]] || fail "runs that ended without a check were not said to: $said"

# One empty answer amid the checks, as when gh fails once: not asked why, and waited on.
runs "completed${P}verify${P}success"
snaps "pending${P}lint${P}$link" "" "pass${P}lint${P}$link"
CI_WAIT_GRACE=0 run 5
((status == 0)) || fail "one empty answer came back $status: $said"
grep -q 'PR #5 at abc1234: all 1 checks passed' <<<"$said" || fail "one empty answer was taken for no CI: $said"

((fails == 0)) && echo "ci-wait-check: ok"
exit "$fails"
