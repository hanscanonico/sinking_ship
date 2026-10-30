#!/usr/bin/env bash
#
# `make art-lint-changed`, verify-changed's art gate: `make art-lint` over what the
# branch's changes can reach. The whole lint when the art itself changed — scenes/art,
# the match scene that draws seats and cargo, the models and characters, the lint and
# its checks; the lint of each ship alone (SHIP=NAME, which plays no match) when only
# her data, her generator or her authoring scene changed; and none, saying so,
# otherwise. Changes count from the merge-base with origin/main (or BASE), the working
# tree's own included, as tools/test_changed.py counts them.
#
# Usage:  tools/art_lint_changed.sh [BASE]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

base=${1:-origin/main}
merge_base=$(git merge-base HEAD "$base" 2>/dev/null) || {
	echo "art-lint-changed: no merge-base with $base — fetch it, or pass a BASE" >&2
	exit 1
}
changed=$({
	git diff --name-only --no-renames "$merge_base"
	git ls-files --others --exclude-standard
} 2>/dev/null | sort -u)

# The lint reads the art's code, the scenes it draws a match with, and what they load.
art=$(grep -E '^(scenes/(art|match)/|assets/(models|characters)/|tools/(art_lint|boat_check|face_cells|furnishing_check|open_span_check|overhead_check|sinking_fx_check|structure_steel|underside_check|wreck_check)\.gd$)' <<<"$changed")
if [[ -n "$art" ]]; then
	echo "art-lint-changed: the whole lint, as the art changed: $(head -3 <<<"$art" | paste -sd' ' -)$(
		(($(grep -c . <<<"$art") > 3)) && printf ' …'
	)"
	exec make --no-print-directory art-lint
fi

# The ships whose own files changed: data/ships/NAME.tres, tools/gen_NAME.py,
# authoring/NAME/. A generator that is no ship's is shared by all of them.
ships=$(sed -nE 's#^(data/ships/([a-z0-9_]+)\.tres|tools/gen_([a-z0-9_]+)\.py|authoring/([a-z0-9_]+)/.+)$#\2\3\4#p' \
	<<<"$changed" | sort -u)
if [[ -z "$ships" ]]; then
	echo "art-lint-changed: nothing the art lint reads changed — no lint to run"
	exit 0
fi
for ship in $ships; do
	if [[ ! -e "data/ships/$ship.tres" ]]; then
		echo "art-lint-changed: the whole lint, as $ship is no ship of data/ships"
		exec make --no-print-directory art-lint
	fi
done
status=0
for ship in $ships; do
	echo "art-lint-changed: $ship's art alone, as her own files changed"
	make --no-print-directory art-lint SHIP="$ship" || status=1
done
exit "$status"
