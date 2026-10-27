#!/usr/bin/env bash
#
# No more than TEST_SLOTS test engines at once across the machine, from any
# worktree and any session: runs COMMAND while holding one of TEST_SLOTS slots,
# each an exclusive kernel advisory lock (flock(2)) on a plain file,
# $TEST_SLOT_LOCK.K.flock — /tmp/sinking_ship_test_slot.1.flock … by default.
# tools/run_tests.sh starts every engine it runs through it, and so do make check
# (tools/check_scripts.sh), art-lint and bake-check. TEST_SLOTS is half the
# online cores by default, at least one; set it in the environment or on make
# (`make test TEST_SLOTS=6`). Runs asking for different counts share the low slots,
# so the most engines at once is the largest count any of them asked for.
#
# A slot is not memory, though: on 2026-10-24 engines from several sessions' gates ran
# the Windows box out of it, and Claude Code stopped the idle sessions' background
# tasks. So with its slot taken, a run also waits for TEST_SLOT_MIN_FREE_MB of memory
# to be free (tools/lib/free_memory.sh) — a tenth of the machine's by default, at least
# 1024; 0 waits for none — and once TEST_SLOT_MEMORY_WAIT seconds (1800) have gone
# by without it, it says so and runs anyway, as it always did.
#
# The slot is taken on a descriptor this script opens and then execs COMMAND
# with, so COMMAND and everything it starts hold it, and the kernel drops it when
# the last of them is gone, however they end — exit, SIGTERM, SIGKILL, a crash.
# It cannot go stale; there is nothing to clean up.
#
# It tries every slot once without waiting; when all are taken, it says so in one
# line — on stderr, or on the descriptor TEST_SLOT_NOTICE_FD numbers, which it closes
# before it runs COMMAND, prefixed with TEST_SLOT_NAME when set — and tries them
# again every half second as long as it takes. It says the same of a wait for
# memory. Runs that share a TEST_SLOT_NOTICE_ONCE path, the many of one make check,
# say each of them once between them. The exit status is COMMAND's.
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

# Knob $1, set to $2, is a count of 0 or more, or unset.
count_or_none() {
	[[ -z "$2" || "$2" =~ ^[0-9]+$ ]] && return 0
	echo "test: $1 takes a count of 0 or more, not '$2'" >&2
	exit 1
}
count_or_none TEST_SLOT_MIN_FREE_MB "${TEST_SLOT_MIN_FREE_MB-}"
count_or_none TEST_SLOT_MEMORY_WAIT "${TEST_SLOT_MEMORY_WAIT-}"

source "$(dirname "$0")/lib/fd_lock.sh" || exit 1
if [[ -z "$FD_LOCK_TOOL" ]]; then
	echo "test: none of flock, /usr/bin/lockf and perl is available: cannot take a slot of $LOCK" >&2
	exit 1
fi
source "$(dirname "$0")/lib/free_memory.sh" || exit 1

# The line "test: [NAME ]$2" on the notice descriptor — when TEST_SLOT_NOTICE_ONCE is
# set, only from the first run to claim it for notice $1 (slot, memory or memory-late).
notice() {
	if [[ -n "${TEST_SLOT_NOTICE_ONCE-}" ]]; then
		mkdir "$TEST_SLOT_NOTICE_ONCE.$1" 2>/dev/null || return 0
	fi
	echo "test: ${TEST_SLOT_NAME:+$TEST_SLOT_NAME }$2" >&"${TEST_SLOT_NOTICE_FD:-2}"
}

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
	notice slot "waiting for a test engine slot: $slots in use across the machine ($LOCK.*.flock)"
	until take_slot; do
		sleep 0.5
	done
fi

if [[ -n "${TEST_SLOT_MIN_FREE_MB-}" ]]; then
	min_free="$TEST_SLOT_MIN_FREE_MB"
else
	total="$(total_memory_mb)"
	min_free=$((${total:-0} / 10))
	((min_free == 0 || min_free >= 1024)) || min_free=1024
fi
free="$(free_memory_mb)"
if ((min_free > 0)) && [[ -n "$free" ]] && ((free < min_free)); then
	patience="${TEST_SLOT_MEMORY_WAIT:-1800}"
	notice memory "waiting for memory: $free MB free, $min_free MB wanted (TEST_SLOT_MIN_FREE_MB)"
	waited=0
	while free="$(free_memory_mb)" && [[ -n "$free" ]] && ((free < min_free)); do
		if ((waited >= patience)); then
			notice memory-late "memory still short after $patience s ($free MB free, $min_free MB wanted): running anyway"
			break
		fi
		sleep 2
		waited=$((waited + 2))
	done
fi

if [[ "${TEST_SLOT_NOTICE_FD-}" =~ ^[0-9]+$ ]]; then
	eval "exec $TEST_SLOT_NOTICE_FD>&-"
fi
unset TEST_SLOT_NOTICE_FD TEST_SLOT_NAME TEST_SLOT_NOTICE_ONCE
exec "$@"
