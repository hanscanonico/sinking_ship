#!/usr/bin/env bash
#
# `make serve-local`: a --server and two headless --autoplay clients in one room,
# over real WebSockets on 127.0.0.1 (SH12). Ada creates the room and starts the match
# once Bea — who types its code in lower case — is in; bots take the other seats.
# Then the server's log: who came and went, the match's transcript, its tick times,
# each client's round trips and the snapshot bandwidth sent them.
#
# With --kill, Bea's process is killed --kill-after seconds into the match, as a
# crash or a pulled cable would end it: her seat goes to a bot and the match still
# finishes.
#
# Usage:  tools/serve_local.sh [--port=47923] [--seed=1701] [--kill] [--kill-after=20]
#
# Every engine runs headless under `timeout`, and each process this started is
# killed by its PID as the script exits. The exit status is 0 only when the server
# logged a finished match and quit by itself — and, with --kill, handed Bea's seat to
# a bot.

set -uo pipefail

# Sourced before the cd: $0 may be a relative path.
source "$(dirname "$0")/lib/require_godot.sh" || exit 1

cd "$(dirname "$0")/.." || exit 1

require_godot serve-local

PORT=47923
SEED=1701
KILL=0
KILL_AFTER=20
# The longest any one engine may run: a match is about two and a half minutes.
DEADLINE=420

for arg in "$@"; do
	case "$arg" in
	--port=*) PORT="${arg#*=}" ;;
	--seed=*) SEED="${arg#*=}" ;;
	--kill) KILL=1 ;;
	--kill-after=*) KILL_AFTER="${arg#*=}" ;;
	*)
		echo "serve-local: unknown argument $arg" >&2
		exit 2
		;;
	esac
done

LOGS="$(mktemp -d)"
URL="ws://127.0.0.1:$PORT"
started=()

# The `timeout` wrappers this started; each forwards a TERM to its engine.
cleanup() {
	for pid in ${started[@]+"${started[@]}"}; do
		kill "$pid" 2>/dev/null
	done
}
trap cleanup EXIT

# Starts an engine headless with the user args after the name, its output in
# $LOGS/<name>.log, and leaves its `timeout` wrapper's PID in $last.
launch() {
	local name="$1"
	shift
	timeout "$DEADLINE" "$GODOT" --headless --no-header --path . --audio-driver Dummy \
		-- "$@" >"$LOGS/$name.log" 2>&1 &
	last=$!
	started+=("$last")
}

# Waits up to $3 seconds for a line matching $2 in $LOGS/$1.log.
await_line() {
	local waited=0
	until grep -qE "$2" "$LOGS/$1.log" 2>/dev/null; do
		if ((waited >= $3 * 2)); then
			echo "serve-local: $1 never logged /$2/ — its log:" >&2
			cat "$LOGS/$1.log" >&2
			exit 1
		fi
		sleep 0.5
		waited=$((waited + 1))
	done
}

echo "serve-local: logs in $LOGS"
launch server --server --port="$PORT" --seed="$SEED" --matches=1
server=$last
await_line server "listening on" 60

launch ada --connect="$URL" --create --name=Ada --autoplay --start-at=2
await_line ada "in room [A-Z]{4}" 60
code="$(grep -oE "in room [A-Z]{4}" "$LOGS/ada.log" | head -1 | awk '{print $3}')"
lower="$(printf '%s' "$code" | tr '[:upper:]' '[:lower:]')"
echo "serve-local: Ada made room $code; Bea joins it as $lower"

launch bea --connect="$URL" --room="$lower" --name=Bea --autoplay
bea=$last

if ((KILL)); then
	await_line bea "match begins" 60
	sleep "$KILL_AFTER"
	engine="$(pgrep -P "$bea")"
	echo "serve-local: killing Bea (pid $engine) $KILL_AFTER s into the match"
	kill -KILL "$engine"
fi

wait "$server"
status=$?
echo "serve-local: server exited $status"
echo "---- server ----"
grep -v '^\[godot_ai' "$LOGS/server.log"
for name in ada bea; do
	echo "---- $name ----"
	grep -v '^\[godot_ai' "$LOGS/$name.log" | tail -5
done

failed=0
if ((status != 0)); then
	echo "serve-local: the server did not quit by itself after its match" >&2
	failed=1
fi
if ! grep -qE '\| (winner seat|draw at) ' "$LOGS/server.log"; then
	echo "serve-local: the server logged no finished match" >&2
	failed=1
fi
if ((KILL)) && ! grep -qE ': Bea left · seat [0-9]+ to a bot' "$LOGS/server.log"; then
	echo "serve-local: Bea's seat was never handed to a bot" >&2
	failed=1
fi
exit $failed
