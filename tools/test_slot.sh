#!/usr/bin/env bash
#
# No more than TEST_SLOTS test engines at once across the machine, from any
# worktree and any session: runs COMMAND while holding one of TEST_SLOTS slots,
# each an exclusive kernel advisory lock (flock(2)) on a plain file,
# $TEST_SLOT_LOCK.K.flock — /tmp/sinking_ship_test_slot.1.flock … by default.
# tools/run_tests.sh starts every engine it runs through it. TEST_SLOTS is half the
# online cores by default, at least one; set it in the environment or on make
# (`make test TEST_SLOTS=6`). Runs asking for different counts share the low slots,
# so the most engines at once is the largest count any of them asked for.
#
# The slot is taken on a descriptor this script opens and then execs COMMAND
# with, so COMMAND and everything it starts hold it, and the kernel drops it when
# the last of them is gone, however they end — exit, SIGTERM, SIGKILL, a crash.
# It cannot go stale; there is nothing to clean up.
#
# It tries every slot once without waiting; when all are taken, it says so in one
# line — on stderr, or on the descriptor TEST_SLOT_NOTICE_FD numbers, which it closes
# before it runs COMMAND, prefixed with TEST_SLOT_NAME when set — and tries them
# again every half second as long as it takes. The exit status is COMMAND's.
# The lock is tools/lib/fd_lock.sh's: flock(1), lockf(1) or Perl, whichever the
# system has; with none it fails and runs nothing.
#
# Usage:  tools/test_slot.sh COMMAND [ARGS…]

set -uo pipefail

LOCK="${TEST_SLOT_LOCK:-/tmp/sinking_ship_test_slot}"

if (($# == 0)); then
	echo "test: usage: tools/test_slot.sh COMMAND [ARGS…]" >&2
	exit 2
fi

if [[ -n "${TEST_SLOTS-}" ]]; then
	if [[ ! "$TEST_SLOTS" =~ ^[1-9][0-9]*$ ]]; then
		echo "test: TEST_SLOTS takes a count of 1 or more, not '$TEST_SLOTS'" >&2
		exit 1
	fi
	slots="$TEST_SLOTS"
else
	cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"
	slots=$((${cores:-2} / 2))
	((slots >= 1)) || slots=1
fi

source "$(dirname "$0")/lib/fd_lock.sh" || exit 1
if [[ -z "$FD_LOCK_TOOL" ]]; then
	echo "test: none of flock, /usr/bin/lockf and perl is available: cannot take a slot of $LOCK" >&2
	exit 1
fi

# Opens each slot's file on fd 8 in turn and keeps the first it locks there.
take_slot() {
	local k
	for ((k = 1; k <= slots; k++)); do
		exec 8>>"$LOCK.$k.flock" || {
			echo "test: cannot open $LOCK.$k.flock" >&2
			exit 1
		}
		fd_lock_try 8 && return 0
	done
	exec 8>&-
	return 1
}

if ! take_slot; then
	echo "test: ${TEST_SLOT_NAME:+$TEST_SLOT_NAME }waiting for a test engine slot: $slots in use across the machine ($LOCK.*.flock)" >&"${TEST_SLOT_NOTICE_FD:-2}"
	until take_slot; do
		sleep 0.5
	done
fi

if [[ "${TEST_SLOT_NOTICE_FD-}" =~ ^[0-9]+$ ]]; then
	eval "exec $TEST_SLOT_NOTICE_FD>&-"
fi
unset TEST_SLOT_NOTICE_FD TEST_SLOT_NAME
exec "$@"
