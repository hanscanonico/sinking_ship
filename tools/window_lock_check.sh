#!/usr/bin/env bash
#
# `make guard-check`, its second half: tools/window_lock.sh serialises two runs,
# lets a waiter through at once when the holder is killed with SIGKILL, hands
# back its command's exit status and does not wait on itself under a holder, and
# tools/fps.sh takes it again when the lock it is told it holds is another file,
# but not when it is the same file spelled another way —
# on a private lock file, with shell stand-ins for the game. Each step waits on
# what happened, never on how long it took, so a loaded machine only makes it
# slower; DEADLINE seconds is how long any one step may take before it fails.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

DEADLINE=60
WORK=$(mktemp -d)
export WINDOW_LOCK="$WORK/window.flock"
unset WINDOW_LOCK_HELD
PIDS=()
trap 'kill -9 ${PIDS[@]+"${PIDS[@]}"} 2>/dev/null; rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "window-lock-check: $1" >&2
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

# Two runs: the second waits, says so, and starts only once the first has ended.
tools/window_lock.sh bash -c "touch '$WORK/a.start'; until [ -e '$WORK/release' ]; do sleep 0.1; done
	touch '$WORK/a.end'" &
PIDS+=($!)
first=$!
if wait_for "[ -e '$WORK/a.start' ]"; then
	tools/window_lock.sh bash -c "[ -e '$WORK/a.end' ] && touch '$WORK/b.ok'; touch '$WORK/b.ran'" \
		2>"$WORK/b.err" &
	PIDS+=($!)
	second=$!
	wait_for "grep -q 'waiting for another game window' '$WORK/b.err'" ||
		fail "the second run never said it was waiting"
	[[ -e "$WORK/b.ran" ]] && fail "the second run started while the first held the lock"
	touch "$WORK/release"
	wait "$first"
	wait_for "[ -e '$WORK/b.ran' ]" || fail "the second run never ran after the first ended"
	wait "$second"
	[[ -e "$WORK/b.ok" ]] || fail "the second run started before the first ended"
else
	fail "the first run never started"
fi

# A holder killed with SIGKILL: the kernel drops its lock, and the waiter goes on.
tools/window_lock.sh bash -c "touch '$WORK/h.start'; exec sleep 600" &
PIDS+=($!)
holder=$!
if wait_for "[ -e '$WORK/h.start' ]"; then
	tools/window_lock.sh touch "$WORK/w.ran" 2>"$WORK/w.err" &
	PIDS+=($!)
	waiter=$!
	wait_for "grep -q 'waiting for another game window' '$WORK/w.err'" ||
		fail "the waiter never said it was waiting on the holder"
	[[ -e "$WORK/w.ran" ]] && fail "the waiter ran while the holder held the lock"
	kill -9 "$holder"
	wait "$holder" 2>/dev/null
	wait_for "[ -e '$WORK/w.ran' ]" || fail "the lock outlived a holder killed with SIGKILL"
	wait "$waiter"
else
	fail "the holder never started"
fi

# A waiter sleeps while it waits: over a five-second wait the processes it runs
# spend well under half a second of CPU between them (macOS lockf(1) waiting on a
# descriptor spins). Read off ps, as rusage leaves lockf's spin out.
tree_cpu() {
	local pids=$1 next=$1 kids
	while [[ -n "$next" ]]; do
		kids=$(pgrep -P "${next//[[:space:]]/,}" | paste -sd, -)
		[[ -n "$kids" ]] && pids="$pids,$kids"
		next=$kids
	done
	LC_ALL=C ps -o time= -p "$pids" | LC_ALL=C awk -F: '{ s += $(NF-1) * 60 + $NF } END { print s + 0 }'
}
tools/window_lock.sh bash -c "touch '$WORK/c.start'; until [ -e '$WORK/c.release' ]; do sleep 0.1; done" &
PIDS+=($!)
holder=$!
if wait_for "[ -e '$WORK/c.start' ]"; then
	tools/window_lock.sh touch "$WORK/c.ran" 2>"$WORK/c.err" &
	PIDS+=($!)
	waiter=$!
	wait_for "grep -q 'waiting for another game window' '$WORK/c.err'" ||
		fail "the idle waiter never said it was waiting"
	sleep 5
	cpu=$(tree_cpu "$waiter")
	LC_ALL=C awk -v c="$cpu" 'BEGIN { exit !(c < 0.5) }' ||
		fail "a waiter spent ${cpu}s of CPU over a five-second wait"
	touch "$WORK/c.release"
	wait "$holder"
	wait "$waiter"
else
	fail "the holder for the idle waiter never started"
fi

# The command's own exit status.
tools/window_lock.sh bash -c 'exit 7' 2>/dev/null
status=$?
((status == 7)) || fail "exit 7 came back as $status"
tools/window_lock.sh true || fail "a clean run failed"

# Under a holder a nested run goes straight through rather than wait on itself.
tools/window_lock.sh bash -c "tools/window_lock.sh touch '$WORK/n.ran'" &
PIDS+=($!)
wait_for "[ -e '$WORK/n.ran' ]" || fail "a run under a holder waited on itself"

# fps under a lock on another file: it takes this one too, and waits on its holder.
printf '#!/usr/bin/env bash\ntouch %q\n' "$WORK/f.ran" >"$WORK/godot"
chmod +x "$WORK/godot"
tools/window_lock.sh bash -c "touch '$WORK/g.start'; until [ -e '$WORK/g.release' ]; do sleep 0.1; done" &
PIDS+=($!)
holder=$!
if wait_for "[ -e '$WORK/g.start' ]"; then
	WINDOW_LOCK_HELD="$WORK/other.flock" GODOT="$WORK/godot" tools/fps.sh --seconds=5 \
		>/dev/null 2>"$WORK/f.err" &
	PIDS+=($!)
	fps=$!
	wait_for "grep -q 'waiting for another game window' '$WORK/f.err'" ||
		fail "fps under a lock on another file never waited for the window lock"
	[[ -e "$WORK/f.ran" ]] && fail "fps under a lock on another file ran while the holder held the lock"
	touch "$WORK/g.release"
	wait "$holder"
	wait_for "[ -e '$WORK/f.ran' ]" || fail "fps never ran after the holder ended"
	wait "$fps"
else
	fail "the holder for fps never started"
fi

# fps under a holder of the same file spelled another way — through a symlinked
# directory — knows it holds the lock, and runs rather than wait on itself.
ln -s "$WORK" "$WORK/alias"
printf '#!/usr/bin/env bash\ntouch %q\n' "$WORK/s.ran" >"$WORK/godot2"
chmod +x "$WORK/godot2"
tools/window_lock.sh bash -c "WINDOW_LOCK='$WORK/alias/window.flock' GODOT='$WORK/godot2' \
	tools/fps.sh --seconds=5 >/dev/null 2>'$WORK/s.err'" &
PIDS+=($!)
wait_for "[ -e '$WORK/s.ran' ]" || fail "fps under the same lock file spelled another way waited on itself"
grep -q 'waiting for another game window' "$WORK/s.err" 2>/dev/null &&
	fail "fps under the same lock file spelled another way waited for the window lock"

((fails == 0)) && echo "window-lock-check: ok"
exit "$fails"
