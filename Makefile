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
#       that explicit hit, past the must-sink rule (as `make capture HIT=` does)
#   make capture SEED=1701 AT=60 [SEATS=] [SHIP=] [EYE=] [CUT=0] [CELLS=1] [SIDE=port] [HIT=] [CAPTURE=] [ARGS=]
#       a windowed bots-only match saved as a PNG at AT seconds of match time
#       (or its end), then quit: from the observer camera, or through seat EYE's
#       eyes; CUT cuts the observer's view of the ship away at and above that
#       height to show the inside; CELLS draws the ship's cells over the observer's
#       view, every one named, each filled to its water's level; HIT=path.tres strikes
#       her with that explicit hit (a fast one shows a late stage soon); SIDE=port
#       watches her from her port side rather than her starboard; ARGS passes more
#       user args, e.g. ARGS=--net-sim=latency:120,jitter:20,loss:5. Not part of
#       verify: it needs a display.
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
SEED ?=
SEATS ?=
SHIP ?=
SCENARIO ?=
SECONDS ?=
STOP ?=
HIT ?=
AT ?=
EYE ?=
CUT ?=
CELLS ?=
SIDE ?=
ARGS ?=
SCREEN ?=
RES ?=
PHYS ?=
JUMP ?=
CAPTURE ?= $(CURDIR)/captures/match_$(SEED)_$(AT)$(if $(PHYS),phys$(subst :,-,$(PHYS)))$(if $(EYE),_eye$(EYE))$(if $(CUT),_cut$(CUT))$(if $(CELLS),_cells)$(if $(SCREEN),_$(SCREEN)).png
match-args = $(if $(SEED),--seed=$(SEED)) $(if $(SEATS),--seats=$(SEATS)) $(if $(SHIP),--ship=$(SHIP)) \
	$(if $(SCENARIO),--scenario=$(SCENARIO)) $(if $(HIT),--hit=$(HIT))

run:
	$(call require-godot)
	$(GODOT) --path . -- $(match-args) $(ARGS)

# The engine helper autoload prints one line of its own on every boot; it is
# filtered so stdout is the transcript alone.
match:
	$(call require-godot)
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/run_match.gd \
		-- $(match-args) $(if $(SECONDS),--seconds=$(SECONDS)) $(if $(STOP),--stop=$(STOP)) \
		| grep -v '^\[godot_ai'

# --fixed-fps steps one tick per drawn frame, so the capture lands on its exact
# tick however fast the machine draws. A capture is silent: the Dummy driver.
# SCREEN=menu, settings, graphics, online or room starts no match, so it neither
# autoplays nor takes AT; pause, online-pause and online-settings stand over the match
# at AT.
menu-screen = $(filter menu settings graphics online room,$(SCREEN))
capture:
	$(call require-godot)
	@test -n "$(AT)$(PHYS)$(filter menu settings graphics online room results hold,$(SCREEN))" || \
		{ echo "capture: AT=<seconds of match time> or PHYS=<h:mm:ss of physics> is required" >&2; exit 1; }
	@mkdir -p "$(dir $(CAPTURE))"
	$(GODOT) --path . $(if $(RES),--resolution $(RES)) --audio-driver Dummy --fixed-fps 30 -- \
		$(match-args) $(if $(menu-screen),,--autoplay) --capture="$(CAPTURE)" \
		$(if $(AT),--capture-at=$(AT)) $(if $(PHYS),--phys=$(PHYS)) $(if $(JUMP),--jump) \
		$(if $(EYE),--capture-eye=$(EYE)) \
		$(if $(CUT),--observer-cut=$(CUT)) $(if $(CELLS),--observer-cells) \
		$(if $(SIDE),--observer-side=$(SIDE)) \
		$(if $(SCREEN),--capture-screen=$(SCREEN)) $(ARGS)

# `make net-bench [SEED=] [SEATS=] [SECONDS=] [NET=latency:120,jitter:20,loss:5]`: one
# match headless, seat 0 played through the client over a loopback lying as NET says
# (NET= for the offline game's honest wire), timed beat by beat: ticks re-run, the
# client's and the host's time, packet sizes (R7). Rules live in tools/net_bench.gd.
NET ?= latency:120,jitter:20,loss:5
net-bench:
	$(call require-godot)
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/net_bench.gd \
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
#   make export-server-mac   the dedicated server for this Mac, the same pack as the
#       Linux one: what `make serve-local EXPORTED=1` and serve-web-local run
# They need Godot's export templates for the engine's version installed, which CI has
# not: none is part of verify. No export ships the godot_ai helper autoload (R11): the
# plugin's export hook strips it from every pack, and every preset leaves addons/ out.
define export-preset
	$(call require-godot)
	@mkdir -p "$(dir $(2))" && touch build/.gdignore
	timeout 1200 $(GODOT) --headless --path . --export-release "$(1)" "$(2)"
endef

export-server:
	$(call export-preset,Linux Server,build/server/sinking_ship_server.x86_64)

export-web:
	$(call export-preset,Web,build/web/index.html)

export-mac:
	$(call export-preset,macOS,build/mac/SinkingShip.app)

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
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/sim_bench.gd \
		-- $(match-args) | grep -v '^\[godot_ai'

# `make bench [SEATS=64] [SHIP=] [SECONDS=60] [SEED=1]`: MatchSim.step timed with many bodies
# on a huge hull (SH18, R7) — seats played by seeded wanderers, no bots, on the
# Titanic-scale fixture or on SHIP — with the spatial index and without it, taking turns:
# p50 and p99 per step each way, the load average, and both ways' digests, which must
# match. Rules live in tools/bench_sim.gd.
bench:
	$(call require-godot)
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/bench_sim.gd \
		-- $(if $(SEED),--seed=$(SEED)) $(if $(SEATS),--seats=$(SEATS)) \
		$(if $(SHIP),--ship=$(SHIP)) $(if $(SECONDS),--seconds=$(SECONDS)) \
		| grep -v '^\[godot_ai'

# `make fps [SEED=4] [SEATS=8] [SECONDS=40] [RES=1440x900] [ARGS=]`: a bots-only match in
# a window, V-Sync off and always on top, a bot at the local seat's eyes (ARGS=--observer
# for the observer camera; ARGS=--quality=high or --render-scale=1 to try a setting), its
# frame rate summed up from the engine's own once-a-second --print-fps: the median and the
# 10th percentile of the samples after the first 8, and the load average. A window the
# system is not drawing idles at a flat ~145 fps: such a run prints NOT DRAWING and fails.
# Rules live in tools/fps.sh. Not part of verify: it needs a display, and the machine to
# itself — an agent takes /tmp/sinking_ship_window.lock around it, as around a capture.
fps:
	GODOT="$(GODOT)" tools/fps.sh $(if $(SEED),--seed=$(SEED)) $(if $(SEATS),--seats=$(SEATS)) \
		$(if $(SECONDS),--seconds=$(SECONDS)) $(if $(RES),--resolution=$(RES)) \
		$(if $(ARGS),-- $(ARGS))

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
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/arena.gd \
		-- --seeds=$(SEEDS) $(if $(LOBBIES),--lobbies=$(LOBBIES)) $(if $(STOP),--stop=$(STOP)) \
		$(if $(SCENARIO),--scenario=$(SCENARIO)) \
		| grep -v '^\[godot_ai'

# `make hits SHIP=steamer SEEDS=200`: the spread of SHIP's iceberg hits over seeds
# 1…SEEDS, each struck as her match on that seed strikes it — sides, places, the cells
# opened, areas, moments, the walls weakened, the doors jammed and the openings left
# open. Headless; no match is played. Rules live in tools/hits.gd.
hits:
	$(call require-godot)
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/hits.gd \
		-- $(if $(SHIP),--ship=$(SHIP)) --seeds=$(SEEDS) | grep -v '^\[godot_ai'

# `make bake SEED=1701 [SHIP=] [HIT=path.tres]`: a seed's sinking alone, no match played (§5b.4):
# the hit the must-sink rule chose (or HIT='s), how it came to it, every event of the
# bake in physics time, how she ends and her labels, and what the bake cost and the
# timeline weighs. Headless. Rules live in tools/bake.gd.
bake:
	$(call require-godot)
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/bake.gd \
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
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/census.gd \
		-- $(if $(SHIP),--ship=$(SHIP)) --seeds=$(SEEDS) --matches=$(MATCHES) \
		| grep -v '^\[godot_ai'

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
verify: check ship-check bake-check lint format-check test

# Each ship's layout and structure are generated by her tools/gen_NAME.py — the steamer's,
# the trawler's (SH30): change her there, then `make ship SHIP=NAME`, or `make ship` for
# every one. ship-check fails when any data/ships/NAME.tres is not exactly what her
# generator writes, so a hand edit to a .tres cannot drift from it, and then floats every
# ship with a structure: intact, level at her stated waterline — and proves she founders
# on her sure hit, the must-sink rule's last rung, within the bake's cap of each of her
# scenarios (tests/unit/core/test_ship_check.gd). Generators write test-only hulls too,
# under tests/fixtures/ships/ and held to them the same way: TEST_HULLS, each as
# SHIP:FIXTURE:FLAG — the steamer's weak hull (SH33), the Titanic's sisters (SH34).
GENERATED = $(patsubst tools/gen_%.py,%,$(wildcard tools/gen_*.py))
TEST_HULLS = steamer:steamer_weak:--weak titanic:olympic_1913:--variant=olympic1913 \
	titanic:britannic:--variant=britannic
ship:
	@for ship in $(if $(SHIP),$(SHIP),$(GENERATED)); do \
		python3 tools/gen_$$ship.py data/ships/$$ship.tres || exit 1; done
	@for hull in $(TEST_HULLS); do ship=$${hull%%:*}; rest=$${hull#*:}; \
		if [ -z "$(SHIP)" ] || [ "$(SHIP)" = $$ship ]; then \
		python3 tools/gen_$$ship.py tests/fixtures/ships/$${rest%%:*}.tres $${rest#*:} || exit 1; fi; done

ship-check:
	@for ship in $(GENERATED); do \
		out=$$(mktemp) && python3 tools/gen_$$ship.py "$$out" >/dev/null \
		&& cmp -s "$$out" data/ships/$$ship.tres; status=$$?; rm -f "$$out"; \
		test $$status -eq 0 || { echo "ship-check: data/ships/$$ship.tres differs from tools/gen_$$ship.py — run make ship SHIP=$$ship" >&2; exit 1; }; \
	done
	@for hull in $(TEST_HULLS); do ship=$${hull%%:*}; rest=$${hull#*:}; \
		fixture=tests/fixtures/ships/$${rest%%:*}.tres; flag=$${rest#*:}; \
		out=$$(mktemp) && python3 tools/gen_$$ship.py "$$out" $$flag >/dev/null \
		&& cmp -s "$$out" $$fixture; status=$$?; rm -f "$$out"; \
		test $$status -eq 0 || { echo "ship-check: $$fixture differs from tools/gen_$$ship.py $$flag — run make ship SHIP=$$ship" >&2; exit 1; }; \
	done
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
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd \
		-- --scene=$(SCENE) --out=$(OUT) | grep -v '^\[godot_ai'

bake-check:
	$(call require-godot)
	@set -o pipefail; for scene in authoring/*/*.tscn; do \
		$(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd -- --scene=$$scene \
		--check=data/ships/$$(basename $$scene .tscn).tres | grep -v '^\[godot_ai' || exit 1; done

ship-scene:
	$(call require-godot)
	@test -n "$(SHIP)" || { echo "ship-scene: SHIP=<a ship under data/ships> is required" >&2; exit 1; }
	@set -o pipefail; $(GODOT) --headless --no-header --path . -s res://tools/ship_bake.gd \
		-- --draw=data/ships/$(SHIP).tres --scene=authoring/$(SHIP)/$(SHIP).tscn \
		| grep -v '^\[godot_ai'

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

.PHONY: import run match capture net-bench sim-bench bench serve-local online-e2e export-server \
	export-web export-mac export-server-mac serve-web-local serve-web-local-stop fps arena \
	hits bake census art-lint test verify check ship ship-check bake-ship bake-check ship-scene \
	lint format format-check
