#!/usr/bin/env bash
#
# `make online-e2e`: two people playing online through the game's own screens, on
# 127.0.0.1 (SH12). A --server, then two headless games driven by tools/online_e2e.gd
# as hands would drive them: Ada opens Play online, types her name and the server and
# creates a room; Bea types its code in lower case, letter by letter, and joins; Ada
# starts once Bea is aboard, both play the match to its results — keys pressed at
# random standing in for hands — go back to the room, see it waiting again, and leave
# it. Then each one's steps and the tail of the server's log.
#
# Usage:  tools/online_e2e.sh [--port=47931] [--seed=1701]
#
# Every engine runs headless under `timeout`; each process this started is killed by
# its PID as the script exits. The exit status is 0 only when both players reached
# every step and the server logged their match's end and both leaving.

set -uo pipefail

# Sourced before the cd: $0 may be a relative path.
source "$(dirname "$0")/lib/require_godot.sh" || exit 1

cd "$(dirname "$0")/.." || exit 1

require_godot online-e2e

PORT=47931
SEED=1701
# The longest any one engine may run: a match is about two and a half minutes.
DEADLINE=480

for arg in "$@"; do
	case "$arg" in
	--port=*) PORT="${arg#*=}" ;;
	--seed=*) SEED="${arg#*=}" ;;
	*)
		echo "online-e2e: unknown argument $arg" >&2
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

# Waits up to $3 seconds for a line matching $2 in $LOGS/$1.log.
await_line() {
	local waited=0
	until grep -qE "$2" "$LOGS/$1.log" 2>/dev/null; do
		if ((waited >= $3 * 2)); then
			echo "online-e2e: $1 never logged /$2/ — its log:" >&2
			cat "$LOGS/$1.log" >&2
			exit 1
		fi
		sleep 0.5
		waited=$((waited + 1))
	done
}

# Starts a player driving the game, named $1, joining the code $2 (empty: creating).
player() {
	ONLINE_E2E_NAME="$1" ONLINE_E2E_SERVER="$URL" ONLINE_E2E_JOIN="$2" ONLINE_E2E_PLAYERS=2 \
		ONLINE_E2E_SEED="$SEED" timeout "$DEADLINE" "$GODOT" --path . --headless --no-header \
		--audio-driver Dummy -s res://tools/online_e2e.gd >"$LOGS/$1.log" 2>&1 &
	last=$!
	started+=("$last")
}

echo "online-e2e: logs in $LOGS"
timeout "$DEADLINE" "$GODOT" --path . --headless --no-header --audio-driver Dummy \
	-- --server --port="$PORT" --seed="$SEED" >"$LOGS/server.log" 2>&1 &
started+=("$!")
await_line server "listening on" 60

player Ada ""
ada=$last
await_line Ada "e2e: Ada in room [A-Z]{4}" 120
code="$(grep -oE "e2e: Ada in room [A-Z]{4}" "$LOGS/Ada.log" | awk '{print $5}')"
lower="$(printf '%s' "$code" | tr '[:upper:]' '[:lower:]')"
echo "online-e2e: Ada made room $code; Bea types $lower"
player Bea "$lower"
bea=$last

wait "$ada"
ada_status=$?
wait "$bea"
bea_status=$?

failed=0
for name in Ada Bea; do
	echo "---- $name ----"
	grep -E '^e2e: |^match seed|ERROR|SCRIPT' "$LOGS/$name.log"
done
echo "---- server (tail) ----"
grep -v '^\[godot_ai' "$LOGS/server.log" | tail -25

if ((ada_status != 0 || bea_status != 0)); then
	echo "online-e2e: Ada exited $ada_status, Bea $bea_status" >&2
	failed=1
fi
for line in ': match begins' ' \| (winner seat|draw at) ' ': waiting for its host again' \
	': Ada left$' ': Bea left$'; do
	if ! grep -qE "room $code$line" "$LOGS/server.log"; then
		echo "online-e2e: the server never logged /room $code$line/" >&2
		failed=1
	fi
done
exit $failed
