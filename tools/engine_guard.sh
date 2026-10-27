#!/usr/bin/env bash
#
# Runs an engine command and fails when the engine printed an error.
#
# Godot exits 0 after a SCRIPT ERROR in a headless tool or a renderer ERROR, so a
# transcript, a census or a capture that lost a section to a crash looked like a
# success. This wraps the command, passes its stdout and stderr through as they
# come, and once it has exited scans both for the engine's error lines. Any
# match, or the command's own failure, is a failure: deterministic, no judgement.
#
# Usage:  tools/engine_guard.sh "$GODOT" --headless --path . -s res://tools/x.gd -- args
#         tools/engine_guard.sh "$GODOT" ... | grep -v '^\[godot_ai'
#
# What counts: a line that begins (after colour codes) with SCRIPT ERROR:, USER
# ERROR:, SHADER ERROR: or ERROR: — "Parse Error:" lines too. WARNING: lines do
# not. The godot_ai helper autoload's own lines (`[godot_ai ...`) are not
# scanned.
#
# The engine's shutdown reports of resources still in use at exit are not a run's
# errors and are let through, the compatibility renderer's among them: "N shaders of
# type X were never freed" and "<kind> with GL ID of N: leaked N bytes." come only
# from its storage destructors as the engine quits (a capture prints hundreds after
# its frame is saved), so they are matched whole, wherever in the log they fall.
# ENGINE_GUARD_PATTERN is an extended regex that replaces the lines that count (the
# test runner counts script errors alone: its tests provoke engine errors on purpose);
# ENGINE_GUARD_IGNORE an extended regex of matching lines to let through.
#
# The engine ends with whoever asked for it. On Windows a make that ends under its
# recipes — a stopped task, a `timeout` around it, a crash — can leave the shells below
# them and their engines running, holding test slots, the window lock and memory for
# output no one reads (a stopped gate's whole shard tree, 2026-10-24 to 2026-10-27). So
# under make (MAKELEVEL set) a watchdog beside the engine looks every
# ENGINE_GUARD_WATCH_EVERY seconds (5) for each process above the guard, up to the make
# — or, where Git Bash cannot see a native make, up to the recipe's shell, which dies
# with it while the engine below lives on — and stops the engine and what it started the
# moment one is gone, saying so. A stop that takes the guard with it takes the watchdog
# too, and the engine then runs to its end, as before. A guard run by hand, outside make,
# has no watchdog: a shell that backgrounds it and ends is no sign it is unwanted.
# ENGINE_GUARD_WATCH_PID names the one process to watch instead, ENGINE_GUARD_ARMED a
# file touched once the watch is set (both for the checks); ENGINE_GUARD_WATCH=0 runs no
# watchdog.

set -uo pipefail

if (($# == 0)); then
	echo "engine_guard: a command is required" >&2
	exit 1
fi

WORK="$(mktemp -d)"
OUT="$WORK/out"
ERR="$WORK/err"
STATUS="$WORK/status"
ENGINE="$WORK/engine"
WATCH_NOTE="$WORK/watch"
WATCHDOG=""
trap '[[ -n "$WATCHDOG" ]] && kill "$WATCHDOG" 2>/dev/null; rm -rf "$WORK"' EXIT

# Process $1's program name into NAME and its parent into PARENT, from /proc where it
# has them (Git Bash, Linux), else from ps (macOS); "?" and nothing for one gone. They
# set variables rather than print, as a command substitution costs a fork, and a fork
# on a loaded Windows box a tenth of a second.
name_of() {
	local path=""
	if [[ -r "/proc/$1/exename" ]]; then
		{ read -r path <"/proc/$1/exename"; } 2>/dev/null
	elif [[ -r "/proc/$1/comm" ]]; then
		{ read -r path <"/proc/$1/comm"; } 2>/dev/null
	else
		path="$(ps -o comm= -p "$1" 2>/dev/null)"
	fi
	NAME="${path##*/}"
	[[ -n "$NAME" ]] || NAME="?"
}
parent_of() {
	local stat="" fields
	if [[ -r "/proc/$1/stat" ]]; then
		{ read -r stat <"/proc/$1/stat"; } 2>/dev/null
		# shellcheck disable=SC2206 # the fields after the name, split on purpose
		fields=(${stat##*) })
		PARENT="${fields[1]-}"
	else
		PARENT="$(ps -o ppid= -p "$1" 2>/dev/null)"
		PARENT="${PARENT// /}"
	fi
}
is_make() {
	[[ "$1" =~ ^(g?make|mingw32-make)(\.exe)?$ ]]
}

# The processes above the guard to watch, and their names.
watch=()
watch_names=()
if [[ -n "${ENGINE_GUARD_WATCH_PID-}" ]]; then
	name_of "$ENGINE_GUARD_WATCH_PID"
	watch=("$ENGINE_GUARD_WATCH_PID")
	watch_names=("$NAME")
elif [[ "${ENGINE_GUARD_WATCH-1}" != 0 && -n "${MAKELEVEL-}" ]]; then
	pid="$PPID"
	for ((hop = 0; hop < 32; hop++)); do
		[[ "$pid" =~ ^[0-9]+$ ]] && ((pid > 1)) || break
		name_of "$pid"
		watch+=("$pid")
		watch_names+=("$NAME")
		is_make "$NAME" && break
		parent_of "$pid"
		pid="$PARENT"
	done
fi

# The first watched process gone, named, or nothing while every one is there.
first_gone() {
	local k
	for ((k = 0; k < ${#watch[@]}; k++)); do
		kill -0 "${watch[k]}" 2>/dev/null || {
			echo "${watch_names[k]} (PID ${watch[k]})"
			return 0
		}
	done
	return 1
}

# Stops the engine, PID $1, and what it started: taskkill's tree on Windows, where
# Godot's console build runs the engine as a child of its own; TERM, then KILL, elsewhere.
stop_engine() {
	local winpid
	if [[ -r "/proc/$1/winpid" ]] && command -v taskkill >/dev/null; then
		read -r winpid <"/proc/$1/winpid" && taskkill //F //T //PID "$winpid" >/dev/null 2>&1
	fi
	kill -TERM "$1" 2>/dev/null
	sleep 3
	kill -0 "$1" 2>/dev/null && kill -KILL "$1" 2>/dev/null
}

# On descriptors of its own, so a reader of the guard's output never waits on it: the
# note it leaves is printed by the guard, when the guard is still there to print it.
watchdog() {
	local engine gone nap=""
	trap '[[ -n "$nap" ]] && kill "$nap" 2>/dev/null; exit 0' TERM
	while :; do
		sleep "${ENGINE_GUARD_WATCH_EVERY:-5}" &
		nap=$!
		wait "$nap"
		nap=""
		engine=""
		{ read -r engine <"$ENGINE"; } 2>/dev/null
		[[ -n "$engine" ]] || continue
		kill -0 "$engine" 2>/dev/null || return 0
		gone="$(first_gone)" || continue
		echo "engine_guard: $gone is gone: stopping its engine (PID $engine)" >"$WATCH_NOTE"
		stop_engine "$engine"
		return 0
	done
}
if ((${#watch[@]})); then
	watchdog </dev/null >/dev/null 2>&1 &
	WATCHDOG=$!
fi
[[ -n "${ENGINE_GUARD_ARMED-}" ]] && touch "$ENGINE_GUARD_ARMED"

# stderr takes the outer fd 2 through its own tee, stdout the outer pipe through
# the other, so each stays on its own stream and both are kept for the scan. The
# command runs as the very shell that wrote its PID down, for the watchdog: exec'd
# from it under bash 4 and later, through sh where there is no BASHPID (bash 3.2).
{
	{
		if [[ -n "${BASHPID-}" ]]; then
			echo "$BASHPID" >"$ENGINE"
			exec "$@"
		fi
		exec sh -c 'echo $$ >"$1"; shift; exec "$@"' engine_guard "$ENGINE" "$@"
	} 2>&1 1>&3 3>&- | tee "$ERR" >&2
	echo "${PIPESTATUS[0]}" >"$STATUS"
} 3>&1 | tee "$OUT"

if [[ -n "$WATCHDOG" ]]; then
	kill "$WATCHDOG" 2>/dev/null
	wait "$WATCHDOG" 2>/dev/null
	WATCHDOG=""
fi
[[ -s "$WATCH_NOTE" ]] && cat "$WATCH_NOTE" >&2

status="$(cat "$STATUS" 2>/dev/null)"
status="${status:-1}"

exit_leaks='^[[:space:]]*ERROR: ([0-9]+ shaders of type [A-Za-z0-9_]+ were never freed|[A-Za-z ]+ with GL ID of [0-9]+: leaked [0-9]+ bytes\.?)[[:space:]]*$'

errors="$(
	cat "$OUT" "$ERR" |
		sed $'s/\033\[[0-9;]*m//g' |
		grep -v '^\[godot_ai' |
		grep -E "${ENGINE_GUARD_PATTERN:-^[[:space:]]*((SCRIPT|USER|SHADER) )?ERROR:|^[[:space:]]*Parse Error:}" |
		grep -Ev 'still in use at exit|leaked at exit|exist at exit in PagedAllocator' |
		grep -Ev "$exit_leaks" |
		{ if [[ -n "${ENGINE_GUARD_IGNORE:-}" ]]; then grep -Ev "$ENGINE_GUARD_IGNORE"; else cat; fi; } |
		sort | uniq -c | sort -rn
)"

if [[ -n "$errors" ]]; then
	count="$(awk '{ n += $1 } END { print n + 0 }' <<<"$errors")"
	{
		echo "engine_guard: the engine printed $count error line(s) — a run that errors is not a pass:"
		head -n 10 <<<"$errors"
		if (($(wc -l <<<"$errors") > 10)); then
			echo "  … and more distinct errors"
		fi
	} >&2
	exit 1
fi

exit "$status"
