#!/usr/bin/env bash
#
# `make guard-check`: tools/engine_guard.sh fails a run the engine errored in and
# passes one it did not, with a stand-in for the engine — Godot itself exits 0
# after a SCRIPT ERROR, which is the whole reason the guard exists. And the engine
# ends with whoever asked for it: a stand-in requester killed, and a make killed
# under its recipe, each stop a stand-in engine that would otherwise sleep on. Each
# of those steps waits on what happened, never on how long it took; DEADLINE seconds
# is how long one may take before it fails.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

DEADLINE=60
WORK=$(mktemp -d)
PIDS=()
trap 'kill -9 ${PIDS[@]+"${PIDS[@]}"} 2>/dev/null; rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "guard-check: $1" >&2
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

# The scan alone: no watchdog, so no Windows parents read for each of these.
expect() {
	local want="$1" label="$2"
	shift 2
	ENGINE_GUARD_WATCH=0 tools/engine_guard.sh "$@" >/dev/null 2>&1
	local got=$?
	if ((got != want)); then
		fail "$label: exit $got, wanted $want"
	fi
}

expect 0 "a clean run" bash -c 'echo out; echo "WARNING: slow" >&2'
expect 1 "SCRIPT ERROR on stderr, engine exits 0" bash -c 'printf "SCRIPT ERROR: boom\n   at: x\n" >&2'
expect 1 "ERROR on stdout, engine exits 0" bash -c 'echo "ERROR: Too many instances using shader instance variables"'
expect 1 "coloured ERROR" bash -c 'printf "\033[31mERROR: red\033[0m\n" >&2'
expect 3 "the command's own failure" bash -c 'exit 3'
expect 0 "the godot_ai helper's lines" bash -c 'echo "[godot_ai] ERROR: not ours"'
expect 0 "a leak report at exit" bash -c 'echo "ERROR: 4 resources still in use at exit (run with --verbose for details)." >&2'
leaks='printf "ERROR: 3 shaders of type SceneShaderGLES3 were never freed\nERROR: Buffer with GL ID of 98: leaked 216 bytes.\nERROR: Texture with GL ID of 37: leaked 4096 bytes.\n" >&2'
expect 0 "the renderer's GL leak report at exit" bash -c "echo captured; $leaks"
expect 1 "a SCRIPT ERROR among the GL leak report" bash -c "printf 'SCRIPT ERROR: boom\n' >&2; $leaks"
expect 1 "an ERROR that only mentions a leak" bash -c 'echo "ERROR: Buffer with GL ID of 9: leaked 216 bytes, then the draw failed" >&2'
ENGINE_GUARD_PATTERN='SCRIPT ERROR:' expect 0 "a deliberate push_error under a script-only pattern" bash -c 'echo "ERROR: CSPRNG gave 3 of 4 bytes" >&2'
ENGINE_GUARD_PATTERN='SCRIPT ERROR:' expect 1 "a script error under a script-only pattern" bash -c 'echo "SCRIPT ERROR: boom" >&2'
ENGINE_GUARD_IGNORE='expected' expect 0 "an ignored error" bash -c 'echo "ERROR: expected thing"'

# A run beside its watchdog ends as it would without one, its output whole.
said="$(MAKELEVEL=1 ENGINE_GUARD_WATCH_EVERY=1 tools/engine_guard.sh bash -c 'sleep 2; echo out' 2>/dev/null)"
status=$?
((status == 0)) || fail "a clean run beside its watchdog: exit $status, wanted 0"
[[ "$said" == out ]] || fail "a clean run beside its watchdog said '$said', not 'out'"

# The requester named by ENGINE_GUARD_WATCH_PID killed while its engine runs: the
# watchdog stops the engine and the guard says why.
sleep 600 &
PIDS+=($!)
requester=$!
ENGINE_GUARD_WATCH_PID=$requester ENGINE_GUARD_WATCH_EVERY=1 ENGINE_GUARD_ARMED="$WORK/a.armed" \
	tools/engine_guard.sh bash -c "echo \$\$ >'$WORK/a.pid'; exec sleep 600" >/dev/null 2>"$WORK/a.err" &
PIDS+=($!)
guard=$!
if wait_for "[ -s '$WORK/a.pid' ] && [ -e '$WORK/a.armed' ]"; then
	engine=$(cat "$WORK/a.pid")
	PIDS+=("$engine")
	kill -0 "$engine" 2>/dev/null || fail "the stand-in engine ended before its requester did"
	kill -9 "$requester"
	wait "$requester" 2>/dev/null
	if wait_for "! kill -0 $engine 2>/dev/null"; then
		wait "$guard"
		grep -q 'is gone: stopping its engine' "$WORK/a.err" ||
			fail "the guard never said why it stopped the engine: $(cat "$WORK/a.err")"
	else
		fail "the engine outlived its requester"
	fi
else
	fail "the guard never started its engine beside a watchdog"
fi

# A make killed under its recipe, as a `timeout` around make does, with the guard in a
# pipeline as the Makefile runs it: found above the guard without being named — the
# make itself, or on Windows, where a native make is out of Git Bash's sight, the
# recipe's shell that dies with it.
cat >"$WORK/Makefile" <<EOF
SHELL := /bin/bash
all:
	@set -o pipefail; ENGINE_GUARD_WATCH_EVERY=1 ENGINE_GUARD_ARMED='$WORK/b.armed' '$PWD/tools/engine_guard.sh' bash -c 'echo \$\$\$\$ >"$WORK/b.pid"; exec sleep 600' | cat
EOF
make -s -f "$WORK/Makefile" >/dev/null 2>"$WORK/b.err" &
PIDS+=($!)
make=$!
if wait_for "[ -s '$WORK/b.pid' ] && [ -e '$WORK/b.armed' ]"; then
	engine=$(cat "$WORK/b.pid")
	PIDS+=("$engine")
	kill -9 "$make"
	wait "$make" 2>/dev/null
	wait_for "! kill -0 $engine 2>/dev/null" || fail "the engine outlived the make that ran it"
else
	fail "the make never started its engine: $(cat "$WORK/b.err")"
fi

((fails == 0)) && echo "guard-check: ok"
exit "$fails"
