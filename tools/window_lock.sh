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
# There is nothing to clean up, but whatever COMMAND starts holds the lock for as
# long as it lives, past COMMAND's own end: on Windows, stopping a task kills its
# shell and leaves the Godot it started running, and that Godot keeps the lock.
#
# It tries once without waiting; when another window holds it, it says so in one
# line on stderr, naming the holder — its PID, how long it has run, its command —
# when the file says which it is, and waits WINDOW_LOCK_WAIT seconds at most, 1800
# by default (0 waits as long as it takes). A waiter that runs out of time says so,
# naming the holder again and, when the process the file names is gone — something
# it started holds the lock — the Godot processes running, and exits 75 without
# running COMMAND. Otherwise the exit status is COMMAND's.
#
# A holder writes its PID, which exec keeps for COMMAND, into the file with its start
# time, so a PID the system has since given another process is never named. Git
# Bash's ps cannot say when a process started, and its exec starts a process anew,
# so there a waiter asks /proc instead whether the PID runs under this lock: the
# holder exports WINDOW_LOCK_HELD, naming the file, to COMMAND. Under a holder
# (WINDOW_LOCK_HELD names the same file) it runs COMMAND as it is, rather than wait
# on itself. The lock is tools/lib/fd_lock.sh's: flock(1), lockf(1) or Perl,
# whichever the system has; with none it fails and runs nothing.
#
# Usage:  [WINDOW_LOCK_WAIT=SECONDS] tools/window_lock.sh COMMAND [ARGS…]

set -uo pipefail

source "$(dirname "$0")/lib/window_lock_file.sh" || exit 1
source "$(dirname "$0")/lib/fd_lock.sh" || exit 1

if (($# == 0)); then
	echo "window: usage: [WINDOW_LOCK_WAIT=SECONDS] tools/window_lock.sh COMMAND [ARGS…]" >&2
	exit 2
fi

if window_lock_held; then
	exec "$@"
fi

WAIT_SECONDS=${WINDOW_LOCK_WAIT:-1800}
if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
	echo "window: WINDOW_LOCK_WAIT is seconds to wait (0: as long as it takes), not '$WAIT_SECONDS'" >&2
	exit 2
fi

if [[ -z "$FD_LOCK_TOOL" ]]; then
	echo "window: none of flock, /usr/bin/lockf and perl is available: cannot take $WINDOW_LOCK_FILE" >&2
	exit 1
fi

# When process $1 started, as ps says it; nothing for a process that is gone, or where
# ps cannot say (Git Bash).
started() {
	LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | sed 's/^ *//; s/ *$//'
}

# Whether process $1 runs under a holder of this lock, as /proc says its environment
# is, where /proc keeps one.
marked() {
	{ tr '\0' '\n' <"/proc/$1/environ"; } 2>/dev/null | grep -qxF "WINDOW_LOCK_HELD=$WINDOW_LOCK_FILE"
}

# " for 01:02:03", how long process $1 has run as ps says it, or on Git Bash, whose ps
# has no -o, " since 07:08:09", when its ps says it started.
ran_for() {
	local t
	t=$(ps -o etime= -p "$1" 2>/dev/null | tr -d ' ')
	if [[ -n "$t" ]]; then
		printf ' for %s' "$t"
	else
		t=$(ps -p "$1" 2>/dev/null | awk 'NR == 2 { print $7 }')
		[[ -n "$t" ]] && printf ' since %s' "$t"
	fi
}

# Process $1's command line, from ps, or from /proc where ps has no -o (Git Bash).
command_of() {
	local said
	said=$(ps -ww -o command= -p "$1" 2>/dev/null)
	[[ -n "$said" ]] || said=$({ tr '\0' ' ' <"/proc/$1/cmdline"; } 2>/dev/null)
	printf '%s' "$said" | cut -c1-400
}

# ", held by PID …" for the holder the file names, while it is the process that wrote
# it; when the process it names is gone, that something it started holds the lock;
# when the file names no one, or a PID the system has given another process, that the
# holder is unknown — one that has just taken the lock, or an older copy of this
# script, which wrote nothing.
holder() {
	local pid='' start=''
	IFS=$'\t' read -r pid start <"$WINDOW_LOCK_FILE" 2>/dev/null
	if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
		printf ', its holder unknown'
	elif { [[ -n "$start" && "$(started "$pid")" == "$start" ]]; } ||
		{ [[ -z "$start" ]] && marked "$pid"; }; then
		printf ', held by PID %s%s: %s' "$pid" "$(ran_for "$pid")" "$(command_of "$pid")"
	elif ! kill -0 "$pid" 2>/dev/null; then
		printf ', its holder PID %s gone: something it started holds the lock' "$pid"
	else
		printf ', its holder unknown'
	fi
}

# The Godot windows open, one a line: when the holder the file names is gone, one of
# them is likely what holds the lock, and Git Bash's ps cannot see a native program. A
# headless engine (a test, a bake) takes no window lock, so it is left out.
godots() {
	if command -v powershell.exe >/dev/null; then
		powershell.exe -NoProfile -NonInteractive -Command "Get-CimInstance Win32_Process \
			-Filter \"Name LIKE 'Godot%'\" | ForEach-Object { 'PID {0} since {1:yyyy-MM-dd HH:mm}: {2}' \
			-f \$_.ProcessId, \$_.CreationDate, \$_.CommandLine }"
	else
		ps -eo pid=,command= | grep -i '[g]odot'
	fi 2>/dev/null | tr -d '\r' | grep -v -e '--headless' | cut -c1-300
}

exec 9>>"$WINDOW_LOCK_FILE" || {
	echo "window: cannot open $WINDOW_LOCK_FILE" >&2
	exit 1
}

if ! fd_lock_try 9; then
	limit=''
	((WAIT_SECONDS > 0)) && limit="; giving up after $WAIT_SECONDS s"
	echo "window: waiting for another game window (lock $WINDOW_LOCK_FILE)$(holder)$limit" >&2
	fd_lock_wait 9 "$WAIT_SECONDS"
	waited=$?
	if ((waited == 1 && WAIT_SECONDS > 0)); then
		said=$(holder)
		echo "window: gave up after $WAIT_SECONDS s waiting for another game window" \
			"(lock $WINDOW_LOCK_FILE)$said" >&2
		if [[ "$said" == *gone* ]]; then
			running=$(godots)
			if [[ -n "$running" ]]; then
				echo "window: the Godot windows open, one of which likely holds it:" >&2
				printf '%s\n' "$running" | sed 's/^/window:   /' >&2
			fi
		fi
		echo "window: WINDOW_LOCK_WAIT=0 waits as long as it takes" >&2
		exit 75
	elif ((waited != 0)); then
		echo "window: could not take $WINDOW_LOCK_FILE" >&2
		exit 1
	fi
fi

printf '%s\t%s\n' "$$" "$(started "$$")" >"$WINDOW_LOCK_FILE"
export WINDOW_LOCK_HELD="$WINDOW_LOCK_FILE"
exec "$@"
