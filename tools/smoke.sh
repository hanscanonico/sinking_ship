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
#   04 crate_afloat   eyes stood 8 m aft of the first crate afloat's starting point, feet
#                     2.5 m over its deck, looking at it, 2 s past "crate n afloat" (else
#                     the first crate lost, 2 s before "crate n lost")
#   05 seat_out       through the eyes of the first seat out, 1 s before it goes
#   06 late           the observer 5 s before the match ends (or at the last water line)
#   07 mid_sinking    the observer, cells drawn, half way from the first flooding to the end
#   08 saloon_filling eyes stood on the floor of the saloon (else of the cell the second
#                     "flooding" line names), at the middle of its cell, 8 s past that line
#   09 wader_cell     eyes stood in the cell where a seat first wades in a cell's water,
#                     feet 2.5 m from the seat inside the cell's box, looking at its feet,
#                     2 s after it first stands wet there (rings round it on that water)
#
# A crate's deck and a cell's floor come from the ship's layout, data/ships/<ship>.tres
# (the default match's ship when SHIP is empty): crate n is the layout's prop n, a cell
# its Cell_ block's low and high corners in ship space.
#
# The transcript names no wading, so shot 09 reads its seat, cell, moment and feet from
# the table of first waders below, measured from the sim's snapshots for each match it
# lists (seed, clock, ship): the first tick a seat's feet stand more than CellMap.DRY
# under the water of the cell they are in. A match the table lacks leaves it out, as
# does one whose transcript no longer floods that cell before then or has that seat out.
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
crate=$(grep -E -m 1 "$stamp""crate [0-9]+ afloat" <<<"$transcript")
crate_shift=2
crate_when="+ 2 s"
if [[ -z "$crate" ]]; then
	crate=$(grep -E -m 1 "$stamp""crate [0-9]+ lost" <<<"$transcript")
	crate_shift=-2
	crate_when="- 2 s"
fi
filling=$(grep -E -m 1 "$stamp""saloon flooding$" <<<"$flooding")
[[ -n "$filling" ]] || filling=$(sed -n 2p <<<"$flooding")
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

# The ship's layout: SHIP's, or the one the default match plays.
layout=""
if [[ -n "$SHIP" ]]; then
	layout="data/ships/$SHIP.tres"
else
	layout=$(sed -nE 's|.*path="res://(data/ships/[^"]+\.tres)".*|\1|p' data/match/default.tres | head -n 1)
fi
[[ -f "$layout" ]] || layout=""
# Where crate [param 1] starts, "x,y,z": the pos of the layout's prop of that index.
crate_at() {
	[[ -n "$layout" ]] || return 0
	awk -v want="$1" '
		/^props = / {
			n = 0
			while (match($0, /SubResource\("[^"]+"\)/)) {
				id = substr($0, RSTART + 13, RLENGTH - 15)
				if (n++ == want) { print id; exit }
				$0 = substr($0, RSTART + RLENGTH)
			}
		}' "$layout" | {
		read -r id || exit 0
		awk -v id="$id" '
			$0 ~ "^\\[sub_resource .*id=\"" id "\"\\]" { inside = 1; next }
			/^\[/ { inside = 0 }
			inside && /^pos = Vector3\(/ { sub(/^[^(]*/, ""); gsub(/[^0-9.,-]/, ""); print; exit }
		' "$layout"
	}
}
# The cell named [param 1] as "x,y,z|x,y,z": its floor's middle (the feet) and a point
# on its floor toward its far side across her (where the eyes look).
cell_feet() {
	[[ -n "$layout" ]] || return 0
	awk -v want="$1" '
		/^\[sub_resource .*id="Cell_/ { inside = 1; named = 0; low = ""; high = ""; next }
		/^\[/ { inside = 0 }
		inside && $0 == "name = &\"" want "\"" { named = 1 }
		inside && /^low = Vector3\(/ { low = $0 }
		inside && /^high = Vector3\(/ { high = $0 }
		inside && named && low != "" && high != "" {
			sub(/^[^(]*/, "", low); sub(/^[^(]*/, "", high)
			gsub(/[^0-9.,-]/, "", low); gsub(/[^0-9.,-]/, "", high)
			split(low, a, ","); split(high, b, ",")
			x = (a[1] + b[1]) / 2; z = (a[3] + b[3]) / 2
			printf "%.2f,%.2f,%.2f|%.2f,%.2f,%.2f\n", x, a[2], z, x, a[2], z + (b[3] - z) * 0.8
			exit
		}' "$layout"
}

# The first waders in a cell: "seed|fast|ship|seat|cell|seconds|x,y,z" — the seat's feet
# in ship space as it stands there. Measure a row again when the sim moves them.
first_waders=(
	"1701|1|steamer|7|hold_wing_s|157.3|4.50,-0.42,4.31"
)
# The feet to stand at in cell [param 1], "x,y,z", 2.5 m from [param 2], "x,y,z", along
# the cell's longer side toward its middle, kept 0.3 m inside its box; at the seat's
# height.
cell_near() {
	[[ -n "$layout" ]] || return 0
	awk -v want="$1" -v seat="$2" '
		/^\[sub_resource .*id="Cell_/ { inside = 1; named = 0; low = ""; high = ""; next }
		/^\[/ { inside = 0 }
		inside && $0 == "name = &\"" want "\"" { named = 1 }
		inside && /^low = Vector3\(/ { low = $0 }
		inside && /^high = Vector3\(/ { high = $0 }
		inside && named && low != "" && high != "" {
			sub(/^[^(]*/, "", low); sub(/^[^(]*/, "", high)
			gsub(/[^0-9.,-]/, "", low); gsub(/[^0-9.,-]/, "", high)
			split(low, a, ","); split(high, b, ","); split(seat, p, ",")
			x = p[1]; z = p[3]
			if (b[1] - a[1] >= b[3] - a[3]) {
				x += (p[1] < (a[1] + b[1]) / 2) ? 2.5 : -2.5
			} else {
				z += (p[3] < (a[3] + b[3]) / 2) ? 2.5 : -2.5
			}
			x = (x < a[1] + 0.3) ? a[1] + 0.3 : (x > b[1] - 0.3) ? b[1] - 0.3 : x
			z = (z < a[3] + 0.3) ? a[3] + 0.3 : (z > b[3] - 0.3) ? b[3] - 0.3 : z
			printf "%.2f,%.2f,%.2f\n", x, p[2], z
			exit
		}' "$layout"
}
ship_name=$(basename "${layout:-none}" .tres)
fast_key=0
[[ -n "$FAST" && "$FAST" != 0 ]] && fast_key=1
wader=""
for row in "${first_waders[@]}"; do
	IFS='|' read -r w_seed w_fast w_ship w_seat w_cell w_at w_feet <<<"$row"
	[[ "$w_seed" == "$SEED" && "$w_fast" == "$fast_key" && "$w_ship" == "$ship_name" ]] || continue
	flooded=$(grep -E -m 1 "$stamp$w_cell flooding$" <<<"$transcript")
	[[ -n "$flooded" ]] || continue
	awk -v f="$(seconds "$flooded")" -v w="$w_at" 'BEGIN { exit !(f < w) }' || continue
	gone=$(grep -E -m 1 "$stamp""seat $w_seat out" <<<"$transcript")
	if [[ -n "$gone" ]] && awk -v g="$(seconds "$gone")" -v w="$w_at" 'BEGIN { exit !(g <= w + 2) }'; then
		continue
	fi
	wader=$row
	break
done

# The plan: one shot per line, "name|what it shows|make capture's knobs".
plan=()
plan+=("eyes_early|seat 0's eyes 5 s in, before any water, wherever it starts|AT=5 EYE=0")
if [[ -n "$first_flood" ]]; then
	plan+=("flood_first|the observer from port at the first flooding ($(cut -d' ' -f2 <<<"$first_flood")) + 4 s, cells drawn|AT=$(offset "$(seconds "$first_flood")" 4) SIDE=port CELLS=1")
	plan+=("flood_last|the observer from port at the last flooding ($(cut -d' ' -f2 <<<"$last_flood")) + 4 s|AT=$(offset "$(seconds "$last_flood")" 4) SIDE=port")
fi
if [[ -n "$crate" ]]; then
	n_crate=$(cut -d' ' -f3 <<<"$crate")
	at=$(crate_at "$n_crate")
	if [[ -n "$at" ]]; then
		view=$(awk -F, '{ printf "FROM=%.2f,%.2f,%.2f LOOK=%.2f,%.2f,%.2f", $1 - 8, $2 + 2.5, $3, $1, $2, $3 }' <<<"$at")
		plan+=("crate_afloat|eyes 8 m aft of crate $n_crate at its $(cut -d' ' -f4 <<<"$crate") $crate_when|AT=$(offset "$(seconds "$crate")" "$crate_shift") $view")
	fi
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

if [[ -n "$filling" ]]; then
	cell=$(sed -E 's/^[^ ]+ (.*) flooding$/\1/' <<<"$filling")
	spot=$(cell_feet "$cell")
	if [[ -n "$spot" ]]; then
		plan+=("saloon_filling|eyes on $cell's floor at its flooding + 8 s|AT=$(offset "$(seconds "$filling")" 8) FROM=${spot%|*} LOOK=${spot#*|}")
	fi
fi

if [[ -n "$wader" ]]; then
	IFS='|' read -r w_seed w_fast w_ship w_seat w_cell w_at w_feet <<<"$wader"
	stand=$(cell_near "$w_cell" "$w_feet")
	if [[ -n "$stand" ]]; then
		plan+=("wader_cell|eyes in $w_cell 2.5 m from seat $w_seat, 2 s after it first wades there|AT=$(offset "$w_at" 2) FROM=$stand LOOK=$w_feet")
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
