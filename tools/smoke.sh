#!/usr/bin/env bash
#
# `make smoke`: the capture sweep a reviewer or the qa agent reads — today the water
# moments of one match. It plays the match once headless (`make match`, which writes
# nothing) to read its transcript, plans its shots from the lines there, and takes them
# one after another with `make capture`, each into OUT/<nn>_<name>.png:
#
#   01 eyes_early     through seat 0's eyes 5 s in, before any water, wherever it starts
#   02 flood_first    the observer from port, cells drawn, 4 s past the first "flooding"
#   03 flood_last     the observer from port 4 s past the last "flooding"
#   04 crate          through seat 0's eyes at the first "crate n lost"
#   05 seat_out       through the eyes of the first seat out, 1 s before it goes
#   06 late           the observer 5 s before the match ends (or at the last water line)
#   07 mid_sinking    the observer, cells drawn, half way from the first flooding to the end
#
# A shot whose moment the transcript lacks is left out. Every capture takes the window
# lock itself (tools/window_lock.sh): the sweep takes none of its own, never raises or
# focuses a window and never ends a process. It stops at the first capture that fails,
# naming the shot, and keeps the frames taken before it.
#
# Usage (environment, as `make smoke` passes it):
#   SEED=1701  SHIP=  (the match's default)  FAST=1  MAX=  (every shot)  DRY=1  OUT=captures/smoke
# DRY=1 plays the headless match to plan, prints the planned `make capture` commands and
# exits 0 without opening a window.

set -uo pipefail
export LC_ALL=C

cd "$(dirname "$0")/.." || exit 1

SEED=${SEED:-1701}
SHIP=${SHIP:-}
FAST=${FAST:-1}
MAX=${MAX:-}
DRY=${DRY:-}
OUT=${OUT:-captures/smoke}
MAKE=${MAKE:-make}

[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"
if [[ -n "$MAX" && ! "$MAX" =~ ^[0-9]+$ ]]; then
	echo "smoke: MAX takes a whole number of shots, not $MAX" >&2
	exit 1
fi

# The knobs every make call of the sweep shares.
knobs=("SEED=$SEED")
[[ -n "$SHIP" ]] && knobs+=("SHIP=$SHIP")
[[ -n "$FAST" && "$FAST" != 0 ]] && knobs+=("FAST=1")

echo "smoke: reading the transcript: $MAKE match ${knobs[*]}" >&2
if ! transcript=$("$MAKE" -s --no-print-directory match "${knobs[@]}"); then
	echo "smoke: make match ${knobs[*]} failed; no shots planned" >&2
	exit 1
fi

# Seconds of match time from a line's leading mm:ss.t, or nothing.
seconds() {
	awk '{ split($1, t, ":"); printf "%.1f", t[1] * 60 + t[2] }' <<<"$1"
}
# The match time, in seconds, plus [param 2] (negative for before), never below 0 and
# never past $cap, a second before the match ends: past it a capture shows the results.
cap=""
offset() {
	awk -v s="$1" -v d="$2" -v cap="$cap" \
		'BEGIN { v = s + d; if (v < 0) v = 0; if (cap != "" && v > cap) v = cap; printf "%.1f", v }'
}
stamp='^[0-9][0-9]:[0-9][0-9]\.[0-9] '

flooding=$(grep -E "$stamp.* flooding$" <<<"$transcript")
first_flood=$(head -n 1 <<<"$flooding")
last_flood=$(tail -n 1 <<<"$flooding")
crate=$(grep -E -m 1 "$stamp""crate [0-9]+ lost" <<<"$transcript")
seat_out=$(grep -E -m 1 "$stamp""seat [0-9]+ out" <<<"$transcript")
ended=$(grep -E -m 1 "^(winner seat [0-9]+|draw|all out|unfinished) at " <<<"$transcript")
last_water=$(grep -E "$stamp.*( flooding| full|water through .*)$" <<<"$transcript" | tail -n 1)

end_at=""
if [[ -n "$ended" ]]; then
	end_at=$(seconds "$(sed -E 's/.* at ([0-9:.]+) .*/\1/' <<<"$ended")")
	grep -q '^unfinished' <<<"$ended" || cap=$(offset "$end_at" -1)
	end_at=$(offset "$end_at" -5)
elif [[ -n "$last_water" ]]; then
	end_at=$(seconds "$last_water")
fi

# The plan: one shot per line, "name|what it shows|make capture's knobs".
plan=()
plan+=("eyes_early|seat 0's eyes 5 s in, before any water, wherever it starts|AT=5 EYE=0")
if [[ -n "$first_flood" ]]; then
	plan+=("flood_first|the observer from port at the first flooding ($(cut -d' ' -f2 <<<"$first_flood")) + 4 s, cells drawn|AT=$(offset "$(seconds "$first_flood")" 4) SIDE=port CELLS=1")
	plan+=("flood_last|the observer from port at the last flooding ($(cut -d' ' -f2 <<<"$last_flood")) + 4 s|AT=$(offset "$(seconds "$last_flood")" 4) SIDE=port")
fi
if [[ -n "$crate" ]]; then
	plan+=("crate|seat 0's eyes at the first crate lost ($(cut -d' ' -f2-3 <<<"$crate"))|AT=$(offset "$(seconds "$crate")" 0) EYE=0")
fi
if [[ -n "$seat_out" ]]; then
	seat=$(sed -E 's/^[^ ]+ seat ([0-9]+) out.*/\1/' <<<"$seat_out")
	plan+=("seat_out|seat $seat's eyes 1 s before it goes out|AT=$(offset "$(seconds "$seat_out")" -1) EYE=$seat")
fi
if [[ -n "$end_at" ]]; then
	plan+=("late|the observer late, at ${end_at} s|AT=$end_at")
	if [[ -n "$first_flood" ]]; then
		mid=$(awk -v a="$(seconds "$first_flood")" -v b="$end_at" 'BEGIN { printf "%.1f", (a + b) / 2 }')
		plan+=("mid_sinking|the observer at mid-sinking, ${mid} s, cells drawn|AT=$mid CELLS=1")
	fi
fi

if [[ -n "$MAX" ]] && ((${#plan[@]} > MAX)); then
	plan=("${plan[@]:0:MAX}")
fi

taken=()
n=0
for shot in "${plan[@]}"; do
	n=$((n + 1))
	IFS='|' read -r name what args <<<"$shot"
	file=$(printf '%s/%02d_%s.png' "$OUT" "$n" "$name")
	# shellcheck disable=SC2206 # the knobs are words, split on purpose
	command=("$MAKE" --no-print-directory capture "${knobs[@]}" $args "CAPTURE=$file")
	if [[ -n "$DRY" && "$DRY" != 0 ]]; then
		printf '# %02d %s: %s\n' "$n" "$name" "$what"
		echo "${command[*]}"
		continue
	fi
	echo "smoke: shot $n/${#plan[@]} $name — ${command[*]}" >&2
	if ! "${command[@]}"; then
		echo "smoke: shot $n ($name: $what) failed; frames kept so far are listed below" >&2
		for line in ${taken[@]+"${taken[@]}"}; do echo "$line"; done
		exit 1
	fi
	taken+=("$file  $what")
done

[[ -n "$DRY" && "$DRY" != 0 ]] && exit 0
for line in ${taken[@]+"${taken[@]}"}; do echo "$line"; done
