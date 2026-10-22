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
#   make run [SEED=] [SEATS=] [SHIP=] [SCENARIO=] [ARGS=]  the game, windowed, from the menu
#       they fill in; SHIP picks a ship of the fleet by name (trawler), the default data's
#       when blank, or a test-only one the menu never lists (steamer_weak, SH33); SCENARIO one of a ship's scenarios by name (steamer_coast: her coast's
#       shallow water, SH32), played on her; ARGS passes more user args, e.g.
#       ARGS=--observer for the observer camera; SEATS=1 plays alone, no bots, until you
#       go out
#   make match SEED=1701 [SEATS=] [SHIP=] [STOP=15:00] [HIT=]   bots only, headless, as a
#       transcript; STOP is the match time the tool stops at and reports unfinished — a
#       tool's limit, never a rule of the match; HIT=path/to/hit.tres strikes her with
#       that explicit hit, past the must-sink rule (as `make capture HIT=` does), and
#       HIT=NAME with the test fixtures' hit of that name, her own first (SHIP=titanic
#       HIT=fast is tests/fixtures/sinking/hits/titanic_fast.tres)
#   make capture SEED=1701 AT=60 [SEATS=] [SHIP=] [EYE=] [CUT=0] [CELLS=1] [SIDE=port] [HIT=] [FROM= LOOK=] [CAPTURE=] [ARGS=]
#       a windowed bots-only match saved as a PNG at AT seconds of match time
#       (or its end), then quit: from the observer camera, or through seat EYE's
#       eyes; CUT cuts the observer's view of the ship away at and above that
#       height to show the inside; CELLS draws the ship's cells over the observer's
#       view, every one named, each filled to its water's level; HIT=path.tres (or a
#       fixture hit's NAME, as for match) strikes her with that explicit hit (a fast one
#       shows a late stage soon); FROM=x,y,z LOOK=x,y,z stands the eyes on those feet in
#       ship space looking at that ship point, riding with her as she lists — the breach
#       from inside any space, whether or not a seat stands there; SIDE=port
#       watches her from her port side rather than her starboard; ARGS passes more
#       user args, e.g. ARGS=--net-sim=latency:120,jitter:20,loss:5. Not part of
#       verify: it needs a display. WET=S holds the lens wet S seconds after surfacing.
#   make capture SEED=1701 PHYS=1:04:40 [JUMP=1] [EYE=] [CUT=] [CELLS=1] [SIDE=]
#       at that moment of the sinking, in physics time after the hit, in place of AT;
#       JUMP=1 bakes, seeks the timeline there and starts the match JUMP's lead before
#       it, every seat on whatever is dry then — no hours of brawl first (§5b.4)
#   make capture SCREEN=menu|settings|graphics|online|room [CAPTURE=]   the main menu,
#       the settings screen over it — on its Graphics page for graphics —, the Online
#       screen, or a room — its players made up, no server asked — with no match
#       started (no AT)
#   make capture SCREEN=hold [SEED=] [ARGS=--bake-budget=1]   the countdown held for a
#       bake still running (R20), its bar half way; a slow slice budget makes one hold
#   make capture SCREEN=pause AT=60 [EYE=]   the pause menu over the match at AT
#   make capture SCREEN=results [EYE=]   the results once the match ends and their
#       buttons take presses
#   RES=1920x1080 on any of them opens the window at that size
#   make smoke [SEED=1701] [SHIP=] [FAST=1] [MAX=] [DRY=1] [OUT=captures/smoke]   the
#       capture sweep QA reads: plays the match headless once, then takes make capture
#       shots one after another at the water moments of its transcript (seat 0's eyes early,
#       the first and last flooding, a crate afloat, the first seat out, late, mid-sinking,
#       the saloon filling, a seat wading in a cell's water, the sea pouring down a hole in
#       a deck)
#       into OUT/<nn>_<name>.png; MAX bounds the shots, DRY=1 prints the planned capture
#       commands and opens no window. Rules live in tools/smoke.sh. Not part of verify.
SEED ?=
SEATS ?=
SHIP ?=
SCENARIO ?=
SECONDS ?=
STOP ?=
HIT ?=
AT ?=
EYE ?=
FROM ?=
LOOK ?=
CUT ?=
CELLS ?=
SIDE ?=
ARGS ?=
FAST ?=
GOAL ?=
SCREEN ?=
RES ?=
PHYS ?=
JUMP ?=
CAPTURE ?= $(CURDIR)/captures/match_$(SEED)_$(AT)$(if $(PHYS),phys$(subst :,-,$(PHYS)))$(if $(EYE),_eye$(EYE))$(if $(CUT),_cut$(CUT))$(if $(CELLS),_cells)$(if $(SCREEN),_$(SCREEN)).png
match-args = $(if $(SEED),--seed=$(SEED)) $(if $(SEATS),--seats=$(SEATS)) $(if $(SHIP),--ship=$(SHIP)) \
	$(if $(SCENARIO),--scenario=$(SCENARIO)) $(if $(HIT),--hit=$(HIT)) $(if $(FAST),--fast) \
	$(if $(GOAL),--goal=$(GOAL))

# FAST=1 plays her sinking on the match data's fast_clock (the menu's Fast sinking).
# GOAL=survival plays survival (the menu's Survival): everyone stays in as long as she
# lasts. Without GOAL=, the match data's goal (the battle royale's in default.tres). It
# works for match too, and with FAST=1. FAST=1 works for bake too. A SEED= that is not a
# whole number of 0 or more is refused, as the menu refuses it.
run:
	$(call require-godot)
	$(GODOT) --path . -- $(match-args) $(ARGS)

# `make replay FILE=path/to/one.replay` watches a saved replay — one the game wrote
# under user://replays, or any path — in the replay viewer (R4–R6); the game quits with
# the reason when the file cannot be played.
replay:
	$(call require-godot)
	@test -n "$(FILE)" || { echo "replay: FILE=<path to a .replay> is required" >&2; exit 1; }
	$(GODOT) --path . -- --replay="$(FILE)" $(ARGS)

# Every headless tool target, and capture, runs the engine through tools/engine_guard.sh:
# the engine exits 0 after a SCRIPT ERROR or a renderer ERROR, so the guard fails the run
# when either prints one.
#
# The engine helper autoload prints one line of its own on every boot; it is
# filtered so stdout is the transcript alone. FAST=1 and GOAL=survival as for run.
match:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/run_match.gd \
		-- $(match-args) $(if $(SECONDS),--seconds=$(SECONDS)) $(if $(STOP),--stop=$(STOP)) \
		| grep -v '^\[godot_ai'

# --fixed-fps steps one tick per drawn frame, so the capture lands on its exact
# tick however fast the machine draws. A capture is silent: the Dummy driver.
# SCREEN=menu, settings, graphics, online, room or replays starts no match, so it neither
# autoplays nor takes AT; pause, online-pause and online-settings stand over the match
# at AT. One game window at a time on a shared machine: capture and fps take the window
# lock themselves (tools/window_lock.sh), a kernel lock released on any exit, so never
# hand-roll a lock around them; run, a person playing, does not take it. A window the
# system stops drawing — covered, minimised, on another Space, the display asleep —
# fails a capture once no frame has been drawn for a minute (DrawWatch), rather
# than hang holding the lock.
menu-screen = $(filter menu settings graphics online room replays,$(SCREEN))
capture:
	$(call require-godot)
	@test -n "$(AT)$(PHYS)$(filter menu settings graphics online room replays results hold,$(SCREEN))" || \
		{ echo "capture: AT=<seconds of match time> or PHYS=<h:mm:ss of physics> is required" >&2; exit 1; }
	@mkdir -p "$(dir $(CAPTURE))"
	tools/window_lock.sh tools/engine_guard.sh $(GODOT) --path . $(if $(RES),--resolution $(RES)) --audio-driver Dummy --fixed-fps 30 -- \
		$(match-args) $(if $(menu-screen),,--autoplay) --capture="$(CAPTURE)" \
		$(if $(AT),--capture-at=$(AT)) $(if $(PHYS),--phys=$(PHYS)) $(if $(JUMP),--jump) \
		$(if $(EYE),--capture-eye=$(EYE)) \
		$(if $(FROM),--capture-from=$(FROM)) $(if $(LOOK),--capture-look=$(LOOK)) \
		$(if $(CUT),--observer-cut=$(CUT)) $(if $(CELLS),--observer-cells) \
		$(if $(SIDE),--observer-side=$(SIDE)) $(if $(WET),--capture-wet=$(WET)) \
		$(if $(SCREEN),--capture-screen=$(SCREEN)) $(ARGS)

# The sweep runs make capture shot by shot, so each takes the window lock itself; the
# sweep takes none. FAST defaults to 1 there (FAST=0 for the paced clock).
MAX ?=
DRY ?=
OUT ?=
smoke:
	@SEED="$(SEED)" SHIP="$(SHIP)" FAST="$(FAST)" MAX="$(MAX)" DRY="$(DRY)" OUT="$(OUT)" \
		GODOT="$(GODOT)" MAKE="$(MAKE)" tools/smoke.sh

# `make net-bench [SEED=] [SEATS=] [SECONDS=] [NET=latency:120,jitter:20,loss:5]`: one
# match headless, seat 0 played through the client over a loopback lying as NET says
# (NET= for the offline game's honest wire), timed beat by beat: ticks re-run, the
# client's and the host's time, packet sizes (R7). Rules live in tools/net_bench.gd.
NET ?= latency:120,jitter:20,loss:5
net-bench:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/net_bench.gd \
		-- $(match-args) --net-sim=$(NET) $(if $(SECONDS),--seconds=$(SECONDS)) \
		| grep -v '^\[godot_ai'

# `make serve-local [WS_PORT=47923] [SEED=1701] [KILL=1] [EXPORTED=1]`: a --server and two
# headless --autoplay clients in one room over real WebSockets on 127.0.0.1 (SH12); the
# server's log — the match's transcript, tick times, round trips and snapshot bandwidth
# — is printed. KILL=1 kills one client mid-match: its seat goes to a bot and the match
# still finishes. EXPORTED=1 runs the exported builds instead of the editor: the
# dedicated server export for this Mac (the Linux server's very pack) and the macOS
# app as both clients, exporting them first. Rules live in tools/serve_local.sh. Not
# part of verify: it runs a whole match in real time.
WS_PORT ?=
KILL ?=
EXPORTED ?=
serve-local: $(if $(EXPORTED),export-server-mac export-mac)
	$(call require-godot)
	GODOT="$(GODOT)" tools/serve_local.sh $(if $(WS_PORT),--port=$(WS_PORT)) \
		$(if $(SEED),--seed=$(SEED)) $(if $(KILL),--kill) $(if $(EXPORTED),--exported)

# `make online-e2e [WS_PORT=47931] [SEED=1701]`: two people online through the game's own
# screens on 127.0.0.1 (SH12) — a --server and two headless games driven as hands would
# drive them: Play online, a name, Create; the code typed and Join; Start; the match
# played to its results; Back to the room; Leave room. Each player's steps and the
# server's log are printed. Rules live in tools/online_e2e.sh and tools/online_e2e.gd.
# Not part of verify: it runs a whole match in real time.
online-e2e:
	$(call require-godot)
	GODOT="$(GODOT)" tools/online_e2e.sh $(if $(WS_PORT),--port=$(WS_PORT)) \
		$(if $(SEED),--seed=$(SEED))

# Release builds under build/, from export_presets.cfg (SH12):
#   make export-server       the Linux dedicated server the deploy runs: headless, its
#       visuals stripped and its audio left out
#   make export-web          the browser build: single-threaded, so it needs no
#       cross-origin isolation headers
#   make export-mac          the macOS app, ad-hoc signed
#   make export-win          the Windows game, one .exe with its pack embedded
#   make export-linux        the Linux game, one x86_64 binary with its pack embedded
#   make export-server-mac   the dedicated server for this Mac, the same pack as the
#       Linux one: what `make serve-local EXPORTED=1` and serve-web-local run
# They need Godot's export templates for the engine's exact version installed, which
# CI has not: none is part of verify, and each stops first, saying where they belong,
# when they are missing (tools/export_templates.sh). No export ships the godot_ai
# helper autoload (R11): the plugin's export hook strips it from every pack, and every
# preset leaves addons/ out.
define export-preset
	$(call require-godot)
	@tools/export_templates.sh "$(GODOT)"
	@mkdir -p "$(dir $(2))" && touch build/.gdignore
	timeout 1200 $(GODOT) --headless --path . --export-release "$(1)" "$(2)"
endef

export-server:
	$(call export-preset,Linux Server,build/server/sinking_ship_server.x86_64)

export-web:
	$(call export-preset,Web,build/web/index.html)

export-mac:
	$(call export-preset,macOS,build/mac/LastOneDry.app)

export-win:
	$(call export-preset,Windows Desktop,build/win/LastOneDry.exe)

export-linux:
	$(call export-preset,Linux Desktop,build/linux/LastOneDry.x86_64)

export-server-mac:
	$(call export-preset,macOS Server,build/server-mac/SinkingShipServer.app)

# `make serve-web-local [WEB_PORT=47984] [WS_PORT=47985]`: the browser build over HTTP
# and an exported server, both on 127.0.0.1 and left running, with the address to open
# printed; `make serve-web-local-stop` stops both. Rules live in tools/serve_web_local.sh.
WEB_PORT ?=
serve-web-local: export-web export-server-mac
	tools/serve_web_local.sh start $(if $(WEB_PORT),--web-port=$(WEB_PORT)) \
		$(if $(WS_PORT),--ws-port=$(WS_PORT))

serve-web-local-stop:
	tools/serve_web_local.sh stop

# `make sim-bench [SEED=] [SEATS=]`: one bots-only match recorded through the local
# host, its input log replayed through a bare MatchSim, no bots, timed step by step,
# with snapshot() and restore() beside it and the load average (R7). Rules live in
# tools/sim_bench.gd.
sim-bench:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/sim_bench.gd \
		-- $(match-args) | grep -v '^\[godot_ai'

# `make bench [SEATS=64] [SHIP=] [SECONDS=60] [SEED=1]`: MatchSim.step timed with many bodies
# on a huge hull (SH18, R7) — seats played by seeded wanderers, no bots, on the
# Titanic-scale fixture or on SHIP — with the spatial index and without it, taking turns:
# p50 and p99 per step each way, the load average, and both ways' digests, which must
# match. Rules live in tools/bench_sim.gd.
bench:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/bench_sim.gd \
		-- $(if $(SEED),--seed=$(SEED)) $(if $(SEATS),--seats=$(SEATS)) \
		$(if $(SHIP),--ship=$(SHIP)) $(if $(SECONDS),--seconds=$(SECONDS)) \
		| grep -v '^\[godot_ai'

# `make fps [SEED=4] [SEATS=8] [SECONDS=40] [RES=1440x900] [SPLIT=1] [ARGS=]`: a bots-only match in
# a window, V-Sync off and always on top, a bot at the local seat's eyes (ARGS=--observer
# for the observer camera; ARGS=--quality=high or --render-scale=1 to try a setting), its
# frame rate summed up from the engine's own once-a-second --print-fps: the median and the
# 10th percentile of the samples after the first 8, and the load average. A window the
# system is not drawing idles at a flat ~145 fps: such a run prints NOT DRAWING and fails.
# SPLIT=1 (any value but 0) also prints where each frame's time goes over the match's
# drawn frames from the same second on — the bots, the host's step, snapshot and digest,
# the wire, the client, the sinking poses, the display scripts, the render's CPU and GPU,
# draw calls — its unaccounted rest with it (FrameProbe). Its client only watches, so it
# never predicts: its reconcile is the restore of each snapshot.
# Rules live in tools/fps.sh. Not part of verify: it needs a display, and the machine to
# itself — it takes the window lock itself, as capture does.
fps:
	GODOT="$(GODOT)" tools/fps.sh $(if $(SEED),--seed=$(SEED)) $(if $(SEATS),--seats=$(SEATS)) \
		$(if $(SECONDS),--seconds=$(SECONDS)) $(if $(RES),--resolution=$(RES)) \
		$(if $(filter-out 0,$(SPLIT)),--split) $(if $(ARGS),-- $(ARGS))

# `make arena SEEDS=200 [LOBBIES=normal,hard-easy] [STOP=15:00] [SCENARIO=]`: bots-only
# lobbies of the default match, seeds 1…SEEDS each, headless, written up as
# docs/arena.md — the record SH7's gates read; a match still on at STOP is stopped and
# counted unfinished. SCENARIO plays one of a ship's scenarios on her instead
# (steamer_coast), written up as docs/arena_SCENARIO.md with how long matches on a wreck
# at rest with dry footing run (Q21).
# Rules live in tools/arena.gd. Progress goes to stderr.
SEEDS ?= 200
LOBBIES ?=
arena:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/arena.gd \
		-- --seeds=$(SEEDS) $(if $(LOBBIES),--lobbies=$(LOBBIES)) $(if $(STOP),--stop=$(STOP)) \
		$(if $(SCENARIO),--scenario=$(SCENARIO)) \
		| grep -v '^\[godot_ai'

# `make hits SHIP=steamer SEEDS=200`: the spread of SHIP's iceberg hits over seeds
# 1…SEEDS, each struck as her match on that seed strikes it — sides, places, the cells
# opened, areas, moments, the walls weakened, the doors jammed and the openings left
# open. Headless; no match is played. Rules live in tools/hits.gd.
hits:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/hits.gd \
		-- $(if $(SHIP),--ship=$(SHIP)) --seeds=$(SEEDS) | grep -v '^\[godot_ai'

# `make bake SEED=1701 [SHIP=] [HIT=path.tres|NAME] [FAST=1]`: a seed's sinking alone, no match played (§5b.4):
# the hit the must-sink rule chose (or HIT='s), how it came to it, every event of the
# bake in physics time, how she ends and her labels, and what the bake cost and the
# timeline weighs. Headless. Rules live in tools/bake.gd.
bake:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/bake.gd \
		-- $(match-args) | grep -v '^\[godot_ai'

# `make census SHIP=steamer SEEDS=200 [MATCHES=20]`: the outcome census (§5b.4), written to
# docs/census.md, another ship's to docs/census_SHIP.md — each seed's first hit baked as drawn (raw) and as the must-sink rule
# chose it (match), every label's share beside its band, the rule's redraws, bakes and
# fallback rungs with the holes they make, hit → gone, the share of each sinking MATCHES
# bots-only matches saw (R33), and the bakes' cost against §5b.4's budgets. Minutes, not
# part of verify: run it in every PR that changes the physics or a ship's data. Progress
# goes to stderr. Rules live in tools/census.gd.
MATCHES ?= 20
census:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/census.gd \
		-- $(if $(SHIP),--ship=$(SHIP)) --seeds=$(SEEDS) --matches=$(MATCHES) \
		| grep -v '^\[godot_ai'

# The art against the data (D6) and the snapshots (D5): drawn platform tops,
# every seat's model on its feet, no live sim object named under scenes/art.
# Rules live in tools/art_lint.gd. Two frames per tick, so the view interpolates.
# SHIP=trawler checks that ship's art alone, and plays no match.
art-lint:
	$(call require-godot)
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . --fixed-fps 60 \
		-s res://tools/art_lint.gd $(if $(SHIP),-- --ship=$(SHIP)) | grep -v -e '^\[godot_ai' -e '^match seed'

# The GUT suite, headless. One script:
#   make test TEST=tests/unit/core/test_ticks.gd
# The whole suite runs as JOBS shards side by side (tools/test_shards.py deals the
# scripts); JOBS=1 runs it in one engine. One shard of N, as CI runs it:
#   make test SHARD=2/8
# A given list of scripts, exactly those, over JOBS shards or one SHARD the same way:
#   make test TESTS="tests/unit/core/test_ticks.gd tests/unit/core/test_air.gd"
# TESTS= with nothing in it runs nothing and passes; given at all, it wins over TEST.
# tools/run_tests.sh hands any other GUT flag through (-gunit_test_name=...).
# Every test engine, from any worktree or session, first takes one of TEST_SLOTS
# machine-wide slots (tools/test_slot.sh), a kernel lock dropped however its engine
# ends: half the cores by default, TEST_SLOTS=6 on make or in the environment to
# change it (make hands either to the recipe as it is). A run that has to wait for one
# says so in one line.
TEST ?=
SHARD ?=
JOBS ?= 4
# TESTS is left undeclared: its origin is what tells an empty list from none. Only
# a list given on make's command line counts, so a stray TESTS in the environment
# cannot cut make verify down to nothing.
test-list = $(filter command line,$(origin TESTS))
test-split = $(if $(SHARD),--shard $(SHARD),$(if $(filter-out 1,$(JOBS)),--jobs $(JOBS)))
test:
	$(call require-godot)
	$(if $(test-list),printf '%s\n' $(TESTS) | )GODOT="$(GODOT)" tools/run_tests.sh \
		$(if $(test-list),--list - $(test-split),$(if $(TEST),-gselect=$(notdir $(TEST)),$(test-split)))

# tests/durations.tsv, the seconds tools/test_shards.py balances the shards by, from
# a finished CI verify run's logs (gh fetches them; RUN is its id):
#   make durations RUN=38882193885
durations:
	$(if $(RUN),,$(error make durations needs RUN=<verify run id>; gh run list --workflow verify))
	tools/test_durations.py --run $(RUN)

# Only the test scripts the branch's changes can reach (tools/test_changed.py): its
# commits and its uncommitted and untracked edits against the merge-base with
# origin/main, each script printed with the chain that pulled it in, then run as a
# TESTS list over JOBS or one SHARD. Nothing runs, and no engine starts, when no
# GDScript, resource or scene changed; the whole suite runs, saying why, when the
# change touches project settings, addons/, the test runner or a file the graph
# cannot place. A ship's data, generator or authoring scene selects only the tests
# that can load her. CI still runs the whole suite.
test-changed:
	@list=$$(mktemp) || exit 1; trap 'rm -f "$$list"' EXIT; \
	tools/test_changed.py --list "$$list" || exit 1; \
	if [ "$$(cat "$$list")" = ALL ]; then \
		GODOT="$(GODOT)" tools/run_tests.sh $(test-split); \
	elif [ -s "$$list" ]; then \
		GODOT="$(GODOT)" tools/run_tests.sh --list "$$list" $(test-split); \
	fi

# The merge gate, in one command. Order is cheapest-feedback-first: parsing
# fails fastest, style next, the suite last.
#
# Needs Godot 4.7+ and gdtoolkit 4.x for the lint and format steps:
#   pipx install "gdtoolkit==4.*"
verify: check guard-check ship-gen-check bake-check lint format-check test

# The local bar for done: every gate verify runs, with test-changed — the tests the
# branch's changes can reach — in place of the whole suite. A branch that touches only
# tooling or docs starts no test engine. CI runs the full verify on every PR, and
# nothing merges until it is green on the PR head.
verify-changed: check guard-check ship-gen-check bake-check lint format-check test-changed

# Each ship's layout and structure are generated by her tools/gen_NAME.py — the steamer's,
# the trawler's (SH30), the ferry's (SH35), the tug's (SH36), the barque's (SH37), the
# freighter's (SH38): change her there, then `make ship SHIP=NAME`, or `make ship` for
# every one. ship-gen-check fails when any data/ships/NAME.tres is not exactly what her
# generator writes, so a hand edit to a .tres cannot drift from it. Generators write
# test-only hulls too, under tests/fixtures/ships/ and held to them the same way:
# TEST_HULLS, each as SHIP:FIXTURE:FLAG — the steamer's weak hull (SH33), the Titanic's
# sisters (SH34). ship-check is ship-gen-check and then the float test: it floats every
# ship with a structure intact, level at her stated waterline, and proves she founders on
# her sure hit, the must-sink rule's last rung, within the bake's cap of each of her
# scenarios (tests/unit/core/test_ship_check.gd). verify runs only ship-gen-check: the
# float test is one of the suite's scripts, so it runs once, inside test, rather than
# twice (tools/ship_check_once.sh holds verify to that).
GENERATED = $(patsubst tools/gen_%.py,%,$(wildcard tools/gen_*.py))
TEST_HULLS = steamer:steamer_weak:--weak titanic:titanic_olympic_1913:--variant=olympic1913 \
	titanic:titanic_britannic:--variant=britannic
ship:
	@for ship in $(if $(SHIP),$(SHIP),$(GENERATED)); do \
		python3 tools/gen_$$ship.py data/ships/$$ship.tres || exit 1; done
	@for hull in $(TEST_HULLS); do ship=$${hull%%:*}; rest=$${hull#*:}; \
		if [ -z "$(SHIP)" ] || [ "$(SHIP)" = $$ship ]; then \
		python3 tools/gen_$$ship.py tests/fixtures/ships/$${rest%%:*}.tres $${rest#*:} || exit 1; fi; done

ship-gen-check:
	@for ship in $(GENERATED); do \
		out=$$(mktemp) && python3 tools/gen_$$ship.py "$$out" >/dev/null \
		&& cmp -s "$$out" data/ships/$$ship.tres; status=$$?; rm -f "$$out"; \
		test $$status -eq 0 || { echo "ship-gen-check: data/ships/$$ship.tres differs from tools/gen_$$ship.py — run make ship SHIP=$$ship" >&2; exit 1; }; \
	done
	@for hull in $(TEST_HULLS); do ship=$${hull%%:*}; rest=$${hull#*:}; \
		fixture=tests/fixtures/ships/$${rest%%:*}.tres; flag=$${rest#*:}; \
		out=$$(mktemp) && python3 tools/gen_$$ship.py "$$out" $$flag >/dev/null \
		&& cmp -s "$$out" $$fixture; status=$$?; rm -f "$$out"; \
		test $$status -eq 0 || { echo "ship-gen-check: $$fixture differs from tools/gen_$$ship.py $$flag — run make ship SHIP=$$ship" >&2; exit 1; }; \
	done

ship-check: ship-gen-check
	GODOT="$(GODOT)" tools/run_tests.sh -gselect=test_ship_check.gd

# A ship drawn as a scene (SH17): authoring/NAME/NAME.tscn, a scene of marked pieces —
# boxes, wedges, lines and markers tagged with what they are, the numbers that are not
# shapes as their metadata (tools/ship_scene_bake.gd holds the vocabulary) — baked into
# the layout and structure the sim reads: `make bake-ship SCENE=authoring/NAME/NAME.tscn
# OUT=data/ships/NAME.tres` lints what it bakes and saves it. The sim reads only the .tres
# (D6). bake-check bakes every authoring scene and fails, printing every field that
# differs, unless it is data/ships/NAME.tres field for field. The steamer's scene is
# drawn from her generated data — `make ship-scene SHIP=steamer` — so a change to
# tools/gen_steamer.py redraws it, and bake-check holds the two together.
bake-ship:
	$(call require-godot)
	@test -n "$(SCENE)" -a -n "$(OUT)" || \
		{ echo "bake-ship: SCENE=<authoring scene> and OUT=<ship .tres> are required" >&2; exit 1; }
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd \
		-- --scene=$(SCENE) --out=$(OUT) | grep -v '^\[godot_ai'

bake-check:
	$(call require-godot)
	@set -o pipefail; for scene in authoring/*/*.tscn authoring/*/*.glb; do \
		test -e "$$scene" || continue; ship=$$(basename $${scene%.*}); \
		tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd -- --scene=$$scene \
		--check=data/ships/$$ship.tres | grep -v '^\[godot_ai' || exit 1; done
	@for blend in authoring/*/*.blend; do test -e "$$blend" || continue; \
		test -e "$${blend%.blend}.glb" || { \
		echo "bake-check: $$blend has no $${blend%.blend}.glb beside it — run make bake-blend SHIP=$$(basename $$blend .blend)" >&2; \
		exit 1; }; done
	@if ! command -v "$(BLENDER)" >/dev/null; then \
		echo "bake-check: no Blender at $(BLENDER) — each .blend held through the .glb committed beside it"; \
	else set -o pipefail; for blend in authoring/*/*.blend; do test -e "$$blend" || continue; \
		dir=$$(mktemp -d) && glb=$$dir/$$(basename $$blend .blend).glb \
		&& $(call blend-export,$$blend,$$glb) \
		&& tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd -- --scene=$$glb \
		--check=data/ships/$$(basename $$blend .blend).tres | grep -v '^\[godot_ai'; \
		status=$$?; rm -rf "$$dir"; test $$status -eq 0 || exit 1; done; fi

ship-scene:
	$(call require-godot)
	@test -n "$(SHIP)" || { echo "ship-scene: SHIP=<a ship under data/ships> is required" >&2; exit 1; }
	@set -o pipefail; tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd \
		-- --draw=data/ships/$(SHIP).tres --scene=authoring/$(SHIP)/$(SHIP).tscn \
		| grep -v '^\[godot_ai'

# A ship authored in Blender (#125): authoring/NAME/NAME.blend, each piece an object
# whose custom property `ship` says what it is and whose other custom properties are its
# fields — the scene's vocabulary — so Blender authors the data while the hull stays
# generated from it (D6). authoring/README.md says how. `make ship-blend SHIP=NAME`
# draws data/ships/NAME.tres as that .blend (tools/ship_blend.py builds it from the
# pieces Godot lays her out as) and exports it; `make bake-blend SHIP=NAME [OUT=…]`
# exports the .blend to authoring/NAME/NAME.glb, every custom property a glTF extra that
# Godot reads back as node metadata (ShipGltf), and bakes it with the scene's baker into
# OUT, data/ships/NAME.tres unless said — which it will not overwrite for a ship her
# tools/gen_NAME.py writes, as ship-gen-check holds that file to it. bake-check holds each
# committed NAME.glb to data/ships/NAME.tres field for field, and each .blend too when
# Blender is on hand: the committed .glb is what lets verify and CI, which have no
# Blender, hold a .blend. require-blender is shared with `make models` below.
blend-export = "$(BLENDER)" --background --factory-startup "$(1)" --python-exit-code 1 \
	--python tools/ship_blend.py -- export "$(2)" | { grep '^ship_blend' || true; }
# Godot skips importing a ship's .glb: the bake reads the file itself, and an import of
# every piece as a mesh would only slow each fresh checkout.
glb-skip = { test -e "$(1).import" || printf '[remap]\n\nimporter="skip"\n' > "$(1).import"; }
ship-blend:
	$(call require-godot)
	$(call require-blender)
	@test -n "$(SHIP)" || { echo "ship-blend: SHIP=<a ship under data/ships> is required" >&2; exit 1; }
	@set -o pipefail; dir=$$(mktemp -d) && mkdir -p authoring/$(SHIP) \
		&& tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd \
		-- --draw=data/ships/$(SHIP).tres --json=$$dir/pieces.json | grep -v '^\[godot_ai' \
		&& "$(BLENDER)" --background --factory-startup --python-exit-code 1 --python tools/ship_blend.py \
		-- build $$dir/pieces.json authoring/$(SHIP)/$(SHIP).blend | { grep '^ship_blend' || true; } \
		&& $(call blend-export,authoring/$(SHIP)/$(SHIP).blend,authoring/$(SHIP)/$(SHIP).glb) \
		&& $(call glb-skip,authoring/$(SHIP)/$(SHIP).glb); status=$$?; rm -rf "$$dir"; exit $$status

bake-blend:
	$(call require-godot)
	$(call require-blender)
	@test -n "$(SHIP)" || { echo "bake-blend: SHIP=<a ship under authoring> is required" >&2; exit 1; }
	@test -e authoring/$(SHIP)/$(SHIP).blend || \
		{ echo "bake-blend: no authoring/$(SHIP)/$(SHIP).blend — make ship-blend SHIP=$(SHIP) draws one" >&2; exit 1; }
	@test -n "$(OUT)" -o ! -e tools/gen_$(SHIP).py || { \
		echo "bake-blend: data/ships/$(SHIP).tres is written by tools/gen_$(SHIP).py — pass OUT=<ship .tres> to bake elsewhere" >&2; \
		exit 1; }
	@set -o pipefail; $(call blend-export,authoring/$(SHIP)/$(SHIP).blend,authoring/$(SHIP)/$(SHIP).glb) \
		&& $(call glb-skip,authoring/$(SHIP)/$(SHIP).glb) \
		&& tools/engine_guard.sh $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd \
		-- --scene=authoring/$(SHIP)/$(SHIP).glb --out=$(if $(OUT),$(OUT),data/ships/$(SHIP).tres) \
		| grep -v '^\[godot_ai'

# `make models [MODEL=name]`: re-exports every modelled prop, or the one MODEL names,
# assets/models/NAME/NAME.blend, to the NAME.glb beside it, with Blender headless
# (tools/export_model.py), which refuses a mesh with no material or no `ink` layer;
# Godot reimports the .glb on its next import. `make model-sources [MODEL=name]`
# rebuilds each NAME.blend from the build script beside it, NAME.py (its shared kit is
# tools/model_kit.py); the .blend stays what `make models` exports, so a model shaped
# by hand in Blender needs no script. assets/models/README.md says how a model is
# authored. Neither is part of verify: Godot imports the committed .glb, so neither
# verify nor CI needs Blender. BLENDER=<path> picks the binary, else `blender` on PATH.
BLENDER ?= blender
MODEL_DIRS = $(if $(MODEL),assets/models/$(MODEL),$(shell find assets/models -mindepth 1 -maxdepth 1 -type d | sort))
define require-blender
	@command -v "$(BLENDER)" >/dev/null || { \
		echo "$@: Blender not found at $(BLENDER)" >&2; \
		echo "$@: install Blender 5.2 so \`blender\` is on PATH, or pass BLENDER=<path>" >&2; \
		exit 1; }
	@test -z "$(MODEL)" || test -d "assets/models/$(MODEL)" || { \
		echo "$@: no model assets/models/$(MODEL)" >&2; exit 1; }
endef
models:
	$(call require-blender)
	@set -o pipefail; for dir in $(MODEL_DIRS); do name=$$(basename $$dir); \
		test -f "$$dir/$$name.blend" || { echo "models: $$dir/$$name.blend is missing" >&2; exit 1; }; \
		"$(BLENDER)" --background --factory-startup "$$dir/$$name.blend" --python-exit-code 1 \
		--python tools/export_model.py -- "$$dir/$$name.glb" | { grep '^export_model' || true; } \
		|| exit 1; done

model-sources:
	$(call require-blender)
	@set -o pipefail; for dir in $(MODEL_DIRS); do name=$$(basename $$dir); \
		if [ ! -f "$$dir/$$name.py" ]; then \
			if [ -n "$(MODEL)" ]; then echo "model-sources: $$dir/$$name.py is missing" >&2; exit 1; fi; \
			echo "model-sources: $$name has no build script; its .blend is its source"; continue; fi; \
		"$(BLENDER)" --background --factory-startup --python-exit-code 1 \
		--python "$$dir/$$name.py" -- "$$dir/$$name.blend" | { grep -E "^$$name:|^Info: Saved" || true; } \
		|| exit 1; done

# `make crew-capture`: every move a brawler is drawn in, saved as one PNG
# (tools/crew_gallery.gd): VIEW=crew (the default) stands them all on a deck, VIEW=arms
# shows a seat's own arms in each through a first-person lens, in a grid, and VIEW=hats
# every hat close up from ahead and behind. Windowed, so
# it takes the window lock as capture does. CAPTURE= names the file; EYE= picks
# whose arms VIEW=arms shows (4, a jersey, by default; 2 a jacket, 1 a greatcoat),
# and FRAMES=1 saves each of its moves' frames whole beside the sheet.
VIEW ?= crew
crew-capture:
	$(call require-godot)
	tools/window_lock.sh tools/engine_guard.sh $(GODOT) --path . --resolution $(if $(RES),$(RES),1920x1080) \
		--audio-driver Dummy --fixed-fps 30 -s res://tools/crew_gallery.gd -- \
		--capture="$(if $(filter $(CURDIR)/captures/match_%,$(CAPTURE)),$(CURDIR)/captures/crew_$(VIEW).png,$(CAPTURE))" \
		--view=$(VIEW) $(if $(EYE),--seat=$(EYE)) $(if $(FRAMES),--frames) | grep -v '^\[godot_ai'

# `make sailor`: rebuilds the brawlers' sailor — rig, body and clips — from
# assets/characters/sailor/gen_sailor.py, with Blender headless, into sailor.blend and
# the sailor.glb the game loads, and its hats from gen_hats.py into hats.blend and
# hats.glb; Godot reimports the .glb files on its next import. Not
# part of verify, as for models. The sailor's README says how it is built.
sailor:
	@command -v "$(BLENDER)" >/dev/null || { \
		echo "$@: Blender not found at $(BLENDER)" >&2; \
		echo "$@: install Blender 5.2 so \`blender\` is on PATH, or pass BLENDER=<path>" >&2; \
		exit 1; }
	@set -o pipefail; "$(BLENDER)" --background --factory-startup --python-exit-code 1 \
		--python assets/characters/sailor/gen_sailor.py -- \
		"$(CURDIR)/assets/characters/sailor/sailor.blend" "$(CURDIR)/assets/characters/sailor/sailor.glb" \
		| { grep '^gen_sailor' || true; }
	@set -o pipefail; "$(BLENDER)" --background --factory-startup --python-exit-code 1 \
		--python assets/characters/sailor/gen_hats.py -- \
		"$(CURDIR)/assets/characters/sailor/hats.blend" "$(CURDIR)/assets/characters/sailor/hats.glb" \
		| { grep '^gen_hats' || true; }

# Every .gd file that is actually ours: skips the engine cache, vendored addons,
# the engine binary, and .claude/worktrees, which holds whole nested checkouts of
# this same repo and would otherwise be linted as if it were project source.
#
# Double quotes, not single: GNU make on Windows runs a $(shell …) line with no
# shell metacharacters itself and strips only double quotes, and the MSYS find
# then globs a bare pattern and finds nothing. Both quote styles read the same
# through sh on Linux and macOS.
#
# Deferred, so only the three gdtoolkit targets below pay for the walk.
SOURCES = $(shell find . -name "*.gd" \
	-not -path "./.godot/*" -not -path "./addons/*" -not -path "./bin/*" \
	-not -path "./.claude/*")

# The gdtoolkit targets run over every core, NPROC workers of 60 files each,
# fed NUL-delimited. xargs exits 123 when any one invocation fails, so a problem
# in a single chunk still fails the target. Workers' output interleaves; each
# chunk also prints its own summary line.
#
# The first file goes alone, before the fan-out, and its failure fails the
# target: gdtoolkit builds its parser cache directory (~/.cache/gdtoolkit on
# Linux, ~/Library/Caches/gdtoolkit on macOS) with a check-then-makedirs, so on a
# fresh machine — every CI runner — parallel workers race to create it and the
# losers report "Cannot open file '…': File exists" as a problem. The warm-up
# creates the directory and its parser pickles first; do not remove it.
NPROC ?= $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
gdtoolkit-each = $(1) $(firstword $(SOURCES)) && \
	printf '%s\0' $(wordlist 2,$(words $(SOURCES)),$(SOURCES)) | \
	xargs -0 -P $(NPROC) -n 60 $(1)

# Parse/type check plus lightweight architecture invariants without booting the
# scene tree. Rules live in tools/check_scripts.sh.
check:
	GODOT="$(GODOT)" tools/check_scripts.sh

# The error guard itself, against a stand-in engine that errors and exits 0; the
# window lock, against sleeps on a private lock file; the test engine slots,
# against sleeps on private ones — both again on Perl's lock, the one Git Bash on
# Windows takes (tools/lib/fd_lock.sh); make fps's SPLIT, read off make -n; make test's
# list of scripts, against a stand-in engine; make durations, against a sample log;
# verify running the float test once, read off make -n; and the gdtoolkit targets'
# warm-up, read off make -n; make test-changed's selection, against a fixture project,
# and its list of runtime-built loads, against the code.
guard-check:
	tools/engine_guard_check.sh
	tools/window_lock_check.sh
	tools/test_slot_check.sh
	FD_LOCK=perl tools/window_lock_check.sh
	FD_LOCK=perl tools/test_slot_check.sh
	tools/fps_split_check.sh
	tools/run_tests_check.sh
	tools/ship_check_once.sh
	tools/test_durations_check.sh
	tools/lint_warmup_check.sh
	tools/test_changed_check.sh
	tools/test_changed.py --check-sites

# Style and smells. Rule overrides live in gdlintrc.
lint:
	$(call require-gdtoolkit,gdlint)
	$(call gdtoolkit-each,gdlint)

# Reformat in place, each file on its own so the workers never share one;
# `make format-check` only reports.
format:
	$(call require-gdtoolkit,gdformat)
	$(call gdtoolkit-each,gdformat)

format-check:
	$(call require-gdtoolkit,gdformat)
	$(call gdtoolkit-each,gdformat --check)

# `verify`'s gates are a sequence rather than a set: they share one .godot/
# across every engine boot, and their order is the cheapest feedback first, so
# racing them under `make -j` would trade a one-second parse failure for the
# whole suite. Each runs once: ship-gen-check, not ship-check, because the float
# test is already one of test's scripts.
.NOTPARALLEL:

.PHONY: import run replay match capture smoke net-bench sim-bench bench serve-local online-e2e export-server \
	export-web export-mac export-win export-linux export-server-mac serve-web-local serve-web-local-stop fps arena \
	hits bake census art-lint test test-changed durations verify verify-changed check guard-check ship ship-gen-check ship-check bake-ship \
	bake-check ship-scene \
	ship-blend bake-blend models model-sources sailor crew-capture lint format format-check
