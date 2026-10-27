#!/usr/bin/env bash
#
# Audits GDScript files: parse/type checks, plus repository architecture seams.
#
# `godot --check-only -s <file>` runs the full GDScript analyser — it catches
# type mismatches and unknown identifiers, not just syntax — but always exits 0,
# so this wrapper scans its output for diagnostics and sets the status itself.
#
# Usage:  tools/check_scripts.sh [file.gd ...]
#
# With no arguments it checks every project script (the `check` target in the
# Makefile); with arguments, just those files — project-relative paths — which
# is what the post-edit hook (tools/check_gd_hook.sh) uses.
#
# Much faster than `make test` for "does what I just wrote compile?": it skips
# booting the scene tree and GUT.

set -uo pipefail

# Sourced before the cd: $0 may be a relative path, and it is the caller's
# working directory that makes it resolve.
source "$(dirname "$0")/lib/require_godot.sh" || exit 1

# Every path below (project.godot, .godot/*, the res://-relative scripts
# themselves) is repo-relative — run from anywhere else and the sweep
# silently checks nothing. cd to the repo root derived from $0, not
# CLAUDE_PROJECT_DIR (that's a hook-only variable and this script isn't one).
cd "$(dirname "$0")/.." || exit 1

require_godot check

# Every project script, in a stable order, NUL-separated so a path with a
# space or newline in it survives every pipeline below. .claude/worktrees
# holds whole nested checkouts of this same repo; without excluding it every
# project file gets checked twice, once at a path Godot cannot resolve res://
# imports for.
project_scripts() {
	find . -name '*.gd' \
		-not -path './.godot/*' \
		-not -path './addons/*' \
		-not -path './bin/*' \
		-not -path './.claude/*' \
		-print0 |
		sort -z
}

# A `class_name` is a global identifier only because
# .godot/global_script_class_cache.cfg says so, and only an `--import` pass
# writes that file. A cache that predates a class — a fresh worktree, a deleted
# .godot, a branch switch — makes every file typing against it fail with
# "Identifier ... not declared in the current scope", which reads exactly like
# broken code. So the names are compared before a single file is parsed, and
# `check` stays the read-only audit it claims to be — it names the command that
# fixes this rather than importing behind the caller's back.
CLASS_CACHE=".godot/global_script_class_cache.cfg"

declared_classes="$(project_scripts | xargs -0 grep -hE '^class_name [A-Za-z_]' | awk '{print $2}' | sort -u)"
if [[ -f "$CLASS_CACHE" ]]; then
	cached_classes="$(sed -n 's/^"class": &"\([^"]*\)".*/\1/p' "$CLASS_CACHE" | sort -u)"
else
	cached_classes=""
fi
uncached="$(comm -23 <(printf '%s\n' "$declared_classes") <(printf '%s\n' "$cached_classes"))"
if [[ -n "$uncached" ]]; then
	missing="$(printf '%s\n' "$uncached" | wc -l | tr -d ' ')"
	first="$(printf '%s\n' "$uncached" | head -1)"
	echo "check: stale class cache — $missing class_name(s) the engine has not registered, e.g. $first" >&2
	echo "check: run 'make import' ($GODOT --headless --path . --import) and try again" >&2
	exit 1
fi

# Autoload singletons are global identifiers at runtime, but --check-only never
# instantiates them, so every use reads as "Identifier not found". Build an
# ignore pattern from the names project.godot actually registers — a typo'd
# singleton name still fails, because it won't be in this list.
autoloads="$(
	awk '/^\[autoload\]/ {inside = 1; next}
	     /^\[/ {inside = 0}
	     inside && /=/ {split($0, kv, "="); print kv[1]}' project.godot |
		paste -sd '|' -
)"
if [[ -n "$autoloads" ]]; then
	ignore="Identifier not found: ($autoloads)\$"
else
	ignore='a^' # matches nothing
fi

# A script that types against a class whose script uses an autoload inherits
# the problem one step removed: the dependency fails to compile for the reason
# above, and this file is then reported with "Failed to compile depended
# scripts", which names no identifier to match on.
#
# That cascade is only ignorable when the underlying autoload error is what
# caused it — and Godot prints both in the same output, so we can tell. A
# dependency that fails for a real reason prints that reason here too, and it
# survives the filter and fails the run.
cascade='Compile Error: Failed to compile depended scripts'

failed=0
checked=0

# Where a file's diagnostics are parked. Percent-encoded, so the key is
# one-to-one with the path: a file with a '%' in its name cannot land on
# another file's report.
report_path() {
	local key="${1//%/%25}"
	printf '%s' "$REPORTS/${key//\//%2F}"
}

# One engine boot per file, sharing nothing, so the files are checked in
# parallel. xargs starts a fresh shell per batch, which is why the worker is an
# exported function over an exported environment rather than an inline body.
check_one() {
	local file="$1"
	local raw output
	# Strip the leading './' so reported paths line up with res:// paths.
	raw="$("$GODOT" --headless --path . --check-only -s "${file#./}" 2>&1)"
	output="$(grep -vE "$ignore" <<<"$raw")"
	if grep -qE "$ignore" <<<"$raw"; then
		output="$(grep -vE "$cascade" <<<"$output")"
	fi
	if grep -qE 'SCRIPT ERROR|Parse Error' <<<"$output"; then
		grep -E 'SCRIPT ERROR|Parse Error|^ +at:' <<<"$output" >"$(report_path "$file")"
		return 1
	fi
	return 0
}

# A batch of files, checked one engine after another while the batch holds one of the
# machine's test slots (tools/test_slot.sh): a make check booted an engine per core at
# once here — 20 of about 150 MB each, beside every other session's gate — until
# 2026-10-27. A file that fails leaves its report; the batch itself always passes.
check_batch() {
	local file
	for file; do
		check_one "$file"
	done
	return 0
}
export -f check_one check_batch report_path
export GODOT ignore cascade

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
REPORTS="$WORK/reports"
export REPORTS
mkdir -p "$REPORTS"

# bash 3.2 (macOS system bash) has no mapfile, so stream the paths through a
# file instead — read twice, once to check and once to report. NUL-delimited,
# matching project_scripts, so a path with a space survives both passes.
queue="$WORK/queue"
if (($#)); then
	printf '%s\0' "$@" >"$queue"
else
	project_scripts >"$queue"
fi

# CHECK_JOBS batches side by side, as many as test_slot.sh gives slots by default; one
# that waits for a slot or for memory says so once for the whole run. A batch that
# could not run at all is a failure: its files went unchecked.
if [[ -n "${TEST_SLOTS-}" ]]; then
	workers="$TEST_SLOTS"
else
	cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"
	workers=$((${cores:-2} / 2))
	((workers >= 1)) || workers=1
fi
export TEST_SLOT_NAME=check TEST_SLOT_NOTICE_ONCE="$WORK/slot-notice"
if ! xargs -0 -P "${CHECK_JOBS:-$workers}" -n 16 \
	tools/test_slot.sh bash -c 'check_batch "$@"' check <"$queue"; then
	echo "check: a batch of files could not take a test slot and went unchecked" >&2
	exit 1
fi

# A count kept inside a worker would die with the worker's own process, so
# the failures are read back off disk — in queue order, so a parallel run says
# exactly what a serial one said and two failures never interleave.
while IFS= read -r -d '' file; do
	checked=$((checked + 1))
	report="$(report_path "$file")"
	[[ -f "$report" ]] || continue
	cat "$report"
	failed=$((failed + 1))
done <"$queue"

# Repository invariants. Kept in the full-project audit rather than a subset
# check: each is cross-file drift, so a run over the files somebody just edited
# is exactly the run that cannot see it.
if (($# == 0)); then
	# The simulation layers, as far as they exist yet: grep on a missing
	# directory would print an error and still pass, so only real ones are read.
	# net/ — the host, the client and the wire (SH11) — is held to the same rules,
	# but may read Time: it times what it does, and SH12's server keeps time.
	sim_dirs=()
	clock_free_dirs=()
	for dir in core ai net; do
		[[ -d "$dir" ]] || continue
		sim_dirs+=("$dir")
		[[ "$dir" == net ]] || clock_free_dirs+=("$dir")
	done

	if ((${#sim_dirs[@]})); then
		# The simulation/presentation split: nothing under core/, ai/ or net/ may reach
		# for a Node, a scene or the tree. The pattern matches only spellings that
		# can mean nothing else — the bare word "Node" is prose in comments, and a
		# lint that cries wolf gets switched off.
		layering="$(grep -rnE 'get_node\(|get_tree\(|\bSceneTree\b|\.tscn|res://scenes/|extends Node' "${sim_dirs[@]}" --include='*.gd' || true)"
		if [[ -n "$layering" ]]; then
			echo "check: core/, ai/ and net/ are Node-free — the sim may not reach into the scene tree" >&2
			printf '%s\n' "$layering" >&2
			failed=$((failed + 1))
		fi

		# Determinism: luck is a seeded stream threaded through the sim, so a
		# global roll is a match that cannot be replayed. Excluding a leading dot
		# is what lets `rng.randf(...)` — the seeded stream, the correct call —
		# through.
		global_rng="$(grep -rnE '(^|[^.A-Za-z_])(randf|randf_range|randi|randi_range|randomize)\(' "${sim_dirs[@]}" --include='*.gd' || true)"
		if [[ -n "$global_rng" ]]; then
			echo "check: core/, ai/ and net/ are RNG-free — roll a seeded rng, never the global one" >&2
			printf '%s\n' "$global_rng" >&2
			failed=$((failed + 1))
		fi

		# The tick is the only clock, and a frame the only input (D1, D2): the
		# engine's clocks and devices are out of reach of the sim and the bots —
		# and of net/, but for Time. The word boundary is what lets InputFrame and
		# BotInputSource through.
		engine="$(
			{
				grep -rnE '\b(OS|Engine|Input|DisplayServer)\.' "${sim_dirs[@]}" --include='*.gd'
				((${#clock_free_dirs[@]})) && grep -rnE '\bTime\.' "${clock_free_dirs[@]}" --include='*.gd'
			} || true
		)"
		if [[ -n "$engine" ]]; then
			echo "check: core/ and ai/ are clock- and device-free, net/ device-free — count ticks, read InputFrames" >&2
			printf '%s\n' "$engine" >&2
			failed=$((failed + 1))
		fi

		# Sound is presentation (D1, D12): cues are played under scenes/ from events
		# and phases, so the sim and the bots never reach the audio server or hold a
		# stream. The prefix catches every AudioStream* class and its players.
		audio="$(grep -rnE '\bAudio(Server|Stream)' "${sim_dirs[@]}" --include='*.gd' || true)"
		if [[ -n "$audio" ]]; then
			echo "check: core/, ai/ and net/ are silent — sound is played under scenes/ from events" >&2
			printf '%s\n' "$audio" >&2
			failed=$((failed + 1))
		fi
	fi

	# A PR's before/after images ride on its branch, never main: committed under
	# docs/pr/<branch>/, linked by that commit's SHA, and removed in the next commit
	# (.claude/agents/implementer.md). The PR's head ref keeps the commit, so the links
	# outlive the merge. Kept on main, they had grown to 149 MB by October 2026 — most
	# of the repository and of every worktree. Only what git tracks counts: a capture
	# waiting in a worktree is no one else's business.
	evidence="$(git ls-files -- docs/pr 2>/dev/null | grep -vx 'docs/pr/\.gdignore' || true)"
	if [[ -n "$evidence" ]]; then
		echo "check: docs/pr/ is not for main — link a PR's images by the commit that added them, then git rm them" >&2
		printf '%s\n' "$evidence" | head -5 >&2
		failed=$((failed + 1))
	fi

	# A script make and CI run as a command is executable as git stores it, whatever
	# this checkout's filesystem says: on Windows git keeps no mode of its own
	# (core.filemode is off), so a new tools/*.sh commits as 100644 and CI's Linux
	# answers "Permission denied" (#287, 2026-10-24). tools/lib/ holds the sourced
	# ones, which need no bit.
	unrunnable="$(git ls-files -s -- '*.sh' 2>/dev/null |
		awk '$1 != "100755" && $4 !~ /^tools\/lib\// { print $4 }' || true)"
	if [[ -n "$unrunnable" ]]; then
		echo "check: these scripts are not executable in git — git update-index --chmod=+x them" >&2
		printf '%s\n' "$unrunnable" >&2
		failed=$((failed + 1))
	fi
fi

if ((failed > 0)); then
	echo "check: $failed failure(s) across $checked file(s)" >&2
	exit 1
fi

echo "check: $checked files OK"
