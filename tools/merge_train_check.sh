#!/usr/bin/env bash
#
# `make guard-check`: tools/merge_train.sh against a stand-in gh that keeps a few pull
# requests as files, and tools/ci_wait.sh as it is. A green PR that holds main's latest
# commit is squash-merged at its head and its branch deleted; one that lacks it is
# updated first, as is the second of a train once the first has moved main. A draft, a
# closed PR, one in conflict and one that does not exist are skipped, a red one is
# named with its failed checks, and the train goes on to the next. A base or a head
# that moves during CI, or a refused merge, starts the PR over, a bounded number of
# times; an update that fails or CI that never comes is given up on. Every PR gets its
# closing line, and the exit says whether all merged. A second train waits for the
# first, names it, and touches nothing until it is gone. Nothing here asserts a time.

set -uo pipefail
tool="$(cd "$(dirname "$0")" && pwd)/merge_train.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "merge-train-check: $1" >&2
	fails=1
}

mkdir "$WORK/bin"
cat >"$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
# The pull requests are directories under $GH_FAKE/pr, a file a fact: state, draft,
# mergeable, head, branch, behind (how far its head is behind main), and checks.HEAD,
# the checks of one head. Every call that changes something is a line in $GH_FAKE/calls.
# Marker files bend an answer: no_update fails update-branch, refuse fails the next
# merge and refuse_always every one, hold keeps a merge waiting for $GH_FAKE/release,
# and during_ci is shell run once, when the PR's checks are first asked for.
G=$GH_FAKE
d=$G/pr/${3-}
get() { cat "$d/$1" 2>/dev/null; }
case "$1 ${2-}" in
"pr view")
	[[ -d "$d" ]] || exit 1
	case "$*" in
	*isDraft*)
		printf '%s\t%s\t%s\t%s\t%s\tmain\n' \
			"$(get state)" "$(get draft)" "$(get mergeable)" "$(get head)" "$(get branch)"
		;;
	*mergeable*) printf '%s\t%s\tmain\t%s\n' "$(get head)" "$(get mergeable)" "$(get branch)" ;;
	*headRefOid*) get head | cut -c1-7 ;;
	*) echo "$3" ;;
	esac
	;;
"pr checks")
	if [[ -e "$d/during_ci" ]]; then
		mv "$d/during_ci" "$d/during_ci.ran"
		(cd "$d" && . ./during_ci.ran)
	fi
	get "checks.$(get head)"
	exit 0
	;;
"pr update-branch")
	echo "update-branch $3" >>"$G/calls"
	if [[ -e "$d/no_update" ]]; then
		echo "GraphQL: merge conflict between base and head (updatePullRequestBranch)" >&2
		exit 1
	fi
	new="u$(get head)"
	echo "$new" >"$d/head"
	echo 0 >"$d/behind"
	[[ -e "$d/checks.$new" ]] || printf 'pass\tverify\tlink\n' >"$d/checks.$new"
	;;
"pr merge")
	echo "merge $3 $4 $5 ${6-}" >>"$G/calls"
	if [[ "$4 $5" != "--squash --match-head-commit" || "${6-}" != "$(get head)" ]]; then
		echo "GraphQL: Head branch was modified. Review and try the merge again." >&2
		exit 1
	fi
	if [[ -e "$d/refuse_always" ]] || rm "$d/refuse" 2>/dev/null; then
		echo "GraphQL: Base branch was modified. Review and try the merge again." >&2
		exit 1
	fi
	if [[ -e "$d/hold" ]]; then
		: >"$G/holding"
		until [[ -e "$G/release" ]]; do sleep 0.2; done
	fi
	echo MERGED >"$d/state"
	for other in "$G"/pr/*; do
		[[ "$(cat "$other/state")" == OPEN ]] && echo 1 >"$other/behind"
	done
	exit 0
	;;
"run list" | "run view") exit 0 ;;
"api -X")
	[[ "$3" == DELETE && "$4" == "repos/{owner}/{repo}/git/refs/heads/"* ]] || exit 1
	echo "delete ${4#*refs/heads/}" >>"$G/calls"
	;;
"api repos/{owner}/{repo}/compare/main..."*)
	for other in "$G"/pr/*; do
		[[ "$(cat "$other/head")" == "${2#*...}" ]] && cat "$other/behind" && exit 0
	done
	exit 1
	;;
*) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/gh"

export GH_FAKE="$WORK/gh"
P=$'\t'
green="pass${P}verify${P}link"

# The head a PR is made with: its number, then zeros.
head_of() {
	printf '%s%039d' "$1" 0
}

# Forgets every PR and call.
fresh() {
	rm -rf "$GH_FAKE"
	mkdir -p "$GH_FAKE/pr"
	: >"$GH_FAKE/calls"
}

# PR $1, open, mergeable, level with main and green, then each FILE=CONTENT given.
pr() {
	local d="$GH_FAKE/pr/$1" fact
	mkdir "$d"
	echo OPEN >"$d/state"
	echo false >"$d/draft"
	echo MERGEABLE >"$d/mergeable"
	head_of "$1" >"$d/head"
	echo "fix/pr-$1" >"$d/branch"
	echo 0 >"$d/behind"
	echo "$green" >"$d/checks.$(head_of "$1")"
	shift
	for fact in "$@"; do
		printf '%s\n' "${fact#*=}" >"$d/${fact%%=*}"
	done
}

run() {
	said=$(PATH="$WORK/bin:$PATH" MERGE_TRAIN_LOCK="$WORK/train.flock" MERGE_TRAIN_POLL=0 \
		CI_WAIT_POLL=0 "$tool" "$@" 2>&1)
	status=$?
	calls=$(paste -sd';' - <"$GH_FAKE/calls")
}

# The closing line of PR $1 is "merge-train: #$1 $2", whole.
closes() {
	grep -qxF "merge-train: #$1 $2" <<<"$said"
}

# Level with main and green: merged at its head, squashed, its branch deleted.
fresh
pr 5
run 5
((status == 0)) || fail "a green PR came back $status: $said"
closes 5 merged || fail "a green PR was not said to be merged: $said"
[[ "$calls" == "merge 5 --squash --match-head-commit $(head_of 5);delete fix/pr-5" ]] ||
	fail "a green PR was not squash-merged at its head and its branch deleted: $calls"

# Behind main: updated first, and merged at the head the update made.
fresh
pr 5 behind=2
run 5
((status == 0)) || fail "a PR behind main came back $status: $said"
[[ "$calls" == "update-branch 5;merge 5 --squash --match-head-commit u$(head_of 5);delete fix/pr-5" ]] ||
	fail "a PR behind main was not updated, then merged at its new head: $calls"
grep -q '#5 at 5000000 is 2 behind main: updating its branch' <<<"$said" ||
	fail "a PR behind main was not said to be updated: $said"

# A train of two: the first moves main, so the second is updated before it merges.
fresh
pr 5
pr 6
run 5 6
((status == 0)) || fail "a train of two came back $status: $said"
want="merge 5 --squash --match-head-commit $(head_of 5);delete fix/pr-5;update-branch 6"
want="$want;merge 6 --squash --match-head-commit u$(head_of 6);delete fix/pr-6"
[[ "$calls" == "$want" ]] || fail "a train of two did not merge one, update the other, merge it: $calls"
[[ "$(tail -2 <<<"$said")" == "merge-train: #5 merged"$'\n'"merge-train: #6 merged" ]] ||
	fail "a train of two did not end on a line for each: $said"

# A draft, a closed PR, one in conflict, one that does not exist: skipped, untouched,
# and the green one after them still merges. One merged already counts as merged.
fresh
pr 1 draft=true
pr 2 state=CLOSED
pr 3 mergeable=CONFLICTING
pr 4 state=MERGED
pr 5
run 1 2 3 404 4 5
((status == 1)) || fail "a train with skipped PRs came back $status: $said"
closes 1 "skipped: a draft (gh pr ready 1)" || fail "a draft was not skipped: $said"
closes 2 "skipped: closed" || fail "a closed PR was not skipped: $said"
closes 3 "skipped: conflicts with main" || fail "a PR in conflict was not skipped: $said"
closes 404 "skipped: no such PR" || fail "a PR that does not exist was not skipped: $said"
closes 4 merged || fail "a PR merged already was not said to be merged: $said"
closes 5 merged || fail "the PR after the skipped ones was not merged: $said"
[[ "$calls" == "merge 5 --squash --match-head-commit $(head_of 5);delete fix/pr-5" ]] ||
	fail "a skipped PR was touched: $calls"
fresh
pr 4 state=MERGED
run 4
((status == 0)) || fail "a PR merged already came back $status: $said"

# Red: its failed checks named, nothing merged, and the next PR still rides.
fresh
pr 5 "checks.$(head_of 5)=fail${P}test 3/8${P}link"$'\n'"pass${P}lint${P}link"$'\n'"cancel${P}verify${P}link"
pr 6
run 5 6
((status == 1)) || fail "a red PR came back $status: $said"
closes 5 "red: test 3/8, verify" || fail "a red PR's failed checks were not named: $said"
closes 6 merged || fail "the PR after a red one was not merged: $said"
grep -q '^merge 5' "$GH_FAKE/calls" && fail "a red PR was merged: $calls"
grep -qF '  ci-wait: PR #5 at 5000000: 1 of 3 checks passed' <<<"$said" ||
	fail "the CI waiter's report on a red PR was not passed on: $said"
grep -q '^update-branch 6' "$GH_FAKE/calls" && fail "a red PR, merging nothing, had the next updated: $calls"

# Main moves during CI, from another machine: green, but updated again and waited again.
fresh
pr 5 during_ci='echo 1 >behind'
run 5
((status == 0)) || fail "main moving during CI came back $status: $said"
[[ "$calls" == "update-branch 5;merge 5 --squash --match-head-commit u$(head_of 5);delete fix/pr-5" ]] ||
	fail "main moving during CI did not have the PR updated before its merge: $calls"
grep -q '#5: main moved during CI' <<<"$said" || fail "main moving during CI was not said: $said"

# A push during CI: the head that was waited for is not merged, the new one is, once green.
fresh
pr 5 during_ci="echo pushed00 >head; printf 'pass\tverify\tlink\n' >checks.pushed00"
run 5
((status == 0)) || fail "a push during CI came back $status: $said"
[[ "$calls" == "merge 5 --squash --match-head-commit pushed00;delete fix/pr-5" ]] ||
	fail "a push during CI did not have the new head waited for and merged: $calls"
grep -q '#5: its head moved during CI' <<<"$said" || fail "a push during CI was not said: $said"

# A merge refused once is tried again; refused every time, given up on after the rounds.
fresh
pr 5 refuse=
run 5
((status == 0)) || fail "a merge refused once came back $status: $said"
[[ "$(grep -c '^merge 5' "$GH_FAKE/calls")" == 2 ]] || fail "a merge refused once was not tried again: $calls"
fresh
pr 5 refuse_always=
pr 6
MERGE_TRAIN_ROUNDS=2 run 5 6
((status == 1)) || fail "a merge always refused came back $status: $said"
closes 5 "gave up: after 2 rounds, the merge was refused: GraphQL: Base branch was modified. Review and try the merge again." ||
	fail "a merge always refused was not given up on with why: $said"
[[ "$(grep -c '^merge 5' "$GH_FAKE/calls")" == 2 ]] || fail "a merge always refused was not tried twice: $calls"
closes 6 merged || fail "the PR after one given up on was not merged: $said"

# An update that fails, CI that never comes, CI out of time: given up on, with why.
fresh
pr 5 behind=1 no_update=
run 5
((status == 1)) || fail "a failed update came back $status: $said"
closes 5 "gave up: update-branch failed: GraphQL: merge conflict between base and head (updatePullRequestBranch)" ||
	fail "a failed update was not given up on with why: $said"
fresh
pr 5 "checks.$(head_of 5)="
CI_WAIT_GRACE=0 CI_WAIT_MINUTES=1 run 5
((status == 1)) || fail "a PR with no CI came back $status: $said"
grep -q '^merge-train: #5 gave up: PR #5 at 5000000 has no CI run: no workflow ran for its head' <<<"$said" ||
	fail "a PR with no CI was not given up on with why: $said"
fresh
pr 5 "checks.$(head_of 5)=pending${P}verify${P}link"
CI_WAIT_MINUTES=0 run 5
((status == 1)) || fail "CI out of time came back $status: $said"
closes 5 "gave up: PR #5 still running after 0 min: verify" || fail "CI out of time was not given up on with why: $said"
[[ -z "$calls" ]] || fail "a PR given up on was touched: $calls"

# GitHub never works out whether it merges: the merge itself is left to say.
fresh
pr 5 mergeable=UNKNOWN
run 5
((status == 0)) || fail "a PR GitHub has not worked out came back $status: $said"

# A bad call merges nothing.
fresh
pr 5
run
((status == 2)) || fail "no PR given came back $status: $said"
run 5 fix/pr-5
((status == 2)) || fail "a PR given by its branch came back $status: $said"
[[ -z "$calls" ]] || fail "a bad call merged something: $calls"

# Waits for "$@" to hold, however long the machine takes; ten minutes mean it never will.
await() {
	local asks=0
	until "$@"; do
		((++asks < 3000)) || return 1
		sleep 0.2
	done
}

# Two trains: the second waits for the first, names it, and asks GitHub nothing until
# the first is gone — so it finds main moved, and updates its PR before merging it.
fresh
pr 5 hold=
pr 6
train() {
	PATH="$WORK/bin:$PATH" MERGE_TRAIN_LOCK="$WORK/train.flock" MERGE_TRAIN_POLL=0 CI_WAIT_POLL=0 "$tool" "$@"
}
train 5 >"$WORK/first.out" 2>&1 &
first=$!
if await test -e "$GH_FAKE/holding"; then
	train 6 >"$WORK/second.out" 2>&1 &
	second=$!
	if await grep -q 'waiting for another merge train' "$WORK/second.out"; then
		grep -Eq "^merge-train: waiting for another merge train \(lock $WORK/train.flock\), held by PID [0-9]+ since [0-9-]+ [0-9:]+, merging #5$" \
			"$WORK/second.out" || fail "a waiting train did not name the one running: $(cat "$WORK/second.out")"
		grep -q ' 6' "$GH_FAKE/calls" && fail "a waiting train touched its PR: $(cat "$GH_FAKE/calls")"
	else
		fail "a second train did not wait for the first: $(cat "$WORK/second.out")"
	fi
	: >"$GH_FAKE/release"
	wait "$first" || fail "the first of two trains failed: $(cat "$WORK/first.out")"
	wait "$second" || fail "the second of two trains failed: $(cat "$WORK/second.out")"
	calls=$(paste -sd';' - <"$GH_FAKE/calls")
	want="merge 5 --squash --match-head-commit $(head_of 5);delete fix/pr-5;update-branch 6"
	want="$want;merge 6 --squash --match-head-commit u$(head_of 6);delete fix/pr-6"
	[[ "$calls" == "$want" ]] || fail "two trains did not merge one after the other: $calls"
else
	fail "the first of two trains never came to its merge: $(cat "$WORK/first.out")"
	: >"$GH_FAKE/release"
	wait "$first"
fi

((fails == 0)) && echo "merge-train-check: ok"
exit "$fails"
