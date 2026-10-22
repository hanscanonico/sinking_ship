#!/usr/bin/env bash
#
# Packs the desktop exports as the release's zips, one per platform:
# build/release/LastOneDry-VERSION-{windows,linux,mac}.zip, each holding the game,
# README.txt (tools/release/README.txt, its @VERSION@ filled in) and licenses/ —
# the assets' register, the font's OFL, and Godot's licence and third-party notices
# (tools/release/godot/, as the engine's tag has them). Every platform asked for
# must have been exported first: `make export-win export-linux export-mac`.
# .github/workflows/release.yml runs it on every vX.Y.Z tag.
#
# Usage:  tools/package_release.sh VERSION [windows] [linux] [mac]   (all three by default)

set -euo pipefail

if (($# < 1)); then
	echo "package: usage: tools/package_release.sh VERSION [windows] [linux] [mac]" >&2
	exit 2
fi
version="$1"
shift
platforms=("$@")
((${#platforms[@]})) || platforms=(windows linux mac)

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/release"
mkdir -p "$out"
touch "$root/build/.gdignore"

# The game each platform ships: what its make export-* target writes.
game_of() {
	case "$1" in
	windows) echo "build/win/LastOneDry.exe" ;;
	linux) echo "build/linux/LastOneDry.x86_64" ;;
	mac) echo "build/mac/LastOneDry.app" ;;
	*) return 1 ;;
	esac
}

# zip keeps the Linux binary's executable bit and the .app's links; where it is
# missing (Git Bash on Windows) Python's zipfile stands in.
pack() {
	local zip="$1"
	rm -f "$zip"
	if command -v zip >/dev/null; then
		zip -q -r -y -X "$zip" .
	else
		python3 -m zipfile -c "$zip" ./*
	fi
}

for platform in "${platforms[@]}"; do
	if ! game="$(game_of "$platform")"; then
		echo "package: no platform $platform (windows, linux or mac)" >&2
		exit 2
	fi
	if [[ ! -e "$root/$game" ]]; then
		echo "package: no $game: make export-${platform/windows/win} first" >&2
		exit 1
	fi
	stage="$out/stage/$platform"
	rm -rf "$stage"
	mkdir -p "$stage/licenses"
	cp -R "$root/$game" "$stage/"
	sed "s/@VERSION@/$version/g" "$root/tools/release/README.txt" >"$stage/README.txt"
	cp "$root/assets/LICENSES.md" "$stage/licenses/ASSETS.md"
	cp "$root/assets/fonts/OFL.txt" "$stage/licenses/OFL.txt"
	cp "$root/tools/release/godot/LICENSE.txt" "$stage/licenses/GODOT_LICENSE.txt"
	cp "$root/tools/release/godot/COPYRIGHT.txt" "$stage/licenses/GODOT_COPYRIGHT.txt"
	zip="$out/LastOneDry-$version-$platform.zip"
	(cd "$stage" && pack "$zip")
	echo "package: $zip"
done
rm -rf "$out/stage"
