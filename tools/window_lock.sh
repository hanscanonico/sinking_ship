#!/usr/bin/env bash
#
# No more than WINDOW_SLOTS game windows at once on a shared machine: runs COMMAND
# while holding one of WINDOW_SLOTS window slots, each an exclusive kernel advisory
# lock (flock(2)) on a plain file — $WINDOW_LOCK, /tmp/sinking_ship_window.flock by
# default, for slot 1, and FILE.slot2 … for the others. `make capture` and `make fps`
# (tools/fps.sh, however it is called) take one themselves, as do tools/play.sh and
# tools/crew.sh (one for all of a crew's seats): never hand-roll a lock around them.
# `make run` does not: a person playing neither waits for it nor holds it.
#
# A capture reads its frame off the game's own viewport and steps one tick a drawn
# frame, so windows side by side only slow each other: the shot is the same. A
# measurement is not, so `--alone` takes every slot — tools/fps.sh runs so, with no
# other window drawing — and keeps the slots it gets while it waits for the rest, no
# one behind it in the queue taking one. WINDOW_SLOTS is 3 by default, at most 9; set
# it the same for every session on the machine (in the environment), as a run asking
# for fewer shares the low slots, and one --alone only keeps out the slots it counts.
#
# The slots are taken on descriptors this script opens and then execs COMMAND with,
# so COMMAND and everything it starts hold them, and the kernel drops them when the
# last of them is gone, however they end — exit, SIGTERM, SIGKILL, a crash. There is
# nothing to clean up, but whatever COMMAND starts holds its slot for as long as it
# lives, past COMMAND's own end: on Windows, stopping a task kills its shell and leaves
# the Godot it started running, and that Godot keeps the slot.
#
# Waiters take a slot in the order they came: each holds a ticket in FILE.queue while
# it waits, and the first with no live ticket ahead of it takes the slot
# (tools/lib/window_queue.pl, where there is Perl; without it they wait unordered, on
# slot 1 alone). A ticket is itself a kernel lock, so a waiter that dies leaves none
# behind. The kernel locks stay what cap the windows: an older copy of this script
# takes no ticket and knows slot 1 only, and may take it ahead of the queue, never
# alongside its holder.
#
# It tries the slots once without waiting, when no one is queued; when they are taken,
# it says so in one line on stderr, naming each slot's holder — its PID, how long it
# has run, its command — when the slot's file says which it is, and how many wait
# ahead of it, and waits WINDOW_LOCK_WAIT seconds at most, 1800 by default (0 waits as
# long as it takes). A waiter that runs out of time says so, naming the holders again
# and, when a process a file names is gone — something it started holds the slot — the
# Godot processes running, and exits 75 without running COMMAND. Otherwise the exit
# status is COMMAND's.
#
# A holder writes its PID, which exec keeps for COMMAND, into each slot's file with
# its start time, so a PID the system has since given another process is never named.
# Git Bash's ps cannot say when a process started, and its exec starts a process anew,
# so there a waiter asks /proc instead whether the PID runs under this lock: the
# holder exports WINDOW_LOCK_HELD, naming the file, to COMMAND, and WINDOW_LOCK_ALONE
# too when it holds every slot. Under a holder (WINDOW_LOCK_HELD names the same file)
# it runs COMMAND as it is, rather than wait on itself — but --alone under a holder of
# one slot of several cannot have them all, and fails. The lock is
# tools/lib/fd_lock.sh's: flock(1), lockf(1) or Perl, whichever the system has; with
# none it fails and runs nothing.
#
# Usage:  [WINDOW_LOCK_WAIT=SECONDS] [WINDOW_SLOTS=N] tools/window_lock.sh [--alone] COMMAND [ARGS…]

set -uo pipefail

source "$(dirname "$0")/lib/window_lock_file.sh" || exit 1
source "$(dirname "$0")/lib/fd_lock.sh" || exit 1

ALONE=0
if [[ "${1:-}" == --alone ]]; then
	ALONE=1
	shift
fi

if (($# == 0)); then
	echo "window: usage: [WINDOW_LOCK_WAIT=SECONDS] [WINDOW_SLOTS=N] tools/window_lock.sh [--alone] COMMAND [ARGS…]" >&2
	exit 2
fi

if window_lock_held; then
	if ((ALONE)) && ! window_lock_alone_held; then
		echo "window: --alone under a holder of one game window slot of several: run it on its own" >&2
		exit 2
	fi
	exec "$@"
fi

WAIT_SECONDS=${WINDOW_LOCK_WAIT:-1800}
if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
	echo "window: WINDOW_LOCK_WAIT is seconds to wait (0: as long as it takes), not '$WAIT_SECONDS'" >&2
	exit 2
fi
SLOTS=${WINDOW_SLOTS:-3}
if ! [[ "$SLOTS" =~ ^[1-9]$ ]]; then
	echo "window: WINDOW_SLOTS is a count of game windows from 1 to 9, not '$SLOTS'" >&2
	exit 2
fi

if [[ -z "$FD_LOCK_TOOL" ]]; then
	echo "window: none of flock, /usr/bin/lockf and perl is available: cannot take $WINDOW_LOCK_FILE" >&2
	exit 1
fi

# Slot $1's descriptor: 9 for slot 1, as it always was, and up from there.
slot_fd() {
	echo $((8 + $1))
}

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

# "held by PID …" for the holder file $1 names, while it is the process that wrote it;
# when the process it names is gone, that something it started holds the slot; when
# the file names no one, or a PID the system has given another process, that the
# holder is unknown — one that has just taken the slot, or an older copy of this
# script, which wrote nothing.
holder_of() {
	local pid='' start=''
	IFS=$'\t' read -r pid start <"$1" 2>/dev/null
	if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
		printf 'its holder unknown'
	elif { [[ -n "$start" && "$(started "$pid")" == "$start" ]]; } ||
		{ [[ -z "$start" ]] && marked "$pid"; }; then
		printf 'held by PID %s%s: %s' "$pid" "$(ran_for "$pid")" "$(command_of "$pid")"
	elif ! kill -0 "$pid" 2>/dev/null; then
		printf 'its holder PID %s gone: something it started holds the lock' "$pid"
	else
		printf 'its holder unknown'
	fi
}

# The slots taken, 1 up, one a line: one Perl tries them all, letting go of each it
# gets. Without Perl, every slot is named.
taken_slots() {
	local k files=()
	for ((k = 1; k <= SLOTS; k++)); do
		files+=("$(window_slot_file "$k")")
	done
	if command -v perl >/dev/null; then
		perl -MFcntl=:flock -e 'for my $k (0 .. $#ARGV) {
			open(my $fh, ">>", $ARGV[$k]) or next;
			if (flock($fh, LOCK_EX | LOCK_NB)) { flock($fh, LOCK_UN); next; }
			print $k + 1, "\n";
		}' "${files[@]}" 2>/dev/null
	else
		seq 1 "$SLOTS"
	fi
}

# ", held by PID …" for each slot taken — with one slot, as it always said it; with
# more, "slot K held by …" for each, "; " between them.
holder() {
	local k said=''
	if ((SLOTS == 1)); then
		printf ', %s' "$(holder_of "$WINDOW_LOCK_FILE")"
		return
	fi
	for k in $(taken_slots); do
		said+="${said:+;} slot $k $(holder_of "$(window_slot_file "$k")")"
	done
	[[ -n "$said" ]] && printf ',%s' "$said"
}

# The Godot windows open, one a line: when the holder a file names is gone, one of
# them is likely what holds the slot, and Git Bash's ps cannot see a native program. A
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

# Opens slot $1's file on its descriptor.
open_slot() {
	local file
	file=$(window_slot_file "$1")
	eval "exec $(slot_fd "$1")>>\"\$file\"" || {
		echo "window: cannot open $file" >&2
		exit 1
	}
}

# Closes slot $1's descriptor, letting go of the slot if it was held.
close_slot() {
	eval "exec $(slot_fd "$1")>&-"
}

for ((k = 1; k <= SLOTS; k++)); do
	open_slot "$k"
done

# Says it gave up after WAIT_SECONDS, naming the holders and, when a process a file
# names is gone, the Godot windows open, and exits 75.
give_up() {
	local said running
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
}

# Waits out of turn, as the lock did before its queue: where there is no Perl to keep
# the queue, or it cannot be kept. A run takes slot 1, as an older copy of this script
# does; --alone takes each slot in turn.
wait_unordered() {
	local k last=1 waited
	((ALONE)) && last=$SLOTS
	got=()
	for ((k = 1; k <= last; k++)); do
		fd_lock_wait "$(slot_fd "$k")" "$WAIT_SECONDS"
		waited=$?
		((waited == 1 && WAIT_SECONDS > 0)) && give_up
		if ((waited != 0)); then
			echo "window: could not take $(window_slot_file "$k")" >&2
			exit 1
		fi
		got+=("$k")
	done
}

# What the wait is for, as the queue and the unordered wait say it.
waiting_line() {
	local what="lock $WINDOW_LOCK_FILE"
	if ((ALONE && SLOTS > 1)); then
		what="this one runs alone: every one of $SLOTS slots, $what"
	elif ((SLOTS > 1)); then
		what="all $SLOTS slots taken, $what"
	fi
	echo "window: waiting for another game window ($what)$(holder)$limit"
}

# Tries the slots once without waiting: any one, or with --alone, every one, letting
# go of those it got when it cannot have them all, so two runs --alone never wait on
# each other, each holding a part.
try_slots() {
	local k
	got=()
	for ((k = 1; k <= SLOTS; k++)); do
		if fd_lock_try "$(slot_fd "$k")"; then
			got+=("$k")
			((ALONE)) || return 0
		elif ((ALONE)); then
			break
		fi
	done
	((ALONE)) && ((${#got[@]} == SLOTS)) && return 0
	for k in ${got[@]+"${got[@]}"}; do
		close_slot "$k"
		open_slot "$k"
	done
	got=()
	return 1
}

# The queue: waiters take a slot in the order they came (tools/lib/window_queue.pl),
# where there is Perl to keep it. The first try without waiting is only for an empty
# queue, so a newcomer never takes a slot from a waiter ahead of it.
QUEUE="$WINDOW_LOCK_FILE.queue"
queued=0
for ticket in "$QUEUE"/[0-9]*; do
	[[ -e "$ticket" ]] && queued=1 && break
done
limit=''
((WAIT_SECONDS > 0)) && limit="; giving up after $WAIT_SECONDS s"
got=()
if ((queued == 0)) && try_slots; then
	:
elif command -v perl >/dev/null; then
	fds=()
	for ((k = 1; k <= SLOTS; k++)); do
		fds+=("$(slot_fd "$k")")
	done
	want=one
	((ALONE)) && want=all
	# Its word that it holds the slots is what counts: a Perl ended from outside — on
	# Windows a TerminateProcess reads as exit 0 — said nothing, and holds nothing. It is
	# exec'd in the substitution's place, as tools/lib/fd_lock.sh says why.
	said=$(exec perl "$(dirname "$0")/lib/window_queue.pl" "$$" "$QUEUE" "$WAIT_SECONDS" \
		"$(waiting_line)" "$want" "${fds[@]}")
	waited=$?
	said=${said##*$'\n'}
	if ((waited == 1 && WAIT_SECONDS > 0)); then
		give_up
	elif ((waited == 2)); then
		echo "window: cannot keep the queue in $QUEUE: waiting out of turn" >&2
		wait_unordered
	elif ((waited != 0)) || [[ "$said" != locked\ * ]]; then
		echo "window: could not take $WINDOW_LOCK_FILE: its waiter ended (exit $waited)" \
			"without saying it holds it" >&2
		exit 1
	else
		read -r -a got <<<"${said#locked }"
	fi
else
	waiting_line >&2
	wait_unordered
fi

# The slots it does not hold are closed, and those it holds name it.
for ((k = 1; k <= SLOTS; k++)); do
	if [[ " ${got[*]} " == *" $k "* ]]; then
		printf '%s\t%s\n' "$$" "$(started "$$")" >"$(window_slot_file "$k")"
	else
		close_slot "$k"
	fi
done
export WINDOW_LOCK_HELD="$WINDOW_LOCK_FILE"
if ((${#got[@]} == SLOTS)); then
	export WINDOW_LOCK_ALONE="$WINDOW_LOCK_FILE"
else
	unset WINDOW_LOCK_ALONE
fi
exec "$@"
