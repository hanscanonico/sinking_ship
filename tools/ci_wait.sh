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
# others (verify) is only reported once they end. Exits 0 when every check passed or
# was skipped, 1 when one failed or was cancelled, 3 when the time ran out first, 2
# when there is no such PR.
#
# Usage:  tools/ci_wait.sh [PR]

set -uo pipefail

poll=${CI_WAIT_POLL:-30}
minutes=${CI_WAIT_MINUTES:-90}
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

deadline=$((SECONDS + minutes * 60))
settled=0
while :; do
	now=$(checks)
	if [[ -n "$now" ]] && ! grep -q '^pending' <<<"$now"; then
		settled=$((settled + 1))
		((settled >= 2)) && break
	else
		settled=0
	fi
	if ((SECONDS >= deadline)); then
		echo "ci-wait: PR #$pr still running after $minutes min:" \
			"$(grep '^pending' <<<"$now" | cut -f2 | paste -sd, -)"
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
