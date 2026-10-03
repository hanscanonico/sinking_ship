# The engine: $GODOT when set (CI points it at the Linux build it fetches),
# else a vendored bin/Godot.app when the checkout has one, else `godot` on PATH.
# tools/lib/require_godot.sh resolves it the same way for the gate scripts.
GODOT ?= $(if $(wildcard bin/Godot.app/Contents/MacOS/Godot),bin/Godot.app/Contents/MacOS/Godot,godot)

# The two things a gate can be missing. The gate scripts say the first for
# themselves, through tools/lib/require_godot.sh; a target that runs the tool
# directly says it here, in the same two lines, so a fresh machine reads the
# setup line instead of a bare "No such file or directory".
require-godot = @test -x "$(GODOT)" || command -v "$(GODOT)" >/dev/null || { \
	echo "$@: Godot binary not found at $(GODOT)" >&2; \
	echo "$@: install Godot 4.7 so \`godot\` is on PATH, or pass GODOT=<path>" >&2; \
	exit 1; }
require-gdtoolkit = @command -v $(1) >/dev/null || { \
	echo "$@: $(1) not found — pipx install \"gdtoolkit==4.*\"" >&2; \
	exit 1; }

# Registers every class_name and imports assets. A fresh checkout or worktree
# needs it once before anything else: until it runs, every script typing
# against a project class fails `check` as if the code were broken.
import:
	$(call require-godot)
	$(GODOT) --headless --path . --import

# One match's knobs, handed to the scene and tools/run_match.gd as user args:
#   make run [SEED=] [SEATS=] [ARGS=]  the game, windowed, from the menu they fill in;
#       ARGS passes more user args, e.g. ARGS=--observer for the observer camera
#   make match SEED=1701 [SEATS=] [SECONDS=]   bots only, headless, as a transcript
#   make capture SEED=1701 AT=60 [SEATS=] [EYE=] [CAPTURE=path.png]
#       a windowed bots-only match saved as a PNG at AT seconds of match time
#       (or its end), then quit: from the observer camera, or through seat EYE's
#       eyes. Not part of verify: it needs a display.
SEED ?=
SEATS ?=
SECONDS ?=
AT ?=
EYE ?=
ARGS ?=
CAPTURE ?= $(CURDIR)/captures/match_$(SEED)_$(AT)$(if $(EYE),_eye$(EYE)).png
match-args = $(if $(SEED),--seed=$(SEED)) $(if $(SEATS),--seats=$(SEATS))

run:
	$(call require-godot)
	$(GODOT) --path . -- $(match-args) $(ARGS)

# The engine helper autoload prints one line of its own on every boot; it is
# filtered so stdout is the transcript alone.
match:
	$(call require-godot)
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/run_match.gd \
		-- $(match-args) $(if $(SECONDS),--seconds=$(SECONDS)) | grep -v '^\[godot_ai'

# --fixed-fps steps one tick per drawn frame, so the capture lands on its exact
# tick however fast the machine draws.
capture:
	$(call require-godot)
	@test -n "$(AT)" || { echo "capture: AT=<seconds of match time> is required" >&2; exit 1; }
	@mkdir -p "$(dir $(CAPTURE))"
	$(GODOT) --path . --fixed-fps 30 -- $(match-args) --autoplay \
		--capture="$(CAPTURE)" --capture-at=$(AT) $(if $(EYE),--capture-eye=$(EYE))

# The art against the data (D6) and the snapshots (D5): drawn platform tops,
# every seat's model on its feet, no live sim object named under scenes/art.
# Rules live in tools/art_lint.gd. Two frames per tick, so the view interpolates.
art-lint:
	$(call require-godot)
	@set -o pipefail; $(GODOT) --headless --no-header --path . --fixed-fps 60 \
		-s res://tools/art_lint.gd | grep -v -e '^\[godot_ai' -e '^match seed'

# The GUT suite, headless. One script:
#   make test TEST=tests/unit/core/test_ticks.gd
# tools/run_tests.sh hands any other GUT flag through (-gunit_test_name=...).
TEST ?=
test:
	$(call require-godot)
	GODOT="$(GODOT)" tools/run_tests.sh $(if $(TEST),-gselect=$(notdir $(TEST)))

# The merge gate, in one command. Order is cheapest-feedback-first: parsing
# fails fastest, style next, the suite last.
#
# Needs Godot 4.7+ and gdtoolkit 4.x for the lint and format steps:
#   pipx install "gdtoolkit==4.*"
verify: check lint format-check test

# Every .gd file that is actually ours: skips the engine cache, vendored addons,
# the engine binary, and .claude/worktrees, which holds whole nested checkouts of
# this same repo and would otherwise be linted as if it were project source.
#
# Deferred, so only the three gdtoolkit targets below pay for the walk.
SOURCES = $(shell find . -name '*.gd' \
	-not -path './.godot/*' -not -path './addons/*' -not -path './bin/*' \
	-not -path './.claude/*')

# Parse/type check plus lightweight architecture invariants without booting the
# scene tree. Rules live in tools/check_scripts.sh.
check:
	GODOT="$(GODOT)" tools/check_scripts.sh

# Style and smells. Rule overrides live in gdlintrc.
lint:
	$(call require-gdtoolkit,gdlint)
	gdlint $(SOURCES)

# Reformat in place; `make format-check` only reports.
format:
	$(call require-gdtoolkit,gdformat)
	gdformat $(SOURCES)

format-check:
	$(call require-gdtoolkit,gdformat)
	gdformat --check $(SOURCES)

# `verify`'s gates are a sequence rather than a set: they share one .godot/
# across every engine boot, and their order is the cheapest feedback first, so
# racing them under `make -j` would trade a one-second parse failure for the
# whole suite.
.NOTPARALLEL:

.PHONY: import run match capture art-lint test verify check lint format format-check
