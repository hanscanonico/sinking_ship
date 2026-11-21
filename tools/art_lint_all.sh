#!/usr/bin/env bash
#
# `make art-lint` and `make art-lint SHIP=NAME`: the lint dealt over several engines
# side by side, as CI's art-lint jobs deal it (.github/workflows/verify.yml) — in one
# engine the whole lint is the two Titanics' checks one after another, 43 minutes of
# them on a CI runner (tools/art_lint_costs.tsv), behind every local gate that touched
# the art.
#
# Usage:  tools/art_lint_all.sh          # the whole lint
#         tools/art_lint_all.sh SHIP     # that ship's alone, which plays no match
#
# The whole lint is the fleet's ships but the Titanics in one engine (SKIP=…
# MATCH=no), what plays a match in two more (MATCH=K/2), and each Titanic in parts
# (SHIP=NAME PART=K/N): the same checks as the one engine's, each once. A ship alone
# is her parts when she is a Titanic, one engine otherwise.
#
# How many parts follows the machine's test slots (TEST_SLOTS, else half the cores,
# as tools/test_slot.sh counts them): every engine takes one, so no more run at once
# than the machine allows whatever is asked for here. A Titanic's last part is her
# open spans alone, a minute; each of the others builds her and takes an even share of
# the rest, and those are the long engines — the traced one's 38 minutes of checks and
# the small one's 10 on the Windows box, where the fleet's ships and the match's
# shares take a minute or two each. So the long parts are one fewer than the slots,
# a quarter of them the small Titanic's, and the short engines pass through the slot
# left over. Alone, a Titanic's long parts are as many as the slots — sixteen parts at
# most for the traced one and four for the small one, as CI has them — and with one
# slot she is one engine.
#
# Their output comes as they write it, each line prefixed with what it checks; every
# engine runs to its end, and the last line names each that failed.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if (($# > 1)); then
	echo "art-lint: usage: tools/art_lint_all.sh [SHIP]" >&2
	exit 2
fi
only="${1-}"

# The ships linted in parts, each with the most parts she is worth.
parted=(titanic:16 small_titanic:4)

if [[ -n "${TEST_SLOTS-}" ]]; then
	if [[ ! "$TEST_SLOTS" =~ ^[1-9][0-9]*$ ]]; then
		echo "art-lint: TEST_SLOTS takes a count of 1 or more, not '$TEST_SLOTS'" >&2
		exit 2
	fi
	slots="$TEST_SLOTS"
else
	cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"
	slots=$((${cores:-2} / 2))
	((slots >= 1)) || slots=1
fi

# $1 held between $2 and $3.
clamp() {
	local n="$1"
	((n >= $2)) || n="$2"
	((n <= $3)) || n="$3"
	echo "$n"
}

# The parts ship $1 goes in, $2 the most she is worth: her long parts and one more,
# her open spans'.
parts_of() {
	local long small
	if [[ -n "$only" ]]; then
		((slots > 1)) || {
			echo 1
			return
		}
		long="$slots"
	else
		small=$(((slots + 1) / 4))
		((small >= 1)) || small=1
		long="$small"
		[[ "$1" == titanic ]] && long=$((slots - 1 - small))
	fi
	clamp $((long + 1)) 2 "$2"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Engines waiting for a slot or for memory say so once between them.
export TEST_SLOT_NOTICE_ONCE="$WORK/slot-notice"

labels=()
pids=()
# One engine, labelled $1, over the make variables that follow.
start() {
	local label="$1"
	shift
	make --no-print-directory art-lint "$@" 2>&1 | sed "s|^|[$label] |" &
	labels+=("$label")
	pids+=("$!")
}

# The longest first: slots go to whoever asks first.
skip=""
for entry in "${parted[@]}"; do
	ship="${entry%%:*}"
	skip+="${skip:+,}$ship"
	[[ -z "$only" || "$only" == "$ship" ]] || continue
	of="$(parts_of "$ship" "${entry#*:}")"
	for ((k = 1; k <= of; k++)); do
		start "$ship $k/$of" SHIP="$ship" PART="$k/$of"
	done
done
if [[ -z "$only" ]]; then
	start "match 1/2" MATCH=1/2
	start "match 2/2" MATCH=2/2
	start ships SKIP="$skip" MATCH=no
elif ((${#pids[@]} == 0)); then
	start "$only" SHIP="$only" PART=1/1
fi

failed=()
for i in "${!pids[@]}"; do
	wait "${pids[$i]}" || failed+=("${labels[$i]}")
done
if ((${#failed[@]})); then
	echo "art-lint: FAILED in $(printf '%s, ' "${failed[@]}" | sed 's/, $//')" >&2
	exit 1
fi
echo "art-lint: every part OK (${#pids[@]} engines)"
