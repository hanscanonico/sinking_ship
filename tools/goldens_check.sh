#!/usr/bin/env bash
#
# `make guard-check`: tools/goldens.py reads the goldens a CI run printed as make
# goldens does. Against tests/fixtures/ci/goldens_run.log, cut from run
# 40064420995's: the battle royale's test printing its digests for linux-x86_64,
# which had no golden yet, between Goldens.show's markers, then going pending.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SAMPLE=tests/fixtures/ci/goldens_run.log
GOLDEN=tests/golden/battle_royale.linux-x86_64.txt
FILE=battle_royale.linux-x86_64.txt
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "goldens-check: $1" >&2
	fails=1
}

# Reads LOG into a fresh folder; its status.
read_log() {
	rm -rf "$WORK/out"
	tools/goldens.py --log "$1" --out "$WORK/out" >/dev/null 2>&1
}

# The run's block is the golden committed from it, byte for byte.
read_log "$SAMPLE" || fail "reading $SAMPLE failed"
cmp -s "$WORK/out/$FILE" "$GOLDEN" || fail "the sample's block did not decode to $GOLDEN"

# The same lines bare, with no job, step or timestamp, as a local run prints them.
cut -f3- "$SAMPLE" | sed -E 's/^[0-9T:.-]+Z ?//' >"$WORK/bare.log"
read_log "$WORK/bare.log" || fail "reading the bare lines failed"
cmp -s "$WORK/out/$FILE" "$GOLDEN" || fail "the bare lines did not decode to $GOLDEN"

# The block printed twice, alike, is one golden; another run printing the same file
# with other text, its own block sound, is a determinism bug.
cat "$SAMPLE" "$SAMPLE" >"$WORK/twice.log"
read_log "$WORK/twice.log" || fail "the block printed twice alike was refused"
sha256() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }
text=$'1 120 0000\n'
printf 'golden %s begin %d %s\n%s\ngolden %s end\n' "$FILE" "${#text}" \
	"$(printf '%s' "$text" | sha256)" "$(printf '%s' "$text" | base64 | tr -d '\n')" "$FILE" >"$WORK/other.log"
read_log "$WORK/other.log" || fail "a sound block of other text was refused"
cat "$SAMPLE" "$WORK/other.log" >"$WORK/disagree.log"
read_log "$WORK/disagree.log" && fail "two runs printing the golden differently passed"

# A character changed fails the size and SHA-256 the marker gives; a block that never
# ends fails; and nothing is written for either.
first=$(grep -m1 -n 'begin 211' "$SAMPLE" | cut -d: -f1)
sed "$((first + 1))s/MSAx/MiAx/" "$SAMPLE" >"$WORK/corrupt.log"
read_log "$WORK/corrupt.log" && fail "a block whose text no longer matches its SHA-256 passed"
[[ -e "$WORK/out/$FILE" ]] && fail "a block that failed its SHA-256 was written"
grep -v ' end$' "$SAMPLE" >"$WORK/unended.log"
read_log "$WORK/unended.log" && fail "a block that never ends passed"
[[ -e "$WORK/out/$FILE" ]] && fail "a block that never ends was written"

# A marker naming a path out of the folder is no golden.
sed "s#golden $FILE#golden ../$FILE#" "$SAMPLE" >"$WORK/escape.log"
read_log "$WORK/escape.log" || fail "a log with only a path-naming marker was refused"
[[ -e "$WORK/$FILE" || -e "$WORK/out/$FILE" ]] && fail "a marker naming a path wrote a file"

# A log with no block means every golden matched: nothing written, and no failure.
grep -v 'golden ' "$SAMPLE" >"$WORK/none.log"
read_log "$WORK/none.log" || fail "a log printing no golden failed"
[[ -e "$WORK/out" ]] && fail "a log printing no golden wrote something"

((fails == 0)) && echo "goldens-check: ok"
exit "$fails"
