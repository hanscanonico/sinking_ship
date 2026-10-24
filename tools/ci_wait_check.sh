#!/usr/bin/env bash
#
# `make guard-check`: tools/ci_wait.sh against a stand-in gh that answers from a
# sequence of CI snapshots. It waits out pending checks and a job reported late,
# says all passed and exits 0; on a failure it names the check, prints the failing
# lines of its log without timestamps, colours or the runner's own closing error,
# and exits 1; it exits 3 when the time runs out and 2 for a PR that does not exist.

set -uo pipefail
tool="$(cd "$(dirname "$0")" && pwd)/ci_wait.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "ci-wait-check: $1" >&2
	fails=1
}

mkdir "$WORK/bin"
cat >"$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
# Each 'pr checks' call answers with the next snapshot, then with the last one again.
case "\$1 \$2" in
"pr view")
	[[ "\$3" == 404 ]] && exit 1
	case "\$*" in
	*headRefOid*) echo abc1234 ;;
	*) echo "\${3:-7}" | sed 's/^--json\$/7/' ;;
	esac
	;;
"pr checks")
	n=\$(cat '$WORK/calls' 2>/dev/null || echo 0)
	n=\$((n + 1))
	echo "\$n" >'$WORK/calls'
	f='$WORK/snap.'\$n
	[[ -e "\$f" ]] || f=\$(ls '$WORK'/snap.* | sort -t. -k2 -n | tail -1)
	cat "\$f"
	;;
"run view") cat '$WORK/job.log' ;;
*) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/gh"

snaps() { # each argument a snapshot, its checks separated by ';'
	rm -f "$WORK"/snap.* "$WORK/calls"
	local i=0 s
	for s in "$@"; do
		i=$((i + 1))
		printf '%s' "$s" | tr ';' '\n' >"$WORK/snap.$i"
	done
}
run() {
	said=$(PATH="$WORK/bin:$PATH" CI_WAIT_POLL=0 "$tool" "$@" 2>&1)
	status=$?
}
link=https://github.com/o/r/actions/runs/11/job/22
P=$'\t'

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

((fails == 0)) && echo "ci-wait-check: ok"
exit "$fails"
