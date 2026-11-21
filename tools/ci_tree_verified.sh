#!/usr/bin/env bash
#
# Has CI already passed this very tree? What .github/workflows/main.yml asks of a
# commit pushed to main before it runs the gate on it. The merge train
# (tools/merge_train.sh) squash-merges a pull request only at a head that holds main's
# latest commit and is green, so the commit it leaves on main holds that head's tree,
# file for file — and the gate run again on it is the same 22 jobs over the same
# files, taking runners from the next pull request's run for six minutes: with the two
# side by side, more jobs than the 20 GitHub runs at once, a PR's run took ten to
# thirteen minutes where alone it takes six and a half (runs 44921495286,
# 44913311961, 44912089643).
#
# Verified means all of: the commit came from a merged pull request; that pull
# request's head commit holds the same tree; and a `verify` run for that head, on a
# pull_request event, ended in success. A head that held less than its base when it
# ran was tested merged with it, a tree of its own, and holds another tree than the
# commit on main does: it is not verified. Neither is a commit pushed straight to
# main.
#
# Prints `verified=true` or `verified=false` on stdout, for $GITHUB_OUTPUT, and why on
# stderr. Whatever it cannot find out — gh failing, GitHub not answering — is
# `verified=false`: the gate then runs whole, as it did before. Exits 0 either way, 2
# on a bad call. It runs only gh, which reads GH_TOKEN and, for the repository,
# GITHUB_REPOSITORY (OWNER/NAME; the checkout's own when unset).
#
# Usage:  tools/ci_tree_verified.sh SHA

set -uo pipefail

sha=${1-}
if [[ $# -ne 1 || ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
	echo "ci-tree-verified: usage: tools/ci_tree_verified.sh SHA, a commit's whole SHA" >&2
	exit 2
fi
repo=${GITHUB_REPOSITORY:-"{owner}/{repo}"}

no() {
	echo "ci-tree-verified: ${sha:0:8} is not verified: $1" >&2
	echo "verified=false"
	exit 0
}

tree_of() {
	gh api "repos/$repo/git/commits/$1" --jq .tree.sha
}

tree=$(tree_of "$sha") && [[ -n "$tree" ]] || no "gh could not read the commit"
pulls=$(gh api "repos/$repo/commits/$sha/pulls" \
	--jq '.[] | select(.merged_at != null) | "\(.number) \(.head.sha)"') ||
	no "gh could not list its pull requests"
[[ -n "$pulls" ]] || no "it comes from no merged pull request"

why=''
while read -r pr head; do
	head_tree=$(tree_of "$head") || {
		why+="; gh could not read #$pr's head"
		continue
	}
	if [[ "$head_tree" != "$tree" ]]; then
		why+="; #$pr's head ${head:0:8} holds another tree"
		continue
	fi
	run=$(gh api "repos/$repo/actions/workflows/verify.yml/runs?head_sha=$head&event=pull_request&status=success&per_page=1" \
		--jq '.workflow_runs[0].html_url // empty') || {
		why+="; gh could not list the runs of #$pr's head"
		continue
	}
	if [[ -z "$run" ]]; then
		why+="; #$pr's head ${head:0:8} holds its tree but has no green verify run"
		continue
	fi
	echo "ci-tree-verified: ${sha:0:8} holds the tree of #$pr's head ${head:0:8}, green in $run" >&2
	echo "verified=true"
	exit 0
done <<<"$pulls"
no "${why#; }"
