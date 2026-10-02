# One answer to "which engine, and is it here?" for every gate script.
#
# $GODOT wins when it is set — CI points it at the Linux build it fetches.
# Otherwise a vendored bin/Godot.app is used when the checkout has one, and
# `godot` on PATH when it does not; the Makefile resolves its own GODOT the same
# way. A path that is executable and a name `command -v` resolves are equally
# good.
#
# Sourced by tools/check_scripts.sh and tools/run_tests.sh, which call
# require_godot after cd-ing to the repo root, so the vendored path resolves.
# The label is the prefix the caller already writes its own diagnostics with.
#
# It exits rather than returning: every caller's answer to a missing engine is
# the same, and a `set -e`-less script that forgot the `|| exit` would run the
# whole gate against a binary that is not there.

VENDORED_GODOT="bin/Godot.app/Contents/MacOS/Godot"

require_godot() {
	local label="$1"
	if [[ -z "${GODOT:-}" ]]; then
		if [[ -x "$VENDORED_GODOT" ]]; then
			GODOT="$VENDORED_GODOT"
		else
			GODOT="godot"
		fi
	fi
	export GODOT
	if [[ -x "$GODOT" ]] || command -v "$GODOT" >/dev/null; then
		return 0
	fi
	echo "$label: Godot binary not found at $GODOT" >&2
	echo "$label: install Godot 4.7 so \`godot\` is on PATH, or pass GODOT=<path>" >&2
	exit 1
}
