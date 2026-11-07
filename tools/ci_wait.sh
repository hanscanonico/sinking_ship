#!/usr/bin/env bash
#
# Waits for a pull request's CI to finish, then says how it went in a few lines: how
# many checks passed, one line for each check that did not, and for a failed job the
# lines of its log that say what failed — lint errors, GUT's failed tests, script
# errors. Run it in the background and read its one short report, rather than asking
# `gh pr checks` again and again. The PR is the number given, else the current
# branch's.
#
# It asks every CI_WAIT_POLL seconds (30), for CI_WAIT_MINUTES (90) at most, and takes
# CI as finished once two answers in a row hold no pending check, as a job that needs
# others (verify) is only reported once they end. A head that still has no check after
# CI_WAIT_GRACE minutes (3), two answers in a row, has it ask why, as GitHub runs no CI
# at all on a PR that conflicts with its base: rather than wait out the time, it says so
# in one line when the PR conflicts, when no workflow ran for the head (skipped), or
# when every run on it ended without a check. Exits 0 when every check passed or was
# skipped, 1 when one failed or was cancelled, 3 when the time ran out first, 4 when no
# CI is coming for the head, 2 when there is no such PR.
#
# Usage:  tools/ci_wait.sh [PR]

set -uo pipefail

poll=${CI_WAIT_POLL:-30}
minutes=${CI_WAIT_MINUTES:-90}
grace=${CI_WAIT_GRACE:-3}
pr=${1-}
if [[ -z "$pr" ]]; then
	pr=$(gh pr view --json number --jq .number 2>/dev/null) || {
		echo "ci-wait: this branch has no PR: give its number" >&2
		exit 2
	}
fi
if ! [[ "$pr" =~ ^[0-9]+$ ]] || ! gh pr view "$pr" --json number >/dev/null 2>&1; then
	echo "ci-wait: no PR '$pr'. Usage: tools/ci_wait.sh [PR]" >&2
	exit 2
fi

# The PR's checks, one a line: bucket<TAB>name<TAB>link; nothing while none are reported.
checks() {
	gh pr checks "$pr" --json bucket,name,link --jq '.[] | "\(.bucket)\t\(.name)\t\(.link)"' 2>/dev/null
}

# The lines of failed job $2 of run $1 that say what failed, its timestamps and colours
# taken off (gh writes a colour's escape either as ESC or as the text "^[").
failed_lines() {
	local esc=$'\033'
	gh run view "$1" --job "$2" --log-failed 2>/dev/null |
		cut -f3- | sed -E "s/^[0-9T:.-]+Z //; s/(${esc}|\^\[)\[[0-9;]*m//g" |
		grep -E '\[Failed\]|^- test_|failing tests|Error|error:|SCRIPT ERROR|res://tests/[^ ]*\.gd|FAILED' |
		grep -v -e '##\[error\]Process completed' | awk '!seen[$0]++' | head -40
}

# Why the head has no check past the grace. Returns while a workflow run for it is still
# on its way, or while GitHub has not yet worked out whether the PR merges (for four asks
# more); else says why no CI is coming and exits 4. gh finds a commit's runs by its whole
# SHA only.
unsure=0
no_ci() {
	local info sha state base branch runs
	info=$(gh pr view "$pr" --json headRefOid,mergeable,baseRefName,headRefName \
		--jq '"\(.headRefOid)\t\(.mergeable)\t\(.baseRefName)\t\(.headRefName)"' 2>/dev/null) || return 0
	IFS=$'\t' read -r sha state base branch <<<"$info"
	[[ -n "$sha" ]] || return 0
	runs=$(gh run list --commit "$sha" --json status,name,conclusion \
		--jq '.[] | "\(.status)\t\(.name)\t\(.conclusion)"' 2>/dev/null) || return 0
	[[ -n "$runs" ]] && grep -qv '^completed' <<<"$runs" && return 0
	local at="ci-wait: PR #$pr at ${sha:0:7}"
	if [[ "$state" == CONFLICTING ]]; then
		echo "$at has no CI run: it conflicts with $base; merge $base"
	elif [[ -n "$runs" ]]; then
		echo "$at has no checks: every run on its head ended without one" \
			"($(awk -F'\t' '{ printf "%s%s: %s", (NR > 1 ? ", " : ""), $2, $3 }' <<<"$runs"))"
	elif [[ "$state" == UNKNOWN ]] && ((++unsure <= 4)); then
		return 0
	else
		echo "$at has no CI run: no workflow ran for its head (skipped?);" \
			"push a new commit, or start one: gh workflow run verify.yml --ref $branch"
	fi
	exit 4
}

deadline=$((SECONDS + minutes * 60))
ask_why=$((SECONDS + grace * 60))
settled=0
bare=0
while :; do
	now=$(checks)
	if [[ -n "$now" ]] && ! grep -q '^pending' <<<"$now"; then
		settled=$((settled + 1))
		((settled >= 2)) && break
	else
		settled=0
	fi
	# Two answers in a row, as a gh that fails answers nothing too.
	if [[ -n "$now" ]]; then bare=0; else bare=$((bare + 1)); fi
	if ((bare >= 2 && SECONDS >= ask_why)); then
		no_ci
	fi
	if ((SECONDS >= deadline)); then
		running=$(grep '^pending' <<<"$now" | cut -f2 | paste -sd, -)
		[[ -n "$now" ]] || running="no check reported yet"
		echo "ci-wait: PR #$pr still running after $minutes min: $running"
		exit 3
	fi
	sleep "$poll"
done

head=$(gh pr view "$pr" --json headRefOid --jq '.headRefOid[0:7]' 2>/dev/null)
total=$(grep -c . <<<"$now")
passed=$(grep -c -e '^pass' -e '^skipping' <<<"$now")
if ((passed == total)); then
	echo "ci-wait: PR #$pr at $head: all $total checks passed"
	exit 0
fi
echo "ci-wait: PR #$pr at $head: $passed of $total checks passed"
while IFS=$'\t' read -r bucket name link; do
	[[ "$bucket" == pass || "$bucket" == skipping ]] && continue
	echo "$bucket  $name  $link"
	[[ "$bucket" == fail && "$link" =~ /runs/([0-9]+)/job/([0-9]+) ]] || continue
	failed_lines "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" | sed 's/^/    /'
done <<<"$now"
exit 1
