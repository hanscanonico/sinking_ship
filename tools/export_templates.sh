#!/usr/bin/env bash
#
# Fails fast, in one clear line, when Godot's export templates for the engine's
# exact version are not installed: without them `--export-release` runs for a
# while and then fails with an error that names neither the version nor where the
# templates belong. Every `make export-*` runs it first.
#
# The templates live in a folder named for the version `godot --version` reports,
# up to its status (4.7.1.stable), under the engine's data folder: %APPDATA% on
# Windows, ~/Library/Application Support on macOS, $XDG_DATA_HOME (else
# ~/.local/share) on Linux.
#
# Usage:  tools/export_templates.sh GODOT

set -uo pipefail

if (($# != 1)); then
	echo "export: usage: tools/export_templates.sh GODOT" >&2
	exit 2
fi

version="$("$1" --version 2>/dev/null | tr -d '\r' | grep -oE '^[0-9]+(\.[0-9]+)+\.[a-z0-9_]+' | head -n 1)"
if [[ -z "$version" ]]; then
	echo "export: could not read the engine's version from $1 --version" >&2
	exit 1
fi

case "$(uname -s)" in
Darwin) data="$HOME/Library/Application Support/Godot" ;;
MINGW* | MSYS* | CYGWIN*) data="${APPDATA:-$HOME/AppData/Roaming}/Godot" ;;
*) data="${XDG_DATA_HOME:-$HOME/.local/share}/godot" ;;
esac
templates="$data/export_templates/$version"

if [[ ! -f "$templates/version.txt" ]]; then
	echo "export: no export templates for Godot $version in $templates" >&2
	echo "export: install them from the editor (Editor > Manage Export Templates) or unpack" \
		"Godot_v${version%.*}-${version##*.}_export_templates.tpz's templates/ there" >&2
	exit 1
fi
