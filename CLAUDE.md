# CLAUDE.md

`AGENTS.md` is a symlink to this file — edit only `CLAUDE.md`.

**Sinking Ship** (working title) — a 3D battle-royale survival brawl on a sinking ship, in
Godot 4.7 and typed GDScript. Bots first; online play later.

Design of record: `.lavish/sinking-ship-plan.html`

- `sinking-ship-plan.html` — the MVP (SH1–SH15) and the destination (SH16–SH23). The match is
  a Node-free 30 Hz sim in `core/` that scenes only draw (D1, D2); every seat — human, bot,
  remote — enters as one quantized `InputFrame` per tick (D3); same seed + same input log ⇒
  same digest on the same build (D4); `from_snapshot(snapshot())` continues exactly and
  presentation reads snapshots only (D5); the ship is data in ship space, never mesh
  collision, and `Surfaces` is the only door to spatial questions (D6); the sinking is a pure
  function of (scenario, seed, tick) — bow-down is one scenario value, never a rule — and
  `SinkSchedule` is the only water authority (D7); bots are players reading a delayed
  `BotView` (D10); online will be server-authoritative snapshots with client re-simulation
  (D11); `ShoveResolver` takes positions as data and `MatchRunner` is the one loop (D13).

## Commands

```sh
make import                                     # once per fresh checkout or worktree
make verify                                     # the merge gate: check, lint, format-check, test
make test TEST=tests/unit/core/test_ticks.gd    # one test script
make run                                        # play: you and five bots, windowed
make match SEED=1701                            # one bots-only match, headless, as a transcript
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
