# The kernel advisory lock (flock(2)) tools/window_lock.sh and tools/test_slot.sh
# take on a descriptor they hold open, one answer for every system the game is made
# on: flock(1) where it is on PATH (Linux), else the BSD lockf(1) macOS ships, else
# Perl's flock (Git Bash on Windows, whose runtime emulates flock(2) and, as with
# flock(1), leaves the lock on the descriptor when Perl exits, held through an exec
# into a native program and dropped when the last holder is gone). FD_LOCK=flock,
# lockf or perl picks one, so the checks can run the fallbacks where flock is found.
#
# fd_lock_try FD takes it without waiting; fd_lock_wait FD waits as long as it
# takes — blocked in flock, or with lockf trying again every half second, as lockf
# waiting on a descriptor spins a core. FD_LOCK_TOOL names the one picked, empty
# when there is none, and then both fail.

fd_lock_perl() {
	perl -MFcntl=:flock -e \
		'open(my $fh, ">&=", $ARGV[0]) or exit 2; exit(flock($fh, $ARGV[1]) ? 0 : 1)' "$@"
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
	fd_lock_wait() { flock "$1"; }
	;;
lockf)
	fd_lock_try() { /usr/bin/lockf -s -t 0 "$1"; }
	fd_lock_wait() { until fd_lock_try "$1"; do sleep 0.5; done; }
	;;
perl)
	fd_lock_try() { fd_lock_perl "$1" 6; } # LOCK_EX | LOCK_NB
	fd_lock_wait() { fd_lock_perl "$1" 2; } # LOCK_EX
	;;
*)
	FD_LOCK_TOOL=
	fd_lock_try() { return 1; }
	fd_lock_wait() { return 1; }
	;;
esac
