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
make verify                                     # the merge gate: check, lint, format-check, test
make test TEST=tests/unit/core/test_ticks.gd    # one test script
make run                                        # play: you and seven bots, windowed
make match SEED=1701                            # one bots-only match, headless, as a transcript
make ship                                       # regenerate data/ships/NAME.tres from tools/gen_NAME.py; SHIP=trawler for one
```

A fresh checkout fails `check` with phantom "not declared" errors until `make import` has
registered every `class_name`. The engine is `$GODOT`, else a vendored `bin/Godot.app`, else
`godot` on PATH; lint and format need `pipx install "gdtoolkit==4.*"`. A green `make verify`
is the bar for done.

## Architecture

- **`core/` is Node-free.** The simulation is plain GDScript classes; scenes render it.
  Nothing in `core/` or `ai/` may reference a `Node`, a scene, `get_node`, `get_tree`,
  `SceneTree`, anything under `scenes/`, or the engine's clocks and devices (`Time`, `OS`,
  `Engine`, `Input`, `DisplayServer`) — count ticks, read `InputFrame`s. `make check`
  enforces it.
- **Seeded RNG only.** Thread a seeded `RandomNumberGenerator` through the sim; global
  `randf()`/`randi()`/`randomize()` in `core/` or `ai/` fails `make check`.
- **Balance numbers live in `data/*.tres`**, never as constants in code.

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
high, `qa` low. `/improve` and `/orchestrate` carry the full loop. `qa` stays idle until the
repo has a `make smoke` capture sweep.
