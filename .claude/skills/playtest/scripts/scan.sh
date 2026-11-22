#!/usr/bin/env bash
# scan.sh OUT SHIP SEED SEATS MODE   one headless bots-only match through sim_scan.gd.
# MODE: normal | fast | survival | survival+fast. Run from an imported checkout.
# The log is OUT/SHIP_SEED_SEATS_MODE.log: `A|` anomaly, `C|` the ticks round a seat's
# first hits, `O|` each exit, `S|` summary. scan_totals.py OUT adds the logs up.
set -uo pipefail
out=$1 ship=$2 seed=$3 seats=$4 mode=$5
here="$(cd "$(dirname "$0")" && pwd)"
command -v cygpath >/dev/null && here="$(cygpath -m "$here")"
extra=()
case "$mode" in
fast) extra=(--fast) ;;
survival) extra=(--goal=survival) ;;
survival+fast) extra=(--goal=survival --fast) ;;
esac
mkdir -p "$out"
start=$(date +%s)
"$GODOT" --headless --no-header --path . -s "$here/sim_scan.gd" -- \
	--seed="$seed" --ship="$ship" --seats="$seats" "${extra[@]}" \
	>"$out/${ship}_${seed}_${seats}_${mode}.log" 2>&1
echo "$ship $seed $seats $mode $(($(date +%s) - start))s" >>"$out/done.txt"
