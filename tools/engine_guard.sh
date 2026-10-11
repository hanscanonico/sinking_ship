#!/usr/bin/env bash
#
# Runs an engine command and fails when the engine printed an error.
#
# Godot exits 0 after a SCRIPT ERROR in a headless tool or a renderer ERROR, so a
# transcript, a census or a capture that lost a section to a crash looked like a
# success. This wraps the command, passes its stdout and stderr through as they
# come, and once it has exited scans both for the engine's error lines. Any
# match, or the command's own failure, is a failure: deterministic, no judgement.
#
# Usage:  tools/engine_guard.sh "$GODOT" --headless --path . -s res://tools/x.gd -- args
#         tools/engine_guard.sh "$GODOT" ... | grep -v '^\[godot_ai'
#
# What counts: a line that begins (after colour codes) with SCRIPT ERROR:, USER
# ERROR:, SHADER ERROR: or ERROR: — "Parse Error:" lines too. WARNING: lines do
# not. The godot_ai helper autoload's own lines (`[godot_ai ...`) are not
# scanned.
#
# The engine's shutdown reports of resources still in use at exit are not a run's
# errors and are let through. ENGINE_GUARD_PATTERN is an extended regex that replaces
# the lines that count (the test runner counts script errors alone: its tests provoke
# engine errors on purpose); ENGINE_GUARD_IGNORE an extended regex of matching lines
# to let through.

set -uo pipefail

if (($# == 0)); then
	echo "engine_guard: a command is required" >&2
	exit 1
fi

OUT="$(mktemp)"
ERR="$(mktemp)"
STATUS="$(mktemp)"
trap 'rm -f "$OUT" "$ERR" "$STATUS"' EXIT

# stderr takes the outer fd 2 through its own tee, stdout the outer pipe through
# the other, so each stays on its own stream and both are kept for the scan.
{
	{
		"$@"
		echo $? >"$STATUS"
	} 2>&1 1>&3 3>&- | tee "$ERR" >&2
} 3>&1 | tee "$OUT"

status="$(cat "$STATUS" 2>/dev/null)"
status="${status:-1}"

errors="$(
	cat "$OUT" "$ERR" |
		sed $'s/\033\[[0-9;]*m//g' |
		grep -v '^\[godot_ai' |
		grep -E "${ENGINE_GUARD_PATTERN:-^[[:space:]]*((SCRIPT|USER|SHADER) )?ERROR:|^[[:space:]]*Parse Error:}" |
		grep -Ev 'still in use at exit|leaked at exit|exist at exit in PagedAllocator' |
		{ if [[ -n "${ENGINE_GUARD_IGNORE:-}" ]]; then grep -Ev "$ENGINE_GUARD_IGNORE"; else cat; fi; } |
		sort | uniq -c | sort -rn
)"

if [[ -n "$errors" ]]; then
	count="$(awk '{ n += $1 } END { print n + 0 }' <<<"$errors")"
	{
		echo "engine_guard: the engine printed $count error line(s) — a run that errors is not a pass:"
		head -n 10 <<<"$errors"
		if (($(wc -l <<<"$errors") > 10)); then
			echo "  … and more distinct errors"
		fi
	} >&2
	exit 1
fi

exit "$status"
