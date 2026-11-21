#!/usr/bin/env bash
#
# `make guard-check-changed` and `make ship-gen-check-changed`, verify-changed's share
# of two gates that hold tooling and generated data, not the game: the whole STEP when
# the branch's changes reach what it reads, and none, saying so, otherwise (#721 — the
# two took 34 minutes of every local gate on Windows, on branches that could not fail
# them). CI's `make verify` runs both whole on every PR, the net under a wrong skip.
#
#   guard-check     reads tools/, the Makefile, the goldens and CI fixtures, the test
#                   durations and the workflows. Skipped, the one check of its that
#                   reads the game's code still runs: tools/test_changed.py --check-sites.
#   ship-gen-check  reads tools/ (every generator and what they import), the Makefile's
#                   list of hulls, data/ (the ships, and the rules and sea the
#                   generators read) and tests/fixtures/ships/.
#
# Changes count from the merge-base with origin/main (or BASE), the working tree's own
# included, as tools/test_changed.py counts them.
#
# Usage:  tools/gate_changed.sh guard-check|ship-gen-check [BASE]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

step=${1-}
case "$step" in
guard-check) reads='^(tools/|Makefile$|tests/golden/|tests/fixtures/ci/|tests/durations\.tsv$|\.github/|\.gutconfig\.json$)' ;;
ship-gen-check) reads='^(tools/|Makefile$|data/|tests/fixtures/ships/)' ;;
*)
	echo "gate-changed: usage: tools/gate_changed.sh guard-check|ship-gen-check [BASE]" >&2
	exit 2
	;;
esac

base=${2:-origin/main}
merge_base=$(git merge-base HEAD "$base" 2>/dev/null) || {
	echo "$step-changed: no merge-base with $base — fetch it, or pass a BASE" >&2
	exit 1
}
changed=$({
	git diff --name-only --no-renames "$merge_base"
	git ls-files --others --exclude-standard
} 2>/dev/null | sort -u)

hit=$(grep -E "$reads" <<<"$changed")
if [[ -n "$hit" ]]; then
	echo "$step-changed: the whole $step, as what it reads changed: $(head -3 <<<"$hit" | paste -sd' ' -)$(
		(($(grep -c . <<<"$hit") > 3)) && printf ' …'
	)"
	exec make --no-print-directory "$step"
fi
echo "$step-changed: nothing $step reads changed — not run"
if [[ "$step" == guard-check ]]; then
	exec tools/test_changed.py --check-sites
fi
exit 0
