# The kernel advisory lock (flock(2)) tools/window_lock.sh and tools/test_slot.sh
# take on a descriptor they hold open, one answer for every system the game is made
# on: flock(1) where it is on PATH (Linux), else the BSD lockf(1) macOS ships, else
# Perl's flock (Git Bash on Windows, whose runtime emulates flock(2) and, as with
# flock(1), leaves the lock on the descriptor when Perl exits, held through an exec
# into a native program and dropped when the last holder is gone). FD_LOCK=flock,
# lockf or perl picks one, so the checks can run the fallbacks where flock is found.
#
# fd_lock_try FD takes it without waiting; fd_lock_wait FD [SECONDS] waits for it,
# SECONDS at most when they are given and above 0, else as long as it takes —
# blocked in flock (under an alarm, with Perl), or with lockf trying again every half
# second, as lockf waiting on a descriptor spins a core — and returns 1 when the time
# is up. FD_LOCK_TOOL names the one picked, empty when there is none, and then both
# fail.

# Perl's flock on descriptor $1 with operation $2, given up after $3 seconds when $3 is
# above 0: the alarm ends a blocked flock by ending Perl (a handler of Perl's own would
# never run, as Git Bash's runtime goes back into the flock), and the group's stderr
# takes the shell's word on it.
fd_lock_perl() {
	{
		perl -MFcntl=:flock -e \
			'alarm($ARGV[2] // 0); open(my $fh, ">&=", $ARGV[0]) or exit 2;
			exit(flock($fh, $ARGV[1]) ? 0 : 1)' "$@"
	} 2>/dev/null
}

FD_LOCK_TOOL=${FD_LOCK-}
if [[ -z "$FD_LOCK_TOOL" ]]; then
	if command -v flock >/dev/null; then
		FD_LOCK_TOOL=flock
	elif [[ -x /usr/bin/lockf ]]; then
		FD_LOCK_TOOL=lockf
	elif command -v perl >/dev/null; then
		FD_LOCK_TOOL=perl
	fi
fi

case "$FD_LOCK_TOOL" in
flock)
	fd_lock_try() { flock -n "$1"; }
	fd_lock_wait() {
		if ((${2:-0} > 0)); then
			flock -w "$2" "$1"
		else
			flock "$1"
		fi
	}
	;;
lockf)
	fd_lock_try() { /usr/bin/lockf -s -t 0 "$1"; }
	fd_lock_wait() {
		local seconds=${2:-0} deadline
		deadline=$((SECONDS + seconds))
		until fd_lock_try "$1"; do
			((seconds <= 0 || SECONDS < deadline)) || return 1
			sleep 0.5
		done
	}
	;;
perl)
	fd_lock_try() { fd_lock_perl "$1" 6; } # LOCK_EX | LOCK_NB
	# LOCK_EX; Perl ended by its alarm (128 + SIGALRM) is the time being up.
	fd_lock_wait() {
		fd_lock_perl "$1" 2 "${2:-0}"
		local status=$?
		((status == 142)) && return 1
		return "$status"
	}
	;;
*)
	FD_LOCK_TOOL=
	fd_lock_try() { return 1; }
	fd_lock_wait() { return 1; }
	;;
esac
