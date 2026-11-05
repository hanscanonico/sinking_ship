#!/usr/bin/env bash
#
# `make guard-check`: which of a `make fps` run's once-a-second samples count
# (tools/lib/fps_samples.awk), against made-up logs, so no engine runs. Only the
# match's count — those printed after the game's first-match-frame line, less the
# first SKIP of them — never a held ship's dressing; a run whose match never
# started keeps none and says so. And `make fps SKIP=` reaches tools/fps.sh as --skip.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fails=0
log=$(mktemp)
trap 'rm -f "$log"' EXIT

# The samples kept from the log, one line, space-separated, past the first SKIP (2).
kept() {
	awk -v skip="${1:-2}" -f tools/lib/fps_samples.awk "$log" | tr '\n' ' '
}

{
	for _ in 1 2 3 4 5; do echo "Project FPS: 981 (1.01 mspf)"; done
	echo "first match frame 342.5 s after launch"
	for fps in 30 20 4 5 3 4; do echo "Project FPS: $fps (250.00 mspf)"; done
} >"$log"
[[ $(kept) == "4 5 3 4 " ]] || {
	echo "fps-samples-check: a held dressing's samples counted: kept $(kept)" >&2
	fails=1
}

# A longer skip (make fps SKIP=, past a ship's background stretch build) drops that many
# of the match's samples, counted from its first frame, not from launch.
[[ $(kept 4) == "3 4 " ]] || {
	echo "fps-samples-check: SKIP=4 kept $(kept 4), not the match's last two samples" >&2
	fails=1
}

# make fps hands SKIP= to tools/fps.sh, as it does SEED, SEATS and SECONDS.
recipe=$(make -s -n fps SKIP=150 2>/dev/null)
if [[ $recipe != *"tools/fps.sh"*"--skip=150"* ]]; then
	echo "fps-samples-check: make fps SKIP=150 does not pass --skip=150 to tools/fps.sh" >&2
	fails=1
fi

for _ in 1 2 3 4 5 6 7 8; do echo "Project FPS: 981 (1.01 mspf)"; done >"$log"
if out=$(kept 2>&1); then
	echo "fps-samples-check: a run whose match never started passed, keeping $out" >&2
	fails=1
fi
exit "$fails"
