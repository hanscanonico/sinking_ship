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
# line on stderr and waits as long as it takes. The exit status is COMMAND's.
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
	wait_lock() { /usr/bin/lockf -s 9; }
else
	echo "window: neither flock nor /usr/bin/lockf is available: cannot take $WINDOW_LOCK_FILE" >&2
	exit 1
fi

exec 9>>"$WINDOW_LOCK_FILE" || {
	echo "window: cannot open $WINDOW_LOCK_FILE" >&2
	exit 1
}

if ! try_lock; then
	echo "window: waiting for another game window (lock $WINDOW_LOCK_FILE)" >&2
	wait_lock || {
		echo "window: could not take $WINDOW_LOCK_FILE" >&2
		exit 1
	}
fi

export WINDOW_LOCK_HELD="$WINDOW_LOCK_FILE"
exec "$@"
