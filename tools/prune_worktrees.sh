#!/usr/bin/env bash
#
# The worktrees whose work is done: every worktree of this repo but the main checkout
# that is on a branch whose pull request is merged and that holds nothing of its own —
# no change to a tracked file but the line endings an engine import rewrites, nothing
# staged, no untracked file, no commit the merged PR did not carry, nothing under
# captures/ (ignored, and gone with the worktree). It names each, and with --remove
# removes it (git worktree remove --force, as import churn counts as a change to git)
# and deletes its local branch. Every other worktree is named with why it stays: a
# detached one, as no PR says when it is done; one whose branch has an open PR, or
# none merged, or one merged under GRACE_MINUTES ago, as the session that merged it may
# be cleaning up after it still; one holding work.
#
# Asks gh for the repo's pull requests. Usage:  tools/prune_worktrees.sh [--remove]

set -uo pipefail

remove=0
case "${1-}" in
--remove) remove=1 ;;
'') ;;
*)
	echo "prune-worktrees: usage: tools/prune_worktrees.sh [--remove]" >&2
	exit 2
	;;
esac

main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)") || exit 1
GRACE_MINUTES=120

# Each merged PR as "branch<TAB>head sha<TAB>number<TAB>minutes since its merge", the
# newest first, and the branches with a PR open.
merged=$(gh pr list --state merged --limit 1000 --json headRefName,headRefOid,number,mergedAt \
	--jq '.[] | "\(.headRefName)\t\(.headRefOid)\t\(.number)\t\((now - (.mergedAt | fromdateiso8601)) / 60 | floor)"') || {
	echo "prune-worktrees: gh could not list the merged pull requests" >&2
	exit 1
}
open=$(gh pr list --state open --limit 1000 --json headRefName --jq '.[].headRefName') || {
	echo "prune-worktrees: gh could not list the open pull requests" >&2
	exit 1
}

# Why worktree $1, on branch $2 with merged PR head $3 (number $4), stays; nothing when
# it holds no work of its own.
holds() {
	local tree=$1 head=$3 number=$4
	if ! git -C "$tree" cat-file -e "$head^{commit}" 2>/dev/null; then
		git -C "$tree" fetch -q origin "refs/pull/$number/head" 2>/dev/null
	fi
	git -C "$tree" merge-base --is-ancestor HEAD "$head" 2>/dev/null ||
		{ echo "commits PR #$number did not carry"; return; }
	git -C "$tree" diff --quiet --ignore-cr-at-eol 2>/dev/null || { echo "changes"; return; }
	git -C "$tree" diff --cached --quiet --ignore-cr-at-eol 2>/dev/null ||
		{ echo "staged changes"; return; }
	[[ -z "$(git -C "$tree" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]] ||
		{ echo "untracked files"; return; }
	[[ -z "$(ls -A "$tree/captures" 2>/dev/null | head -1)" ]] || { echo "files under captures/"; return; }
}

done_count=0
kept_count=0
tree='' branch='' detached=0
report() {
	[[ -z "$tree" || "$tree" == "$main" ]] && return
	local why='' line head number minutes
	if ((detached)); then
		why="detached"
	elif grep -qxF "$branch" <<<"$open"; then
		why="PR open"
	else
		line=$(awk -F'\t' -v b="$branch" '$1 == b { print; exit }' <<<"$merged")
		if [[ -z "$line" ]]; then
			why="no merged PR"
		else
			IFS=$'\t' read -r _ head number minutes <<<"$line"
			if ((minutes < GRACE_MINUTES)); then
				why="PR #$number merged $minutes min ago"
			else
				why=$(holds "$tree" "$branch" "$head" "$number")
			fi
		fi
	fi
	if [[ -n "$why" ]]; then
		kept_count=$((kept_count + 1))
		echo "stays   $tree ($why)"
		return
	fi
	done_count=$((done_count + 1))
	if ((remove)); then
		if git -C "$main" worktree remove --force "$tree" 2>/dev/null; then
			git -C "$main" branch -D -q "$branch" 2>/dev/null
			echo "removed $tree (PR #$number merged; branch $branch deleted)"
		else
			echo "failed  $tree (PR #$number merged, but git could not remove it: a program has a file open there?)"
		fi
	else
		echo "done    $tree (PR #$number merged)"
	fi
}

while IFS= read -r entry; do
	case "$entry" in
	"worktree "*)
		report
		tree=${entry#worktree } branch='' detached=0
		;;
	"branch refs/heads/"*) branch=${entry#branch refs/heads/} ;;
	detached) detached=1 ;;
	esac
done < <(git -C "$main" worktree list --porcelain)
report

if ((remove)); then
	git -C "$main" worktree prune
	echo "prune-worktrees: $done_count removed, $kept_count stay"
else
	echo "prune-worktrees: $done_count done, $kept_count stay; --remove removes the done ones"
fi
