#!/usr/bin/env bash
#
# Plays the game online with an agent at every seat: `make crew` brings up a --server on
# 127.0.0.1 and N sessions of `make play`, each a seat's (tools/play.sh), all on one
# CrewClock (scenes/game/crew_clock.gd): they run a frame at a time together, so while
# any one agent thinks over a turn the whole crew — the server's beats too — stands
# still, and nobody's connection falls silent. Each agent then takes its turns with
# `tools/crew.sh SEAT '<commands>'`, the commands and the answers those of tools/play.sh,
# and the crew plans and reports on one board.
#
#   make crew [N=2] [SEED=1701] [WS_PORT=47941] [RES=640x360] [HEADLESS=1]   in the
#       background: the server and N seats, Ada, Bea, Cal, Dee, Eve, Fay, Gus, Hal, each
#       on the server's Online screen under its name; until `tools/crew.sh quit`, or
#       PLAY_IDLE (900) seconds with no turn at a seat, which leaves that seat alone.
#       LANGS=fr,es,en plays seat 1 in French, seat 2 in Spanish, seat 3 in English,
#       and the list again from seat 4; every seat in English without it
#   tools/crew.sh 2 'click "Join"; until text "Ada" 300; shot room'   a turn at seat 2
#   tools/crew.sh say Bea 'joined ABCD; ready'     a line on the crew's board
#   tools/crew.sh board [FROM]                     the board, from line FROM on
#   tools/crew.sh free SEAT… | all                 the seat plays on while its agent
#                                                  thinks, holding nobody
#   tools/crew.sh hold SEAT… | all                 the crew waits on it again
#   tools/crew.sh status                           the seats up, each one's frames,
#                                                  and who the crew is waiting on
#   tools/crew.sh log [LINES]                      the tail of the server's log (40)
#   tools/crew.sh quit                             every seat and the server
#
# Turns at different seats may be taken at once, one shell per agent: each seat's
# session answers its own batch, and the crew moves on while every held seat has a
# batch running. A held seat whose batch is done holds the rest until its next batch
# comes — the match stands still for its agent — so keep turns short (`wait 60` and
# look, rather than `until over`) while others need the match to go on. A free seat
# (`free`, or FREE=1 for every seat from the start) holds nobody: between its batches
# its game plays on, what it holds held still, as a player's would who looked away.
# Free a seat that waits on the others — in the menus, or waiting on the board.
#
# The seats' windows share the one window lock, taken once for the crew (HEADLESS=1
# opens none and takes none: then `shot` fails, and the answers' text is all a seat
# sees). Each seat has its own user folder, CREW/seatK/home, as a play session does.
#
# Environment: CREW the crew's folder (captures/crew); PLAY_WAIT as for tools/play.sh.

set -uo pipefail
export LC_ALL=C

cd "$(dirname "$0")/.." || exit 1

CREW=${CREW:-$PWD/captures/crew}
NAMES=(Ada Bea Cal Dee Eve Fay Gus Hal)

# Ends the process whose system id is $1: a Godot's own, which Git Bash's kill does not
# reach on Windows.
stop_pid() {
	case "$(uname -s)" in
	MINGW* | MSYS* | CYGWIN*) taskkill //PID "$1" //F >/dev/null 2>&1 ;;
	*) kill "$1" 2>/dev/null ;;
	esac
}

# Every engine on the crew's clock stopped by the id it wrote there.
stop_clock() {
	shopt -s nullglob
	local file pid
	for file in "$CREW"/clock/*.clock; do
		read -r pid _ <"$file" && [[ "$pid" =~ ^[0-9]+$ ]] && stop_pid "$pid"
		rm -f "$file"
	done
}

serve() {
	local seats=2 seed=1701 port=47941
	for arg in "$@"; do
		case "$arg" in
		--seats=*) seats="${arg#*=}" ;;
		--seed=*) seed="${arg#*=}" ;;
		--port=*) port="${arg#*=}" ;;
		*)
			echo "crew: unknown argument $arg" >&2
			exit 2
			;;
		esac
	done
	if ! [[ "$seats" =~ ^[1-8]$ ]]; then
		echo "crew: N is a number of seats from 1 to 8, not '$seats'" >&2
		exit 2
	fi
	# shellcheck source=tools/lib/require_godot.sh
	source tools/lib/require_godot.sh
	require_godot "crew"
	mkdir -p "$CREW/clock"
	stop_clock
	echo "--- $(date '+%F %T') a crew of $seats on ws://127.0.0.1:$port ---" >>"$CREW/board.md"

	started=()
	# shellcheck disable=SC2329 # run by the trap
	cleanup() {
		for pid in ${started[@]+"${started[@]}"}; do
			kill "$pid" 2>/dev/null
		done
		stop_clock
	}
	trap cleanup EXIT

	ENGINE_GUARD_LIMIT="${PLAY_LIMIT:-3600}" tools/engine_guard.sh "$GODOT" --headless \
		--no-header --path . --audio-driver Dummy -- --server --port="$port" \
		--seed="$seed" --crew="$CREW/clock" >"$CREW/server.log" 2>&1 &
	started+=("$!")
	local waited=0
	until grep -q "listening on" "$CREW/server.log" 2>/dev/null; do
		if ((waited >= 120)); then
			echo "crew: the server never listened — its log:" >&2
			cat "$CREW/server.log" >&2
			exit 1
		fi
		sleep 0.5
		waited=$((waited + 1))
	done
	echo "crew: server on ws://127.0.0.1:$port, its log $CREW/server.log"

	local k name language languages=()
	IFS=, read -r -a languages <<<"${LANGS:-en}"
	((${#languages[@]})) || languages=(en)
	for ((k = 1; k <= seats; k++)); do
		name="${NAMES[k - 1]}"
		language="${languages[(k - 1) % ${#languages[@]}]}"
		rm -rf "$CREW/seat$k/in" "$CREW/seat$k/out" "$CREW/seat$k/free"
		mkdir -p "$CREW/seat$k"
		[[ "${FREE:-0}" == 1 ]] && touch "$CREW/seat$k/free"
		PLAY="$CREW/seat$k" PLAY_IDLE="${PLAY_IDLE:-900}" RES="${RES:-640x360}" \
			PLAY_HEADLESS="${HEADLESS:-0}" tools/play.sh serve \
			--connect="ws://127.0.0.1:$port" --name="$name" --language="$language" \
			--crew="$CREW/clock" >/dev/null 2>&1 &
		started+=("$!")
		echo "crew: seat $k is $name, in $language: tools/crew.sh $k '<commands>'"
	done
	for ((k = 1; k <= seats; k++)); do
		waited=0
		until [[ -f "$CREW/seat$k/ready" ]]; do
			if ((waited >= 600)); then
				echo "crew: seat $k never came up — its log:" >&2
				tail -n 20 "$CREW/seat$k/engine.log" >&2
				exit 1
			fi
			sleep 0.5
			waited=$((waited + 1))
		done
	done
	echo "crew: all $seats seats up; the board is $CREW/board.md"
	# The seats go when quit or left idle; the server stays for as long as one is up.
	local seat_pids=("${started[@]:1}")
	wait "${seat_pids[@]}"
	echo "crew: every seat has gone; the server's last lines:"
	grep -v '^\[godot_ai' "$CREW/server.log" | tail -n 15
}

status() {
	shopt -s nullglob
	local file pid frames name least=-1
	for file in "$CREW"/clock/*.clock; do
		read -r pid frames <"$file" || continue
		((least < 0 || frames < least)) && least=$frames
	done
	if ((least < 0)); then
		echo "crew: none on the clock in $CREW/clock"
		return
	fi
	for file in "$CREW"/clock/*.clock; do
		read -r pid frames <"$file" || continue
		name="$(basename "$file" .clock)"
		local seat="${name#seat}" who="$name"
		[[ "$seat" =~ ^[0-9]+$ ]] && who="$name (${NAMES[seat - 1]})"
		local note=""
		if [[ "$name" == seat* ]]; then
			local done_turns=("$CREW/$name"/out/*.txt) asked=("$CREW/$name"/in/*.txt)
			if [[ -f "$CREW/$name/free" ]]; then
				note="  · free"
			elif ((${#asked[@]} == ${#done_turns[@]})); then
				note="  · thinking: the crew waits on it"
			fi
		fi
		printf '%-14s pid %-7s frame %s%s\n' "$who" "$pid" "$frames" "$note"
	done
}

case "${1:-}" in
"")
	sed -n '3,/^# Environment/p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
	;;
serve)
	shift
	# One window lock for every seat's window: each seat's own play.sh finds it held.
	if [[ "${HEADLESS:-0}" == 1 || -n "${WINDOW_LOCK_HELD:-}" ]]; then
		serve "$@"
	else
		exec tools/window_lock.sh "$0" serve "$@"
	fi
	;;
say)
	if (($# < 3)); then
		echo "crew: say NAME TEXT" >&2
		exit 2
	fi
	mkdir -p "$CREW"
	echo "$(date '+%T') $2: ${*:3}" >>"$CREW/board.md"
	;;
board)
	[[ -f "$CREW/board.md" ]] || exit 0
	awk -v from="${2:-1}" 'NR >= from { print NR ": " $0 }' "$CREW/board.md"
	;;
status) status ;;
free | hold)
	shift_to="$1"
	shift
	if (($# == 0)); then
		echo "crew: $shift_to SEAT… | all" >&2
		exit 2
	fi
	seats=("$@")
	if [[ "$1" == "all" ]]; then
		seats=()
		for dir in "$CREW"/seat*/; do
			seats+=("$(basename "$dir" | sed 's/^seat//')")
		done
	fi
	for seat in "${seats[@]}"; do
		if [[ "$shift_to" == free ]]; then
			touch "$CREW/seat$seat/free"
		else
			rm -f "$CREW/seat$seat/free"
		fi
	done
	echo "crew: seat(s) ${seats[*]} $([[ "$shift_to" == free ]] && echo free || echo held)"
	;;
log) grep -v '^\[godot_ai' "$CREW/server.log" | tail -n "${2:-40}" ;;
quit)
	shopt -s nullglob
	for seat in "$CREW"/seat*/; do
		[[ -f "$seat/ready" ]] && PLAY="${seat%/}" tools/play.sh quit >/dev/null &
	done
	wait
	sleep 2
	stop_clock
	echo "crew: quit"
	;;
*)
	if ! [[ "$1" =~ ^[1-8]$ ]]; then
		echo "crew: unknown command $1 (tools/crew.sh for the list)" >&2
		exit 2
	fi
	seat="$1"
	shift
	PLAY="$CREW/seat$seat" exec tools/play.sh "$@"
	;;
esac
