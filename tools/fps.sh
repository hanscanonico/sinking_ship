#!/usr/bin/env bash
#
# `make fps`: how fast the game draws a bots-only match, windowed, with nothing
# else in the way. The game runs with V-Sync off and its window always on top,
# silent (the Dummy driver), and prints its own frame rate once a second (the
# engine's --print-fps); the first SKIP samples, the loading and the countdown's
# first seconds, are dropped and the rest summed up: their median, their 10th
# percentile (interpolated) and the 1-minute load average as the run starts and
# ends. A bot plays the local seat, so the view is its first-person eyes unless
# ARGS says --observer.
#
# A window the system is not drawing — covered, minimised, on another Space —
# idles at a flat rate (about 145 fps on a Mac) rather than drawing: when the kept
# samples span 2 fps or less, slowest to fastest, the run prints NOT DRAWING and
# fails, and is to be run again with the window in sight.
#
# One game window at a time on a shared machine: an agent takes the window lock
# around each run, as around `make capture`, and releases it also on failure —
#   until mkdir /tmp/sinking_ship_window.lock 2>/dev/null; do sleep 5; done
#   make fps …; rmdir /tmp/sinking_ship_window.lock
#
# Usage:  tools/fps.sh [--seed=4] [--seats=8] [--seconds=40] [--resolution=1440x900]
#                      [--project=DIR] [-- MORE USER ARGS]
#
# --project runs another checkout of the game (an A/B against main) with this
# script's rules. The engine runs under `timeout`, which ends it after --seconds,
# and kills it KILL_AFTER seconds later if it has not quit by then.

set -uo pipefail
# Decimal points, whatever the machine's locale writes numbers with.
export LC_ALL=C

source "$(dirname "$0")/lib/require_godot.sh" || exit 1

cd "$(dirname "$0")/.." || exit 1

require_godot fps

SEED=4
SEATS=8
SECONDS_RUN=40
RESOLUTION=1440x900
PROJECT=.
SKIP=8
KILL_AFTER=10
EXTRA=()

while (($#)); do
	case "$1" in
	--seed=*) SEED="${1#*=}" ;;
	--seats=*) SEATS="${1#*=}" ;;
	--seconds=*) SECONDS_RUN="${1#*=}" ;;
	--resolution=*) RESOLUTION="${1#*=}" ;;
	--project=*) PROJECT="${1#*=}" ;;
	--)
		shift
		EXTRA=("$@")
		break
		;;
	*)
		echo "fps: unknown argument $1" >&2
		exit 2
		;;
	esac
	shift
done

load() {
	if [[ -r /proc/loadavg ]]; then
		cut -d' ' -f1 /proc/loadavg
	else
		sysctl -n vm.loadavg | awk '{print $2}'
	fi
}

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

START_LOAD=$(load)
# timeout's own status (124) is how every run ends: the run is judged by its samples.
timeout -k "$KILL_AFTER" "$SECONDS_RUN" "$GODOT" --path "$PROJECT" --disable-vsync --print-fps \
	--always-on-top --resolution "$RESOLUTION" --audio-driver Dummy -- \
	--seed="$SEED" --seats="$SEATS" --autoplay ${EXTRA[@]+"${EXTRA[@]}"} >"$LOG" 2>&1
END_LOAD=$(load)

grep -o 'Project FPS: [0-9]*' "$LOG" | awk '{print $3}' | tail -n +$((SKIP + 1)) | sort -n |
	awk -v start="$START_LOAD" -v end="$END_LOAD" -v args="${EXTRA[*]-}" \
		-v seed="$SEED" -v seats="$SEATS" '
	{ fps[NR] = $1 }
	END {
		n = NR
		if (n < 5) {
			printf "fps: only %d samples kept: the game did not run long enough\n", n > "/dev/stderr"
			exit 1
		}
		# Sorted ascending: the median, and the 10th percentile between ranks.
		median = n % 2 ? fps[(n + 1) / 2] : (fps[n / 2] + fps[n / 2 + 1]) / 2
		rank = 1 + 0.1 * (n - 1)
		low = int(rank)
		p10 = fps[low] + (rank - low) * (fps[low + 1] - fps[low])
		printf "seed %s seats %s %s: median %.1f fps, p10 %.1f, min %d, max %d, %d samples, " \
			"load %s -> %s\n", seed, seats, args, median, p10, fps[1], fps[n], n, start, end
		if (fps[n] - fps[1] <= 2) {
			print "fps: NOT DRAWING: the samples span 2 fps or less; keep the window in sight" \
				> "/dev/stderr"
			exit 1
		}
	}'
