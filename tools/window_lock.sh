#!/usr/bin/env bash
#
# One game window at a time on a shared machine: runs COMMAND while holding the
# window lock, an exclusive kernel advisory lock (flock(2)) on a plain file,
# $WINDOW_LOCK, /tmp/sinking_ship_window.flock by default. `make capture` and
# `make fps` (tools/fps.sh, however it is called) take it themselves: never
# hand-roll a lock around them. `make run` does not: a person playing neither
# waits for it nor holds it.
#
# The lock is taken on a descriptor this script opens and then execs COMMAND
# with, so COMMAND and everything it starts hold it, and the kernel drops it when
# the last of them is gone, however they end — exit, SIGTERM, SIGKILL, a crash.
# It cannot go stale; there is nothing to clean up.
#
# It tries once without waiting; when another window holds it, it says so in one
# line on stderr, naming the holder — its PID, how long it has run, its command —
# when the file says which it is, and waits as long as it takes: blocked in
# flock(1), or with lockf(1) trying again every half second, as lockf waiting on a
# descriptor spins a core. The exit status is COMMAND's. A holder writes its PID,
# which exec keeps for COMMAND, into the file with its start time, so a PID the
# system has since given another process is never named.
# Under a holder (WINDOW_LOCK_HELD names the same file) it runs COMMAND as it is,
# rather than wait on itself. flock(1) where it is on PATH (Linux), else the
# BSD lockf(1) macOS ships; with neither it fails and runs nothing.
#
# Usage:  tools/window_lock.sh COMMAND [ARGS…]

set -uo pipefail

source "$(dirname "$0")/lib/window_lock_file.sh" || exit 1

if (($# == 0)); then
	echo "window: usage: tools/window_lock.sh COMMAND [ARGS…]" >&2
	exit 2
fi

if window_lock_held; then
	exec "$@"
fi

if command -v flock >/dev/null; then
	try_lock() { flock -n 9; }
	wait_lock() { flock 9; }
elif [[ -x /usr/bin/lockf ]]; then
	try_lock() { /usr/bin/lockf -s -t 0 9; }
	wait_lock() { until try_lock; do sleep 0.5; done; }
elif command -v perl >/dev/null; then
	# Git Bash on Windows: perl's flock(2) on the inherited descriptor, as in
	# tools/test_slot.sh.
	try_lock() {
		perl -e 'use Fcntl ":flock"; open(F, ">>&=", 9) or exit 2; exit(flock(F, LOCK_EX | LOCK_NB) ? 0 : 1)'
	}
	wait_lock() { until try_lock; do sleep 0.5; done; }
else
	echo "window: neither flock, /usr/bin/lockf nor perl is available: cannot take $WINDOW_LOCK_FILE" >&2
	exit 1
fi

# When process $1 started, as ps says it; nothing for a process that is gone.
started() {
	LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | sed 's/^ *//; s/ *$//'
}

# ", held by PID …" for the holder the file names, while it is the process that wrote
# it; when the file names no one, or someone gone, that the holder is unknown — one
# that has just taken the lock, or an older copy of this script, which wrote nothing.
holder() {
	local pid start
	if IFS=$'\t' read -r pid start <"$WINDOW_LOCK_FILE" 2>/dev/null &&
		[[ "$pid" =~ ^[0-9]+$ && -n "$start" && "$(started "$pid")" == "$start" ]]; then
		printf ', held by PID %s for %s: %s' "$pid" \
			"$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')" \
			"$(ps -ww -o command= -p "$pid" 2>/dev/null | cut -c1-400)"
	else
		printf ', its holder unknown'
	fi
}

exec 9>>"$WINDOW_LOCK_FILE" || {
	echo "window: cannot open $WINDOW_LOCK_FILE" >&2
	exit 1
}

if ! try_lock; then
	echo "window: waiting for another game window (lock $WINDOW_LOCK_FILE)$(holder)" >&2
	wait_lock || {
		echo "window: could not take $WINDOW_LOCK_FILE" >&2
		exit 1
	}
fi

printf '%s\t%s\n' "$$" "$(started "$$")" >"$WINDOW_LOCK_FILE"
export WINDOW_LOCK_HELD="$WINDOW_LOCK_FILE"
exec "$@"
