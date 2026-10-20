#!/usr/bin/env bash
#
# `make guard-check`: tools/engine_guard.sh fails a run the engine errored in and
# passes one it did not, with a stand-in for the engine — Godot itself exits 0
# after a SCRIPT ERROR, which is the whole reason the guard exists.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fails=0
expect() {
	local want="$1" label="$2"
	shift 2
	tools/engine_guard.sh "$@" >/dev/null 2>&1
	local got=$?
	if ((got != want)); then
		echo "guard-check: $label: exit $got, wanted $want" >&2
		fails=1
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

((fails == 0)) && echo "guard-check: ok"
exit "$fails"
