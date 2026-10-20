# CLAUDE.md

`AGENTS.md` is a symlink to this file — edit only `CLAUDE.md`.

**Sinking Ship** (working title) — a first-person 3D battle-royale survival brawl on a
sinking ship with rooms, in Godot 4.7 and typed GDScript. Bots first; online play later.

Design of record: `.lavish/sinking-ship-plan.html` (rev 4)

- `sinking-ship-plan.html` — the MVP (SH1–SH15 plus SH3b, SH9b, SH14b) and the destination
  (SH16–SH35). The match is
  a Node-free 30 Hz sim in `core/` that scenes only draw (D1, D2); every seat — human, bot,
  remote — enters as one quantized `InputFrame` per tick (D3); same seed + same input log ⇒
  same digest on the same build (D4); `from_snapshot(snapshot())` continues exactly and
  presentation reads snapshots only (D5); the ship is data in ship space, never mesh
  collision, carries its structure — hull sections, cells, walls, openings, mass, strength —
  and `Surfaces` is the only door to spatial questions (D6); the sinking is physics baked
  from a seeded hit — a pure function of (ship, scenario, seed), nothing on a clock, no end
  or side assumed — and `SinkSchedule` is the only water authority, answering per cell from
  the timeline (D7); bots are players reading a delayed `BotView` (D10); online will be
  server-authoritative snapshots with client re-simulation (D11); `ShoveResolver` takes
  positions as data and `MatchRunner` is the one loop (D13); the game is first person and
  the elevated camera is only the observer tool (D14); rooms are thin wall blockers with
  door openings, floors at negative heights and steep stairs as ramps, and the water inside
  the ship is per cell (D6, D7).

## Commands

```sh
make import                                     # once per fresh checkout or worktree
make verify                                     # the full gate, CI's: check, guard-check, ship-gen-check, bake-check, lint, format-check, test
make verify-changed                             # the local bar for done: every verify gate, test-changed in test's place
make test TEST=tests/unit/core/test_ticks.gd    # one test script
make test JOBS=8                                # the suite as 8 shards side by side (default 4; JOBS=1 for one engine)
make test SHARD=2/8                             # one CI shard; tests/durations.tsv balances them
make test TESTS="tests/unit/core/test_ticks.gd …"  # exactly these scripts, over JOBS shards (TESTS= runs none)
make durations RUN=38882193885                  # rewrite tests/durations.tsv from that CI verify run's logs
make test-changed                               # only the scripts the branch's changes can reach, each with its chain
make run                                        # play: you and seven bots, windowed
make match SEED=1701                            # one bots-only match, headless, as a transcript
make match SEED=1701 FAST=1                     # the same, her sinking on the fast clock (FAST=1 works for run too)
make match SEED=1701 GOAL=survival              # survival: everyone stays in as long as she lasts (GOAL= works for run too)
make smoke                                      # the water capture sweep for QA: shots at the transcript's water moments into captures/smoke/ (MAX=3, DRY=1)
make ship                                       # regenerate data/ships/NAME.tres from tools/gen_NAME.py; SHIP=trawler for one
make bake-ship SCENE=authoring/steamer/steamer.tscn OUT=…   # bake a marked greybox scene into a ShipLayout .tres (SH17)
make bake-check                                 # every authoring/NAME/NAME.tscn bakes to data/ships/NAME.tres field for field
make ship-scene SHIP=steamer                    # draw data/ships/NAME.tres as its authoring scene
make models                                     # re-export assets/models/NAME/NAME.blend to NAME.glb (needs Blender; not in verify)
```

A fresh checkout fails `check` with phantom "not declared" errors until `make import` has
registered every `class_name`. The engine is `$GODOT`, else a vendored `bin/Godot.app`, else
`godot` on PATH; lint and format need `pipx install "gdtoolkit==4.*"`. A green
`make verify-changed` is the local bar for done; CI runs the full `make verify` on every
PR, and nothing merges until it is green on the PR head. `make verify` stays runnable
locally whenever the whole suite is wanted.

One game window at a time on this shared machine: `make capture` and `make fps` take the
window lock themselves (`tools/window_lock.sh`, a kernel lock released on any exit) — never
hand-roll a lock around them. Test engines are capped the same way: each takes one of
`TEST_SLOTS` machine-wide slots (`tools/test_slot.sh`, half the cores by default), so a run
that says it is waiting for a slot is the machine being shared, not a hang.

## Architecture

- **`core/` is Node-free.** The simulation is plain GDScript classes; scenes render it.
  Nothing in `core/` or `ai/` may reference a `Node`, a scene, `get_node`, `get_tree`,
  `SceneTree`, anything under `scenes/`, or the engine's clocks and devices (`Time`, `OS`,
  `Engine`, `Input`, `DisplayServer`) — count ticks, read `InputFrame`s. `make check`
  enforces it.
- **Seeded RNG only.** Thread a seeded `RandomNumberGenerator` through the sim; global
  `randf()`/`randi()`/`randomize()` in `core/` or `ai/` fails `make check`.
- **Balance numbers live in `data/*.tres`**, never as constants in code.
- **Godot owns the form, Blender the finish.** Everything the game measures — a blocker's
  footprint, a walkable surface, a height, an opening, the size a variant is picked by,
  every dimension a fit test reads — is declared on the Godot side (layout data, authoring
  scenes, the fitting code's tables). A model in `assets/models/NAME/` only dresses that
  envelope and stays inside it: never read gameplay or placement from a mesh's bounds, and
  never change a form by editing only a model. New props and reworks are modelled in
  Blender through the Blender MCP, judged with `look`; the saved `.blend` is the source and
  `make models` exports it. Scripted geometry is for the form (layout, cells, runtime FX
  meshes), not for art; an existing `NAME.py` prop stays scripted until it is reworked. One
  live Blender per machine: one session models at a time. See `assets/models/README.md`.

## Conventions

- Typed GDScript, tabs, `snake_case` files, one `class_name` per file matching its name
  (`sink_schedule.gd` → `SinkSchedule`). `make format` (gdformat) settles whitespace.
- Godot owns `.import` files and UIDs (`.uid` files, `uid=` in `.tscn`/`.tres`); let it
  regenerate them.
- Tests are GUT, in `tests/unit` (`test_` prefix), and cover the Node-free layers. Every
  bugfix comes with a failing test the fix makes pass. Tests seed their RNG.
- Small, focused commits with a present-tense imperative subject (`Add water level`).

## Model roles

Fable orchestrates and does not implement, research or review a PR itself. Workers are the
agents in `.claude/agents/`, every one on the latest Opus available (`model: opus` — the
alias, never Fable, never a dated Opus id), effort set by role: `scout` low, `implementer`
medium (the `improve` workflow retries once at high on a red gate or a reject), `reviewer`
high, `qa` low. `/orchestrate` carries the full loop. `qa` stays idle until the
repo has a `make smoke` capture sweep.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `hanscanonico/sinking_ship`, driven with `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default roles, each label named for its role (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the root, with the plan's D-decisions standing in for ADRs. See `docs/agents/domain.md`.
