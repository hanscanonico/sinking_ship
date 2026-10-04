#!/usr/bin/env bash
#
# `make serve-web-local` / `make serve-web-local-stop`: the browser build (build/web)
# served over HTTP and an exported --server (build/server-mac, the Linux server's very
# pack) on 127.0.0.1, both left running for a person with a browser (SH12). `start`
# prints the address to open; `stop` kills both by the PIDs `start` wrote down.
#
# The page and the server are on two ports here, so the page's address names the
# server (?server=ws://…); deployed, the reverse proxy puts the server under the page's
# own origin at /ws, and a link needs no server.
#
# Usage:  tools/serve_web_local.sh start [--web-port=47984] [--ws-port=47985]
#         tools/serve_web_local.sh stop
#
# Each runs under `timeout` (two hours), its log under build/serve-web-local/.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

WEB_PORT=47984
WS_PORT=47985
# Long enough for a person to play a few matches; never forever.
DEADLINE=7200
STATE="build/serve-web-local"
PIDS="$STATE/pids"
SERVER_ENGINE="build/server-mac/SinkingShipServer.app/Contents/MacOS/Sinking Ship"

stop() {
	[[ -f "$PIDS" ]] || return 0
	while read -r pid; do
		kill "$pid" 2>/dev/null && echo "serve-web-local: stopped pid $pid"
	done <"$PIDS"
	rm -f "$PIDS"
}

# Waits up to $3 seconds for a line matching $2 in $1.
await_line() {
	local waited=0
	until grep -qE "$2" "$1" 2>/dev/null; do
		if ((waited >= $3 * 2)); then
			echo "serve-web-local: $1 never logged /$2/:" >&2
			cat "$1" >&2
			stop
			exit 1
		fi
		sleep 0.5
		waited=$((waited + 1))
	done
}

command="${1:-}"
shift
for arg in "$@"; do
	case "$arg" in
	--web-port=*) WEB_PORT="${arg#*=}" ;;
	--ws-port=*) WS_PORT="${arg#*=}" ;;
	*)
		echo "serve-web-local: unknown argument $arg" >&2
		exit 2
		;;
	esac
done

case "$command" in
stop)
	stop
	exit 0
	;;
start) ;;
*)
	echo "usage: tools/serve_web_local.sh start|stop [--web-port=N] [--ws-port=N]" >&2
	exit 2
	;;
esac

if [[ -f "$PIDS" ]]; then
	echo "serve-web-local: already running (make serve-web-local-stop first)" >&2
	exit 1
fi
for needed in build/web/index.html "$SERVER_ENGINE"; do
	if [[ ! -e "$needed" ]]; then
		echo "serve-web-local: no $needed — make export-web export-server-mac" >&2
		exit 1
	fi
done
mkdir -p "$STATE"

timeout "$DEADLINE" python3 -m http.server --bind 127.0.0.1 --directory build/web "$WEB_PORT" \
	>"$STATE/web.log" 2>&1 &
echo $! >>"$PIDS"
timeout "$DEADLINE" "$SERVER_ENGINE" --headless --audio-driver Dummy \
	-- --server --port="$WS_PORT" >"$STATE/server.log" 2>&1 &
echo $! >>"$PIDS"

await_line "$STATE/server.log" "listening on" 60
waited=0
until curl -fsS -o /dev/null "http://127.0.0.1:$WEB_PORT/index.html"; do
	if ((waited >= 40)); then
		echo "serve-web-local: the page never came up:" >&2
		cat "$STATE/web.log" >&2
		stop
		exit 1
	fi
	sleep 0.5
	waited=$((waited + 1))
done

PAGE="http://127.0.0.1:$WEB_PORT/"
SERVER="ws://127.0.0.1:$WS_PORT"
cat <<EOF
serve-web-local: the page at $PAGE, the server at $SERVER (logs in $STATE/)
  play:           ${PAGE}?server=$SERVER  (Play online: a name, then Create a room)
  join a room:    ${PAGE}?room=CODE&server=$SERVER  (or the room's Copy invite link)
  stop both:      make serve-web-local-stop
EOF
