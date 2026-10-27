#!/usr/bin/env bash
#
# `make guard-check`, its third part: tools/test_slot.sh lets no more than
# TEST_SLOTS commands run at once, says once that a run waits — named, on its
# notice descriptor when given one —, lets a waiter through at once when a holder
# is killed with SIGKILL, defaults to half the cores, holds a run with its slot until
# its floor of memory is free, and hands back its command's exit status — on private
# lock files, with sleeps standing in for test engines and FREE_MEMORY_FILE for the
# system's free memory. Each step waits on what happened, never on how
# long it took, so a loaded machine only makes it slower; DEADLINE seconds is how
# long any one step may take before it fails.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

DEADLINE=60
WORK=$(mktemp -d)
export TEST_SLOT_LOCK="$WORK/slot"
# No floor but where a step sets one: the machine's own memory is no part of the check.
export TEST_SLOT_MIN_FREE_MB=0
unset TEST_SLOTS TEST_SLOT_NOTICE_FD TEST_SLOT_NAME TEST_SLOT_NOTICE_ONCE TEST_SLOT_MEMORY_WAIT FREE_MEMORY_FILE
PIDS=()
HOLDERS=()
trap 'kill -9 ${PIDS[@]+"${PIDS[@]}"} 2>/dev/null; rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "test-slot-check: $1" >&2
	fails=1
}

# Waits until the shell condition $1 holds, DEADLINE seconds at most.
wait_for() {
	local i
	for ((i = 0; i < DEADLINE * 10; i++)); do
		eval "$1" && return 0
		sleep 0.1
	done
	return 1
}

# A run that marks its start as $1.start and holds its slot until $1.release.
hold() {
	tools/test_slot.sh bash -c "touch '$WORK/$1.start'; until [ -e '$WORK/$1.release' ]; do sleep 0.1; done
		touch '$WORK/$1.end'" 2>"$WORK/$1.err" &
	PIDS+=($!)
	HOLDERS+=($!)
}

# Waits for every run hold started to end, so the next step finds its slots free.
end_holders() {
	local pid
	for pid in ${HOLDERS[@]+"${HOLDERS[@]}"}; do
		wait "$pid"
	done
	HOLDERS=()
}

# Two slots: two runs hold one each at once; a third waits, says so once, and
# starts only once one of them has ended.
export TEST_SLOTS=2
hold a
hold b
if wait_for "[ -e '$WORK/a.start' ] && [ -e '$WORK/b.start' ]"; then
	[[ -s "$WORK/a.err" || -s "$WORK/b.err" ]] && fail "a run waited with a slot free"
	tools/test_slot.sh bash -c "{ [ -e '$WORK/a.end' ] || [ -e '$WORK/b.end' ]; } && touch '$WORK/c.ok'
		touch '$WORK/c.ran'" 2>"$WORK/c.err" &
	PIDS+=($!)
	third=$!
	wait_for "grep -q 'waiting for a test engine slot' '$WORK/c.err'" ||
		fail "the third run never said it was waiting"
	[[ -e "$WORK/c.ran" ]] && fail "a third run started while both slots were held"
	touch "$WORK/a.release"
	wait_for "[ -e '$WORK/c.ran' ]" || fail "the third run never ran after a slot freed"
	wait "$third"
	[[ -e "$WORK/c.ok" ]] || fail "the third run started before a slot freed"
	(($(grep -c . "$WORK/c.err") == 1)) || fail "the waiting run said $(grep -c . "$WORK/c.err") lines, not one"
else
	fail "two runs never held the two slots at once"
fi
touch "$WORK/a.release" "$WORK/b.release"
end_holders

# A holder killed with SIGKILL: the kernel drops its slot, and the waiter goes on.
export TEST_SLOTS=1
tools/test_slot.sh bash -c "touch '$WORK/h.start'; exec sleep 600" &
PIDS+=($!)
holder=$!
if wait_for "[ -e '$WORK/h.start' ]"; then
	tools/test_slot.sh touch "$WORK/w.ran" 2>"$WORK/w.err" &
	PIDS+=($!)
	waiter=$!
	wait_for "grep -q 'waiting for a test engine slot' '$WORK/w.err'" ||
		fail "the waiter never said it was waiting on the holder"
	[[ -e "$WORK/w.ran" ]] && fail "the waiter ran while the holder held the only slot"
	kill -9 "$holder"
	wait "$holder" 2>/dev/null
	wait_for "[ -e '$WORK/w.ran' ]" || fail "the slot outlived a holder killed with SIGKILL"
	wait "$waiter"
else
	fail "the holder never started"
fi

# Side-by-side shards: the waiting line goes, named, to the descriptor
# TEST_SLOT_NOTICE_FD numbers rather than stderr, and that descriptor is closed
# before the command runs.
tools/test_slot.sh bash -c "touch '$WORK/s.start'; until [ -e '$WORK/s.release' ]; do sleep 0.1; done" &
PIDS+=($!)
sayer=$!
if wait_for "[ -e '$WORK/s.start' ]"; then
	TEST_SLOT_NOTICE_FD=7 TEST_SLOT_NAME="shard 3/4" tools/test_slot.sh \
		bash -c "{ true >&7; } 2>/dev/null || touch '$WORK/n.closed'; touch '$WORK/n.ran'" \
		7>"$WORK/n.say" 2>"$WORK/n.err" &
	PIDS+=($!)
	named=$!
	wait_for "grep -q '^test: shard 3/4 waiting for a test engine slot' '$WORK/n.say'" ||
		fail "the named waiter never said so on its notice descriptor"
	touch "$WORK/s.release"
	wait "$sayer"
	wait_for "[ -e '$WORK/n.ran' ]" || fail "the named waiter never ran after the slot freed"
	wait "$named"
	[[ -s "$WORK/n.err" ]] && fail "the named waiter wrote to stderr: $(cat "$WORK/n.err")"
	[[ -e "$WORK/n.closed" ]] || fail "the notice descriptor was still open in the command"
else
	fail "the holder before the named waiter never started"
fi

# Unset, the count is half the cores, at least one: that many hold at once, and
# one more waits.
unset TEST_SLOTS
cores=$(getconf _NPROCESSORS_ONLN)
want=$((cores / 2 > 1 ? cores / 2 : 1))
for ((k = 1; k <= want; k++)); do
	hold "d$k"
done
if wait_for "[ \$(ls '$WORK' | grep -c '^d[0-9]*\.start\$') -eq $want ]"; then
	tools/test_slot.sh touch "$WORK/e.ran" 2>"$WORK/e.err" &
	PIDS+=($!)
	extra=$!
	wait_for "grep -q 'waiting for a test engine slot' '$WORK/e.err'" ||
		fail "with $cores cores, run $((want + 1)) never waited"
	touch "$WORK/d1.release"
	wait_for "[ -e '$WORK/e.ran' ]" || fail "the extra run never ran after a slot freed"
	wait "$extra"
else
	fail "with $cores cores, $want runs never held a slot each at once"
fi
for ((k = 1; k <= want; k++)); do
	touch "$WORK/d$k.release"
done
end_holders

# The memory floor: with its slot taken, a run short of TEST_SLOT_MIN_FREE_MB waits,
# says so once, and starts as soon as that much is free.
export TEST_SLOTS=2 FREE_MEMORY_FILE="$WORK/free"
echo 100 >"$WORK/free"
TEST_SLOT_MIN_FREE_MB=500 tools/test_slot.sh touch "$WORK/m.ran" 2>"$WORK/m.err" &
PIDS+=($!)
short=$!
wait_for "grep -q 'waiting for memory: 100 MB free, 500 MB wanted' '$WORK/m.err'" ||
	fail "a run short of memory never said it was waiting for it"
[[ -e "$WORK/m.ran" ]] && fail "a run started with less memory free than its floor"
echo 600 >"$WORK/free"
wait_for "[ -e '$WORK/m.ran' ]" || fail "the run short of memory never ran once it was free"
wait "$short"
(($(grep -c . "$WORK/m.err") == 1)) || fail "the run short of memory said $(grep -c . "$WORK/m.err") lines, not one"

# Past TEST_SLOT_MEMORY_WAIT seconds it says so and runs anyway; at a floor of 0 it
# never waits.
echo 100 >"$WORK/free"
TEST_SLOT_MIN_FREE_MB=500 TEST_SLOT_MEMORY_WAIT=2 tools/test_slot.sh touch "$WORK/p.ran" 2>"$WORK/p.err" ||
	fail "a run out of patience failed"
[[ -e "$WORK/p.ran" ]] || fail "a run out of patience never ran"
grep -q 'memory still short after 2 s .*: running anyway' "$WORK/p.err" ||
	fail "a run out of patience never said it ran anyway: $(cat "$WORK/p.err")"
tools/test_slot.sh touch "$WORK/z.ran" 2>"$WORK/z.err"
[[ -e "$WORK/z.ran" && ! -s "$WORK/z.err" ]] || fail "a floor of 0 still waited for memory"

# Unset, the floor is a tenth of the machine's memory, at least 1024 MB.
echo 1 >"$WORK/free"
(unset TEST_SLOT_MIN_FREE_MB && TEST_SLOT_MEMORY_WAIT=0 tools/test_slot.sh touch "$WORK/f.ran" 2>"$WORK/f.err")
grep -qE 'waiting for memory: 1 MB free, [0-9]{4,} MB wanted' "$WORK/f.err" ||
	fail "unset, the floor was not a tenth of the memory, at least 1024 MB: $(cat "$WORK/f.err")"

# Runs sharing a TEST_SLOT_NOTICE_ONCE path say a wait once between them.
echo 100 >"$WORK/free"
for k in 1 2; do
	TEST_SLOT_MIN_FREE_MB=500 TEST_SLOT_NOTICE_ONCE="$WORK/once" \
		tools/test_slot.sh touch "$WORK/o$k.ran" 2>"$WORK/o$k.err" &
	PIDS+=($!)
	HOLDERS+=($!)
done
wait_for "[ -d '$WORK/once.memory' ]" || fail "runs sharing a notice path never claimed it"
echo 600 >"$WORK/free"
end_holders
said=$(cat "$WORK/o1.err" "$WORK/o2.err" | grep -c 'waiting for memory')
((said == 1)) || fail "runs sharing TEST_SLOT_NOTICE_ONCE said they waited $said times, not once"
unset TEST_SLOTS FREE_MEMORY_FILE

# The command's own exit status; a count that is not one is refused, nothing run.
tools/test_slot.sh bash -c 'exit 7' 2>/dev/null
status=$?
((status == 7)) || fail "exit 7 came back as $status"
tools/test_slot.sh true || fail "a clean run failed"
for bad in 0 -1 two; do
	TEST_SLOTS=$bad tools/test_slot.sh touch "$WORK/bad.ran" 2>/dev/null &&
		fail "TEST_SLOTS=$bad was taken"
	[[ -e "$WORK/bad.ran" ]] && fail "TEST_SLOTS=$bad ran its command"
done
for bad in -1 lots; do
	TEST_SLOT_MIN_FREE_MB=$bad tools/test_slot.sh touch "$WORK/bad.ran" 2>/dev/null &&
		fail "TEST_SLOT_MIN_FREE_MB=$bad was taken"
	[[ -e "$WORK/bad.ran" ]] && fail "TEST_SLOT_MIN_FREE_MB=$bad ran its command"
done

((fails == 0)) && echo "test-slot-check: ok"
exit "$fails"
