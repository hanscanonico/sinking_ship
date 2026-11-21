#!/usr/bin/env bash
#
# The game's GDExtension (native/, #410) kept built for the tests: `make import`, `make
# test` and `make test-changed` run this first. native/lib is built per checkout and
# never tracked, so a fresh worktree has none, and one that pulled a change to
# native/src holds a stale one, which the game treats as absent (NativeVersion): either
# way the suite runs the GDScript, the same answers several times slower — eight of its
# heavy scripts took 328 s for 70 s with the library on the Windows box, 2026-11-21 —
# and nothing said so. A cold build is half a minute.
#
# Nothing to do, and nothing said, when this platform's library carries the digest of
# the native/src beside it (the one native/SConstruct builds in, NativeAbi.source).
# Otherwise it builds (tools/native_build.sh) and, the extension being new to this
# checkout's .godot, imports once to register it. A machine with no scons, or on Windows
# no LLVM_MINGW, cannot build: one line says the suite runs the GDScript, and the run
# goes on. A build that fails fails the run, as CI's would.
#
#   NATIVE_ENSURE=0   leave native/lib as it is and say nothing
#   --no-import       build only: the caller imports next (make import)
#
# Usage:  tools/native_ensure.sh [--no-import]

set -uo pipefail
source "$(dirname "$0")/lib/require_godot.sh" || exit 1
cd "$(dirname "$0")/.." || exit 1

[[ "${NATIVE_ENSURE-1}" != 0 ]] || exit 0

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) platform=windows ;;
Darwin) platform=macos ;;
Linux) platform=linux ;;
*) exit 0 ;;
esac

sha256() {
	if command -v sha256sum >/dev/null; then
		sha256sum
	else
		shasum -a 256
	fi
}

# native/SConstruct's source_digest: every .cpp and .h of native/src by name, each as
# its name, a newline, its size in bytes, a newline, its bytes.
digest="$(
	cd native/src 2>/dev/null || exit 0
	for name in $(printf '%s\n' *.cpp *.h | LC_ALL=C sort); do
		[[ -f "$name" ]] || continue
		printf '%s\n%s\n' "$name" "$(wc -c <"$name" | tr -d ' ')"
		cat "$name"
	done | sha256 | cut -d' ' -f1
)"
[[ -n "$digest" ]] || exit 0

why="has no library for $platform"
for library in native/lib/libsinking_native."$platform".*; do
	[[ -f "$library" ]] || continue
	grep -a -q "$digest" "$library" && exit 0
	why="was built from other sources than native/src"
done

slower="the tests run the GDScript, several times slower (native/README.md)"
if ! command -v "${SCONS:-scons}" >/dev/null 2>&1; then
	echo "native: native/lib $why, and there is no scons to build it — $slower" >&2
	exit 0
fi
if [[ "$platform" == windows && -z "${LLVM_MINGW-}" ]]; then
	echo "native: native/lib $why, and LLVM_MINGW is not set to build it — $slower" >&2
	exit 0
fi

echo "native: native/lib $why — building it (tools/native_build.sh)"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
if ! tools/native_build.sh >"$log" 2>&1; then
	tail -40 "$log" >&2
	echo "native: the build failed — NATIVE_ENSURE=0 runs without it" >&2
	exit 1
fi

[[ "${1-}" != --no-import ]] || exit 0
if ! grep -qs 'native/lib/sinking_native.gdextension' .godot/extension_list.cfg; then
	require_godot native
	"$GODOT" --headless --path . --import >"$log" 2>&1 || {
		tail -20 "$log" >&2
		echo "native: the import that registers the extension failed" >&2
		exit 1
	}
fi
exit 0
