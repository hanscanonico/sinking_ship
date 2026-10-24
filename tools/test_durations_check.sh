#!/usr/bin/env bash
#
# `make guard-check`, its sixth part: tools/test_durations.py reads a CI verify
# log as make durations does. Against tests/fixtures/ci/verify_run.log, cut from
# run 38882193885's: two jobs; scripts that pass, one under a second; scripts whose
# only test is pending, so GUT prints no passed line for them; and each job's
# "= Run Summary", which reprints the pending scripts' paths (and one, the
# Britannic's, the sample never ran) — a reprint is no run and adds no line.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SAMPLE=tests/fixtures/ci/verify_run.log
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "test-durations-check: $1" >&2
	fails=1
}

expected="tests/unit/core/test_battle_royale_digests.gd	48
tests/unit/core/test_funnel_strike.gd	0
tests/unit/core/test_stamina.gd	1
tests/unit/core/test_titanic_olympic.gd	97
tests/unit/match/test_brawl_marks.gd	0"

# A log file, the run named: every script timed once, sorted, nothing reprinted.
tools/test_durations.py --log "$SAMPLE" --run 38882193885 --out "$WORK/file.tsv" 2>/dev/null ||
	fail "reading $SAMPLE failed"
got="$(grep -v '^#' "$WORK/file.tsv")"
[[ "$got" == "$expected" ]] || fail "the sample read as:
$got"
grep -q 'test_titanic_britannic' "$WORK/file.tsv" && fail "a path reprinted in the Run Summary was read as a run"
grep -q '^# .*verify run 38882193885, 2026-10-16' "$WORK/file.tsv" || fail "the header does not name the run and its date"
grep -q 'make durations RUN=38882193885' "$WORK/file.tsv" || fail "the header does not say how to write the file again"

# The same log on stdin, to stdout, writes the same file.
tools/test_durations.py --log - --run 38882193885 --out - <"$SAMPLE" >"$WORK/stdin.tsv" ||
	fail "reading the sample on stdin failed"
cmp -s "$WORK/file.tsv" "$WORK/stdin.tsv" || fail "the sample on stdin read otherwise than from its file"

# The sample with its colour escapes written out as `^[`, as gh prints a log by
# October 2026, reads the same: read as text, the escape hid every passed line and
# the summary banner, and each job's last script dropped out (run 40058239619 lost
# test_must_sink.gd, its shard's only script).
LC_ALL=C sed $'s/\x1b/^[/g' "$SAMPLE" >"$WORK/caret.log"
grep -q '\^\[\[' "$WORK/caret.log" || fail "the written-out copy of the sample holds no ^[ escape"
tools/test_durations.py --log "$WORK/caret.log" --run 38882193885 --out "$WORK/caret.tsv" 2>/dev/null ||
	fail "reading the sample with written-out escapes failed"
cmp -s "$WORK/file.tsv" "$WORK/caret.tsv" || fail "the sample with written-out escapes read as:
$(grep -v '^#' "$WORK/caret.tsv")"

# One job's log bare, with no job and step columns, reads the same for that job.
grep '^test 5/8' "$SAMPLE" | cut -f3- >"$WORK/bare.log"
got="$(tools/test_durations.py --log "$WORK/bare.log" --out - | grep -v '^#')"
[[ "$got" == "$(grep -E 'stamina|olympic|brawl_marks' <<<"$expected")" ]] || fail "a bare job log read as:
$got"

# The digests' run cut out, so the job meets that path only in its Run Summary,
# reprinted just ahead of the Britannic's: read past the banner, the reprint
# would open a script the next reprint closes at 0 s.
awk '/test_battle_royale_digests\.gd$/ && !cut { skip = 1; cut = 1 } /test_funnel_strike\.gd$/ { skip = 0 } !skip' \
	"$SAMPLE" >"$WORK/reprint_only.log"
got="$(tools/test_durations.py --log "$WORK/reprint_only.log" --out - | grep -v '^#')"
[[ "$got" == "$(grep -v digests <<<"$expected")" ]] || fail "a path only reprinted in the Run Summary read as:
$got"

# A log that times no script, and a run id that is not one, are refused.
printf 'nothing here\n' | tools/test_durations.py --log - --out "$WORK/none.tsv" 2>/dev/null &&
	fail "a log timing no script passed"
[[ -e "$WORK/none.tsv" ]] && fail "a log timing no script wrote a file"
tools/test_durations.py --run 'not-a-run' --out - >/dev/null 2>&1 && fail "a run id that is not a number passed"

((fails == 0)) && echo "test-durations-check: ok"
exit "$fails"
