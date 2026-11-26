#!/usr/bin/env bash
#
# Plays the game by turns, for an agent with no hands on the keys: `make play` opens
# the game held on its first frame, and each `tools/play.sh '<commands>'` after it is one
# turn — the commands are run, in order, and what a player would know then is printed:
# the words on the screen and where each button is, the local seat (and the ghost, while
# the view walks as one), what happened, the
# frames saved. Between turns the game stands still (PlayDriver, scenes/game/play_driver.gd,
# which lists the commands).
#
#   make play [SHIP=] [SEED=] [SEATS=] [FAST=1] [GOAL=] [RES=960x540] [ARGS=]   in the
#       background: the session, until `quit`, PLAY_IDLE seconds (600) with no turn, or
#       PLAY_LIMIT seconds (3600) in all
#   tools/play.sh 'until text "Play" 900; shot menu'       a turn; `;` or a newline
#       between commands
#   tools/play.sh 'click "Play"; until live 3000; shot start'
#   tools/play.sh 'hold move_up; wait 60; release all; turn 90; shot'
#   tools/play.sh quit                                      ends it; a no-op with none up
#   tools/play.sh - <<'EOF' … EOF                           a turn read from stdin
#
# A turn's answer names each frame it saved, PLAY/shots/NNNN_NAME.png: read it as an
# image. Any error or warning the engine printed during the turn is shown under it.
#
# The session is a player's own from the first launch: `serve` points the engine's user
# folder into PLAY/home (APPDATA on Windows, XDG_DATA_HOME elsewhere), so what it saves —
# settings, key bindings, replays, baked sinkings — is its own and never the settings or
# the replays of whoever owns the machine; the first turn's answer says where that is.
# It holds the one window lock (tools/window_lock.sh) for as long as it runs, as a
# capture does: quit it when done.
#
# Environment: PLAY the session's folder (captures/play), PLAY_WAIT the seconds a turn
# may take before the client gives up on it (600). Several sessions playing online
# together, an agent at each: `make crew` (tools/crew.sh).

set -uo pipefail
export LC_ALL=C

cd "$(dirname "$0")/.." || exit 1

PLAY=${PLAY:-$PWD/captures/play}
PLAY_WAIT=${PLAY_WAIT:-600}

if [[ "${1:-}" == "serve" ]]; then
	shift
	# shellcheck source=tools/lib/require_godot.sh
	source tools/lib/require_godot.sh
	require_godot "play"
	mkdir -p "$PLAY/home"
	rm -f "$PLAY/ready" "$PLAY/log_seen"
	case "$(uname -s)" in
	MINGW* | MSYS* | CYGWIN*) APPDATA="$(cygpath -w "$PLAY/home")" && export APPDATA ;;
	*) export XDG_DATA_HOME="$PLAY/home" ;;
	esac
	# PLAY_HEADLESS=1 draws nothing (make crew HEADLESS=1): no window, so no window lock,
	# and a `shot` fails.
	lock=(tools/window_lock.sh)
	view=(--resolution "${RES:-960x540}")
	if [[ "${PLAY_HEADLESS:-0}" == 1 ]]; then
		lock=()
		view=(--headless)
	fi
	ENGINE_GUARD_LIMIT="${PLAY_LIMIT:-3600}" ENGINE_GUARD_EARLY=1 \
		${lock[@]+"${lock[@]}"} tools/engine_guard.sh "$GODOT" --path . \
		"${view[@]}" --audio-driver Dummy --fixed-fps 30 --disable-vsync -- \
		"$@" --play="$PLAY" --play-idle="${PLAY_IDLE:-600}" 2>&1 | tee "$PLAY/engine.log"
	exit "${PIPESTATUS[0]}"
fi

if (($# == 0)); then
	sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
fi

commands="$*"
if [[ "$1" == "-" ]]; then
	commands="$(cat)"
fi

# A quit with no session up has nothing to quit: left to wait for one, it would be the
# first turn of the next session and end it on its first frame.
if [[ "$commands" == "quit" && ! -f "$PLAY/ready" ]]; then
	echo "play: no session in $PLAY to quit"
	exit 0
fi

# The session is up once its driver has written PLAY/ready: a ship's first bake and the
# window lock's queue can both come before it.
waited=0
while [[ ! -f "$PLAY/ready" ]]; do
	if ((waited >= PLAY_WAIT)); then
		echo "play: no session in $PLAY after ${PLAY_WAIT} s: run \`make play\` in the background first" >&2
		[[ -f "$PLAY/engine.log" ]] && tail -n 5 "$PLAY/engine.log" >&2
		exit 1
	fi
	sleep 1
	waited=$((waited + 1))
done

shopt -s nullglob
taken=("$PLAY"/in/*.txt)
turn=$(printf '%04d' $((${#taken[@]} + 1)))
if [[ "$turn" == "0001" ]]; then
	cat "$PLAY/ready"
fi
printf '%s\n' "$commands" | tr ';' '\n' >"$PLAY/in/$turn.part"
mv "$PLAY/in/$turn.part" "$PLAY/in/$turn.txt"

waited=0
while [[ ! -f "$PLAY/out/$turn.txt" ]]; do
	if [[ ! -f "$PLAY/ready" ]]; then
		# A quit answers before the driver leaves; anything else is the game gone.
		[[ -f "$PLAY/out/$turn.txt" ]] && break
		echo "play: the session ended before turn $turn was answered" >&2
		[[ -f "$PLAY/engine.log" ]] && tail -n 15 "$PLAY/engine.log" >&2
		exit 1
	fi
	if ((waited >= PLAY_WAIT * 5)); then
		echo "play: turn $turn not answered in ${PLAY_WAIT} s (PLAY_WAIT)" >&2
		exit 1
	fi
	sleep 0.2
	waited=$((waited + 1))
done
cat "$PLAY/out/$turn.txt"

# What the engine complained of since the last turn.
seen=0
[[ -f "$PLAY/log_seen" ]] && seen=$(<"$PLAY/log_seen")
if [[ -f "$PLAY/engine.log" ]]; then
	total=$(wc -l <"$PLAY/engine.log")
	complaints=$(tail -n +"$((seen + 1))" "$PLAY/engine.log" | grep -E -A3 'ERROR|WARNING' | head -n 40)
	if [[ -n "$complaints" ]]; then
		echo "engine:"
		printf '%s\n' "$complaints" | sed 's/^/  /'
	fi
	echo "$((total))" >"$PLAY/log_seen"
fi
