#!/usr/bin/env bash
#
# `make guard-check`, its fifth part: `make test` with a list of scripts runs
# exactly those, dealt over JOBS shards or one SHARD, holds GUT's "Scripts" count
# to the list, passes an empty list saying so, and refuses a list naming a script
# that is not one; with no list, the whole suite, a shard and -gselect run as they
# did. Against a stand-in engine that records the scripts it was handed and
# counts them in GUT's summary line, less any it is told cannot load — no Godot
# runs, so the check takes seconds.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export TEST_SLOT_LOCK="$WORK/slot" TEST_SLOTS=4
unset TEST_SLOT_NOTICE_FD TEST_SLOT_NAME TESTS TEST SHARD JOBS

# The stand-in: res:// paths of -gtest, or every script under tests/unit when the
# config's directory scan would run (no -gconfig=), one line each to $RECORD and
# its arguments to $RECORD.args; STANDIN_UNLOADABLE, a script's basename, drops
# that one from the count as GUT drops a script it cannot load.
STANDIN="$WORK/godot"
cat >"$STANDIN" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$RECORD.args"
scripts="" scan=1
for arg; do
	case "$arg" in
	-gtest=*) scripts="${arg#-gtest=}" ;;
	-gconfig=) scan=0 ;;
	-gselect=*) scan=0 ;;
	esac
done
if ((scan)); then
	scripts="$(find tests/unit -name 'test_*.gd' | sed 's|^|res://|' | paste -sd, -)"
fi
ran=0
for script in ${scripts//,/ }; do
	echo "$script" >>"$RECORD"
	[[ "$(basename "$script")" == "${STANDIN_UNLOADABLE:-}" ]] || ran=$((ran + 1))
done
printf 'Totals\n------\nScripts  %d\n' "$ran"
EOF
chmod +x "$STANDIN"

fails=0
fail() {
	echo "run-tests-check: $1" >&2
	fails=1
}

A=tests/unit/ai/test_bot_brain.gd
B=tests/unit/core/test_ticks.gd
C=tests/unit/core/test_air.gd
D=tests/unit/ai/test_bot_cargo.gd

# Runs `make test` with the stand-in and arguments $2…, into a fresh record named
# $1; its exit status is make's.
run() {
	local name="$1"
	shift
	export RECORD="$WORK/$name"
	: >"$RECORD"
	make -s test GODOT="$STANDIN" "$@" >"$WORK/$name.out" 2>&1
}

# The scripts the stand-in was handed under record $1, sorted, as res:// paths.
ran() {
	sort "$WORK/$1"
}

# The scripts $@ as res:// paths, sorted, as ran() writes them.
paths() {
	printf 'res://%s\n' "$@" | sort
}

# How many engines the stand-in was started as under record $1.
engines() {
	if [[ -e "$WORK/$1.args" ]]; then
		wc -l <"$WORK/$1.args" | tr -d ' '
	else
		echo 0
	fi
}

# A list over two shards: exactly the listed scripts, each once, in two engines.
run jobs TESTS="$A $B $C" JOBS=2 || fail "a list of three over JOBS=2 failed: $(cat "$WORK/jobs.out")"
[[ "$(ran jobs)" == "$(paths "$A" "$B" "$C")" ]] || fail "a list over JOBS=2 ran $(ran jobs | paste -sd' ' -)"
(($(engines jobs) == 2)) || fail "a list over JOBS=2 started $(engines jobs) engines"

# JOBS=1: one engine runs the whole list.
run one TESTS="$A $B $C" JOBS=1 || fail "a list in one engine failed: $(cat "$WORK/one.out")"
[[ "$(ran one)" == "$(paths "$A" "$B" "$C")" ]] || fail "a list in one engine ran $(ran one | paste -sd' ' -)"
(($(engines one) == 1)) || fail "a list in one engine started $(engines one) engines"

# res:// spellings and repeats name the same script once.
run spelled TESTS="res://$A $A $B" JOBS=1 || fail "a list with res:// and a repeat failed: $(cat "$WORK/spelled.out")"
[[ "$(ran spelled)" == "$(paths "$A" "$B")" ]] || fail "a list with res:// and a repeat ran $(ran spelled | paste -sd' ' -)"

# More shards than scripts: the empty ones pass.
run wide TESTS="$A $B" JOBS=4 || fail "a list of two over JOBS=4 failed: $(cat "$WORK/wide.out")"
[[ "$(ran wide)" == "$(paths "$A" "$B")" ]] || fail "a list of two over JOBS=4 ran $(ran wide | paste -sd' ' -)"

# One SHARD of a list: the two shards of two together run the list once.
run shard1 TESTS="$A $B $C $D" SHARD=1/2 || fail "shard 1/2 of a list failed: $(cat "$WORK/shard1.out")"
run shard2 TESTS="$A $B $C $D" SHARD=2/2 || fail "shard 2/2 of a list failed: $(cat "$WORK/shard2.out")"
[[ "$(sort "$WORK/shard1" "$WORK/shard2")" == "$(paths "$A" "$B" "$C" "$D")" ]] ||
	fail "the shards of a list ran $(sort "$WORK/shard1" "$WORK/shard2" | paste -sd' ' -)"
[[ -s "$WORK/shard1" && -s "$WORK/shard2" ]] || fail "one shard of a list of four ran nothing"

# Anything after the split is refused, not dropped.
RECORD="$WORK/trailing" GODOT="$STANDIN" tools/run_tests.sh --list - --shard 1/1 -gexit <<<"$A" >/dev/null 2>&1 &&
	fail "a list with an argument after its split passed"
(($(engines trailing) == 0)) || fail "a list with an argument after its split started an engine"

# A listed script that cannot load fails the run.
STANDIN_UNLOADABLE="$(basename "$B")" run unloadable TESTS="$A $B $C" JOBS=2 &&
	fail "a list with a script that cannot load passed"
STANDIN_UNLOADABLE="$(basename "$B")" run unloadable1 TESTS="$A $B" JOBS=1 &&
	fail "a list with a script that cannot load passed in one engine"

# A script that is not there, or is not a test script, fails before any engine.
run missing TESTS="$A tests/unit/core/test_no_such_script.gd" JOBS=1 && fail "a list naming a missing script passed"
(($(engines missing) == 0)) || fail "a list naming a missing script started an engine"
run stranger TESTS="$A tests/unit/sim_fixtures.gd" JOBS=1 && fail "a list naming a script that is not a test passed"
run outside TESTS="tools/run_match.gd" JOBS=1 && fail "a list naming a script outside tests/unit passed"

# An empty list runs nothing, passes, and says so.
for jobs in 1 4; do
	run "empty$jobs" TESTS= JOBS="$jobs" || fail "an empty list with JOBS=$jobs failed: $(cat "$WORK/empty$jobs.out")"
	(($(engines "empty$jobs") == 0)) || fail "an empty list with JOBS=$jobs started an engine"
	grep -q 'no test scripts' "$WORK/empty$jobs.out" || fail "an empty list with JOBS=$jobs did not say so"
done
run emptyshard TESTS= SHARD=1/8 || fail "an empty list with SHARD=1/8 failed"

# No list: the whole suite over JOBS shards, one engine each, every script once.
all="$(find tests/unit -name 'test_*.gd' | sed 's|^|res://|' | sort)"
run suite JOBS=3 || fail "the whole suite over JOBS=3 failed: $(cat "$WORK/suite.out")"
[[ "$(ran suite)" == "$all" ]] || fail "the whole suite over JOBS=3 did not run every script once"
(($(engines suite) == 3)) || fail "the whole suite over JOBS=3 started $(engines suite) engines"

# JOBS=1: the config's own scan, held to every script under tests/unit.
run whole JOBS=1 || fail "the whole suite in one engine failed: $(cat "$WORK/whole.out")"
grep -q -- '-gtest=' "$WORK/whole.args" && fail "the whole suite in one engine was handed a list"
STANDIN_UNLOADABLE="$(basename "$A")" run wholeshort JOBS=1 && fail "the whole suite passed a script that cannot load"

# A SHARD of the suite, and a shard with nothing in it still failing as it did.
run suiteshard SHARD=1/2 || fail "shard 1/2 of the suite failed: $(cat "$WORK/suiteshard.out")"
[[ -n "$(comm -13 <(echo "$all") <(ran suiteshard))" ]] && fail "shard 1/2 of the suite ran a script outside it"
run nothing SHARD=1000/1000 && fail "an empty shard of the suite passed"

# TESTS in the environment, empty or not, is no list: the whole suite runs.
TESTS= run envempty JOBS=1 || fail "the whole suite with TESTS= in the environment failed"
grep -q -- '-gtest=' "$WORK/envempty.args" && fail "TESTS= in the environment made a list"
TESTS="$A" run envlist JOBS=1 || fail "the whole suite with TESTS in the environment failed"
grep -q -- '-gtest=' "$WORK/envlist.args" && fail "TESTS in the environment made a list"

# TEST= narrows by -gselect, handed to GUT verbatim, with no count.
run select TEST="$B" || fail "TEST= failed: $(cat "$WORK/select.out")"
grep -q -- "-gselect=$(basename "$B")\$" "$WORK/select.args" || fail "TEST= handed GUT $(cat "$WORK/select.args")"

((fails == 0)) && echo "run-tests-check: ok"
exit "$fails"
