#!/usr/bin/env bash
#
# One merge train across the machine: merges the pull requests given, one at a time and
# in the order given, each only when CI is green on a head that holds its base's latest
# commit. Two sessions each looping `gh pr update-branch`, wait, merge move main under
# one another's PRs, and a PR can pass CI again and again and never merge (#703, four
# times); so every session merges through this, and a second train waits for the first.
#
# It holds an exclusive kernel advisory lock (flock(2)) for its whole run, on a plain
# file it keeps open, $MERGE_TRAIN_LOCK, /tmp/sinking_ship_merge_train.flock by default:
# the kernel drops it when the train is gone, however it ends, so there is nothing to
# clean up. A train that finds another running says so in one line on stderr, naming the
# holder as the file does — its PID, when it started, the PRs it merges — and waits as
# long as it takes. The lock is tools/lib/fd_lock.sh's: flock(1), lockf(1) or Perl,
# whichever the system has; with none it fails and merges nothing.
#
# For each PR: one that is a draft, closed, or in conflict with its base is skipped.
# When its head lacks commits of its base, `gh pr update-branch`; then tools/ci_wait.sh
# waits for the head's CI. Red: its failed checks are named and the train moves on,
# merging nothing. Green: the PR is looked at again, and squash-merged at that very head
# (`gh pr merge --squash --match-head-commit`) when it still holds its base's latest
# commit, its branch then deleted on the remote (the local one is its worktree's:
# tools/prune_worktrees.sh). A head or a base that moved during CI — a push, a merge
# from another machine — or a refused merge starts the PR over, MERGE_TRAIN_ROUNDS
# times at most (3).
#
# What it does goes to stdout as it happens, tools/ci_wait.sh's report included, and it
# ends on one line per PR: `merge-train: #N merged`, `red: CHECKS`, `skipped: REASON`
# or `gave up: REASON`. Exits 0 when every PR is merged, 1 when one is not, 2 on a bad
# call. It asks GitHub again every MERGE_TRAIN_POLL seconds (10) while GitHub works
# something out; CI_WAIT_MINUTES and tools/ci_wait.sh's other knobs pass through. It
# runs only gh: no engine, no test slot, next to no memory — run it in the background.
#
# Usage:  tools/merge_train.sh PR [PR…]

set -uo pipefail

LOCK="${MERGE_TRAIN_LOCK:-/tmp/sinking_ship_merge_train.flock}"
poll=${MERGE_TRAIN_POLL:-10}
rounds=${MERGE_TRAIN_ROUNDS:-3}
here="$(cd "$(dirname "$0")" && pwd)"

usage() {
	echo "merge-train: usage: tools/merge_train.sh PR [PR…], each a pull request's number" >&2
	exit 2
}
(($# > 0)) || usage
for pr in "$@"; do
	[[ "$pr" =~ ^[0-9]+$ ]] || usage
done
if ! [[ "$poll" =~ ^[0-9]+$ && "$rounds" =~ ^[1-9][0-9]*$ ]]; then
	echo "merge-train: MERGE_TRAIN_POLL is seconds and MERGE_TRAIN_ROUNDS a count of 1 or more," \
		"not '$poll' and '$rounds'" >&2
	exit 2
fi

source "$here/lib/fd_lock.sh" || exit 1
if [[ -z "$FD_LOCK_TOOL" ]]; then
	echo "merge-train: none of flock, /usr/bin/lockf and perl is available: cannot take $LOCK" >&2
	exit 1
fi

# ", held by PID …" as the running train wrote it; unknown when it has only just taken
# the lock and written nothing yet.
holder() {
	local pid='' since='' prs=''
	IFS=$'\t' read -r pid since prs <"$LOCK" 2>/dev/null
	if [[ "$pid" =~ ^[0-9]+$ ]]; then
		printf ', held by PID %s since %s, merging %s' "$pid" "$since" "$prs"
	else
		printf ', its holder unknown'
	fi
}

exec 9>>"$LOCK" || {
	echo "merge-train: cannot open $LOCK" >&2
	exit 1
}
if ! fd_lock_try 9; then
	echo "merge-train: waiting for another merge train (lock $LOCK)$(holder)" >&2
	fd_lock_wait 9 0 || {
		echo "merge-train: could not take $LOCK" >&2
		exit 1
	}
fi
prs=$(printf '#%s ' "$@")
printf '%s\t%s\t%s\n' "$$" "$(date '+%Y-%m-%d %H:%M')" "${prs% }" >"$LOCK"

say() {
	echo "merge-train: $*"
}

# The first line of what a failed gh said, for a reason that stays one line.
first_line() {
	printf '%s\n' "$1" | tr -d '\r' | grep -m1 . | cut -c1-200
}

# PR $1 as GitHub has it now, into state, draft, mergeable, sha, branch and base; asked
# again, six times at most, while GitHub has not worked out whether it merges, as it has
# not just after its base moved. Fails when there is no such PR, or gh does not answer.
read_pr() {
	local asks=0 info
	while :; do
		info=$(gh pr view "$1" --json state,isDraft,mergeable,headRefOid,headRefName,baseRefName \
			--jq '[.state, .isDraft, .mergeable, .headRefOid, .headRefName, .baseRefName] | @tsv' \
			2>/dev/null | tr -d '\r') || return 1
		IFS=$'\t' read -r state draft mergeable sha branch base <<<"$info"
		[[ -n "$sha" && -n "$base" ]] || return 1
		[[ "$state" == OPEN && "$mergeable" == UNKNOWN ]] || return 0
		((++asks <= 6)) || return 0
		sleep "$poll"
	done
}

# How many commits of its base the PR's head lacks; nothing when gh does not answer.
behind_by() {
	gh api "repos/{owner}/{repo}/compare/$base...$sha" --jq .behind_by 2>/dev/null | tr -d '\r'
}

# Takes PR $1 through the train, and leaves how it went in outcome.
ride() {
	local pr=$1 round asks behind said status was red why='' moved
	if ! read_pr "$pr"; then
		outcome="skipped: no such PR"
		return
	fi
	for ((round = 1; round <= rounds; round++)); do
		if [[ "$state" == MERGED ]]; then
			say "#$pr is merged already"
			outcome="merged"
			return
		elif [[ "$state" != OPEN ]]; then
			outcome="skipped: closed"
			return
		elif [[ "$draft" == true ]]; then
			outcome="skipped: a draft (gh pr ready $pr)"
			return
		elif [[ "$mergeable" == CONFLICTING ]]; then
			outcome="skipped: conflicts with $base"
			return
		fi
		behind=$(behind_by)
		if ! [[ "$behind" =~ ^[0-9]+$ ]]; then
			outcome="gave up: could not compare its head with $base"
			return
		fi
		if ((behind > 0)); then
			say "#$pr at ${sha:0:7} is $behind behind $base: updating its branch"
			if ! said=$(gh pr update-branch "$pr" 2>&1); then
				outcome="gave up: update-branch failed: $(first_line "$said")"
				return
			fi
			was=$sha
			moved=0
			for ((asks = 0; asks < 30; asks++)); do
				read_pr "$pr" && [[ "$sha" != "$was" ]] && moved=1 && break
				sleep "$poll"
			done
			if ((moved == 0)); then
				outcome="gave up: update-branch did not move its head"
				return
			fi
		fi

		say "#$pr at ${sha:0:7}: waiting for CI"
		said=$("$here/ci_wait.sh" "$pr" 2>&1)
		status=$?
		printf '%s\n' "$said" | sed 's/^/  /'
		if ((status == 1)); then
			red=$(grep -E '^[a-z]+  ' <<<"$said" | awk -F'  ' '{ print $2 }' | paste -sd, - | sed 's/,/, /g')
			outcome="red: ${red:-CI failed}"
			return
		elif ((status != 0)); then
			said=$(grep -m1 '^ci-wait: ' <<<"$said")
			outcome="gave up: ${said:-tools/ci_wait.sh exited $status}"
			outcome=${outcome/gave up: ci-wait: /gave up: }
			return
		fi

		# Green: on this head, and with the base where it was? Only then is it merged.
		was=$sha
		if ! read_pr "$pr"; then
			outcome="gave up: gh stopped answering for it"
			return
		fi
		if [[ "$sha" != "$was" || "$said" != *" at ${sha:0:7}:"* ]]; then
			why="its head moved during CI"
		elif [[ "$state" != OPEN || "$draft" == true || "$mergeable" == CONFLICTING ]]; then
			continue
		elif ! behind=$(behind_by) || ! [[ "$behind" =~ ^[0-9]+$ ]]; then
			outcome="gave up: could not compare its head with $base"
			return
		elif ((behind > 0)); then
			why="$base moved during CI"
		elif said=$(gh pr merge "$pr" --squash --match-head-commit "$sha" 2>&1); then
			gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/$branch" >/dev/null 2>&1 ||
				say "#$pr: could not delete its branch $branch on the remote"
			say "#$pr merged at ${sha:0:7}"
			outcome="merged"
			return
		else
			why="the merge was refused: $(first_line "$said")"
			read_pr "$pr" || true
		fi
		say "#$pr: $why"
	done
	outcome="gave up: after $rounds rounds, ${why:-it never came to a merge}"
}

report=()
unmerged=0
for pr in "$@"; do
	outcome=''
	ride "$pr"
	[[ "$outcome" == merged ]] || unmerged=1
	report+=("merge-train: #$pr $outcome")
done
printf '%s\n' "${report[@]}"
exit "$unmerged"
