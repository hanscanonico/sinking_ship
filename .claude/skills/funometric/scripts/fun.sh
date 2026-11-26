#!/usr/bin/env bash
# fun.sh OUT SHIP SEED SEATS MODE     one bots-only match through fun_scan.gd
# fun.sh OUT replay PATH              a recorded match (make play keeps them under
#                                     captures/play/home/LastOneDry/replays) re-run
# MODE: normal | fast | survival | survival+fast. Run from an imported checkout.
# The log is OUT/NAME.fun; fun_report.py OUT/*.fun judges them.
set -uo pipefail
out=$1
here="$(cd "$(dirname "$0")" && pwd)"
command -v cygpath >/dev/null && here="$(cygpath -m "$here")"
mkdir -p "$out"
if [ "$2" = replay ]; then
	path=$3
	command -v cygpath >/dev/null && path="$(cygpath -m "$path")"
	name="played_$(basename "$3" .replay)"
	args=(--replay="$path")
else
	ship=$2 seed=$3 seats=$4 mode=$5
	name="${ship}_${seed}_${seats}_${mode}"
	args=(--seed="$seed" --ship="$ship" --seats="$seats")
	case "$mode" in
	fast) args+=(--fast) ;;
	survival) args+=(--goal=survival) ;;
	survival+fast) args+=(--goal=survival --fast) ;;
	esac
fi
"$GODOT" --headless --no-header --path . -s "$here/fun_scan.gd" -- "${args[@]}" 2>&1 |
	grep -v '^\[godot_ai' >"$out/$name.fun"
echo "$out/$name.fun"
