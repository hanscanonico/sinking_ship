#!/usr/bin/env bash
# Builds the game's GDExtension (native/, #410) for this machine: fetches godot-cpp at
# its pinned commit into native/build/godot-cpp, then SCons writes native/lib/ — the
# library and the sinking_native.gdextension that loads it. Nothing it writes is
# tracked: CI builds its own, and a checkout that never runs it plays the GDScript.
#
#   SCONS       the scons to run (default: scons on PATH; `pip install scons` in a venv)
#   LLVM_MINGW  Windows only: an unpacked llvm-mingw (github.com/mstorsjo/llvm-mingw),
#               whose bin/ holds x86_64-w64-mingw32-clang++; nothing goes on PATH
#   JOBS        compile jobs (default: the cores)
#   PLATFORM    windows on Linux: cross-compile the Windows library with mingw-w64
#               (x86_64-w64-mingw32-g++ on PATH), as CI's native (windows) job does
set -euo pipefail

# godot-cpp 10.0.0-stable, which carries the Godot 4.7 API (api_version=4.7 below).
GODOT_CPP_URL=https://github.com/godotengine/godot-cpp
GODOT_CPP_COMMIT=507ed9d840c01a3c5b2a39af8bb4000bfac30bf5

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/native/build"
cpp="$build/godot-cpp"

scons="${SCONS:-scons}"
if ! command -v "$scons" >/dev/null 2>&1; then
	echo "native: scons not found — pip install scons (a venv is fine) and pass SCONS=<path>" >&2
	exit 1
fi

args=(target=template_release api_version=4.7 lto=none "build_profile=$root/native/build_profile.json")
host="$(uname -s)"
if [[ -n "${PLATFORM:-}" ]]; then
	if [[ "$PLATFORM" != windows || "$host" != Linux ]]; then
		echo "native: PLATFORM=$PLATFORM — only PLATFORM=windows, on Linux, cross-compiles" >&2
		exit 1
	fi
	host=cross-windows
fi
case "$host" in
cross-windows) args+=(platform=windows arch=x86_64 use_mingw=yes) ;;
MINGW* | MSYS* | CYGWIN*)
	if [[ -z "${LLVM_MINGW:-}" ]]; then
		echo "native: LLVM_MINGW is not set — unpack llvm-mingw's ucrt-x86_64 release" >&2
		echo "native: (github.com/mstorsjo/llvm-mingw/releases) and pass LLVM_MINGW=<its folder>" >&2
		exit 1
	fi
	if [[ ! -x "$LLVM_MINGW/bin/x86_64-w64-mingw32-clang++" && ! -x "$LLVM_MINGW/bin/x86_64-w64-mingw32-clang++.exe" ]]; then
		echo "native: no x86_64-w64-mingw32-clang++ under $LLVM_MINGW/bin" >&2
		exit 1
	fi
	export PATH="$LLVM_MINGW/bin:$PATH"
	args+=(platform=windows arch=x86_64 use_mingw=yes use_llvm=yes "mingw_prefix=$LLVM_MINGW")
	;;
Darwin) args+=(platform=macos arch=universal) ;;
Linux) args+=(platform=linux arch=x86_64) ;;
*)
	echo "native: no build for $(uname -s)" >&2
	exit 1
	;;
esac

mkdir -p "$build"
# Out of Godot's sight: godot-cpp's test project holds scripts and an extension of its own.
: >"$build/.gdignore"
if [[ "$(git -C "$cpp" rev-parse HEAD 2>/dev/null || true)" != "$GODOT_CPP_COMMIT" ]]; then
	rm -rf "$cpp"
	git init -q "$cpp"
	git -C "$cpp" fetch -q --depth 1 "$GODOT_CPP_URL" "$GODOT_CPP_COMMIT"
	git -C "$cpp" checkout -q FETCH_HEAD
fi

jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
cd "$root/native"
"$scons" -j"$jobs" "${args[@]}"
