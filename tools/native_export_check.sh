#!/usr/bin/env bash
#
# Stops a desktop `make export-*` before it starts when the game's GDExtension
# (native/, #410) has no library for the export's platform: Godot would only warn,
# and ship a game that cannot load it. native/lib/sinking_native.gdextension must list
# FEATURE (linux.x86_64, windows.x86_64 or macos), and the library it names must be
# there. NATIVE=0 lets the export go on without it: the game then runs the GDScript
# (and logs that no library loads for it, when native/lib holds other platforms').
#
# Usage:  tools/native_export_check.sh FEATURE

set -uo pipefail

if (($# != 1)); then
	echo "export: usage: tools/native_export_check.sh FEATURE" >&2
	exit 2
fi
feature="$1"
extension=native/lib/sinking_native.gdextension

library=""
if [[ -f "$extension" ]]; then
	library="$(tr -d '\r' <"$extension" | sed -n "s|^$feature = \"res://\(.*\)\"\$|\1|p" | head -n 1)"
fi
if [[ -n "$library" && -f "$library" ]]; then
	echo "export: $feature ships $library"
	exit 0
fi

if [[ "${NATIVE:-}" == 0 ]]; then
	echo "export: NATIVE=0 — no native library for $feature; the export runs the GDScript" >&2
	exit 0
fi
echo "export: no native library for $feature in native/lib (${library:-$extension lists none})" >&2
case "$feature" in
macos) where="make native on a Mac, or CI's native-macos artifact" ;;
windows.*) where="make native on Windows, or CI's native-windows artifact" ;;
*) where="make native on Linux, or CI's native-linux artifact" ;;
esac
echo "export: build it ($where: put the library in native/lib and run make native to list it)," \
	"or pass NATIVE=0 to export without it and run the GDScript" >&2
exit 1
