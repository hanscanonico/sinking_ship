#!/usr/bin/env bash
#
# `make ship-gen-check`: every generated ship file held to its generator, the
# generators run side by side — one after another they took CI's runner five
# minutes, three of the eleven the Titanic's at a minute and a half apiece.
#
# Usage:  tools/ship_gen_check.sh SHIP:FILE[:FLAG] …
#
# Each SHIP:FILE[:FLAG] runs tools/gen_SHIP.py [FLAG] into a scratch file and
# compares that with FILE byte for byte. Every one is run, as many at once as the
# machine has cores (NPROC), and each that differs — or whose generator failed —
# is named with the command that rewrites it.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if (($# == 0)); then
	echo "ship-gen-check: name what to check, e.g. steamer:data/ships/steamer.tres" >&2
	exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export WORK

# xargs starts a fresh shell per generator, which is why the worker is an exported
# function over an exported environment rather than an inline body.
check_one() {
	local entry="$1" ship rest file flag="" out
	ship="${entry%%:*}"
	rest="${entry#*:}"
	file="${rest%%:*}"
	[[ "$rest" == *:* ]] && flag="${rest#*:}"
	out="$WORK/$(printf '%s' "$entry" | tr -c 'A-Za-z0-9_.-' '_').tres"
	# $flag unquoted: none is no argument at all.
	# shellcheck disable=SC2086
	if python3 "tools/gen_$ship.py" "$out" $flag >/dev/null && cmp -s "$out" "$file"; then
		return 0
	fi
	echo "ship-gen-check: $file differs from tools/gen_$ship.py${flag:+ $flag} — run make ship SHIP=$ship" >&2
	return 1
}
export -f check_one

NPROC="${NPROC:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

# Through a file, as tools/gdtoolkit_each.sh feeds its workers: the same on every
# platform. xargs exits 123 when any one generator's check fails.
printf '%s\0' "$@" >"$WORK/queue"
xargs -0 -P "$NPROC" -n 1 bash -c 'check_one "$1"' ship-gen-check <"$WORK/queue"
