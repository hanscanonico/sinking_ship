# native/ — the game's GDExtension (#410)

The hottest loops of the bots and of the sinking bake in C++, giving the same answers as
the GDScript they stand in for, bit for bit: the walk-graph search (`ai/walk_search.gd`),
the bots' reads of the water (`core/still_points.gd`, `ai/walk_graph.gd`,
`ai/bot_refuge.gd`), the bake's solves for a held head and its sweep of the openings
(`core/sinking/sink_stepper.gd`, #411), and around them each opening's share open, the
cells a step holds stiff and her failures' heads across what can give way
(`core/sinking/sink_failures.gd`, #411), her lift and her water's load as she moves
(`core/sinking/ship_motion.gd`, #411), the floating furniture's contacts: where her
props stand (`core/prop_stands.gd`), what holds a circle back
(`Surfaces.obstacle_contacts` and the railings' contacts, `core/surfaces.gd`) and the
cargo's contact passes (`Hazards._move`, `core/hazards.gd`), a bot's search for a way
round by the floor and the surface under each square it asks of (`ai/bot_floor_way.gd`,
`Surfaces.under`), the dressed ship's face
emission — her faces cut at the chunk and room lines, judged indoors or out and gathered
into batches (`scenes/art/ship_mesh.gd`, `scenes/art/indoor_grid.gd`, #411) — and the
water's effects' walks of her cells, openings and decks (`scenes/art/inner_water.gd`,
`scenes/match/fx_planner.gd`, `scenes/audio/cue_planner.gd`).

## Layout

- `src/` — the extension's sources: `walk_search_native.{h,cpp}` (`NativeWalkGraph`,
  `NativeWalkSearch`), `water_native.{h,cpp}` (`NativeWater`), `sink_native.{h,cpp}`
  and `sink_step_native.cpp` (`NativeSink`), `motion_native.{h,cpp}` (`NativeMotion`), `contacts_native.{h,cpp}` (`NativeStands`, `NativeSurfaces`,
  `NativeCrates`) with `floor_way_native.cpp` (`NativeSurfaces.under` and `floor_way`), `art_native.{h,cpp}` (`NativeShipMesh`, `NativeIndoorGrid`,
  `NativeLining`), `water_fx_native.{h,cpp}` (`NativeWaterFx`), `register_types.cpp`
  (the entry, `sinking_native_init`).
- `SConstruct` — the build, over godot-cpp's; `build_profile.json` — the engine
  classes godot-cpp binds (few, so it compiles quickly).
- `build/` — not tracked: godot-cpp at its pinned commit (`tools/native_build.sh`) and
  its objects, hidden from Godot by a `.gdignore`.
- `lib/` — not tracked: `libsinking_native.<platform>.<arch>.<ext>` and the
  `sinking_native.gdextension` that loads it, written together by the build.

## Building

`make native` builds for this machine, then imports once so Godot registers the
extension. It needs `scons` (`pip install scons` in a venv, `SCONS=<path>`) and a C++
compiler: gcc or clang on Linux, Xcode's clang on macOS (`xcode-select --install`; the
library is universal, arm64 and x86_64 in one), and on Windows
[llvm-mingw](https://github.com/mstorsjo/llvm-mingw/releases) (the `ucrt-x86_64` zip,
unpacked anywhere, `LLVM_MINGW=<folder>`). Nothing goes on PATH. On Linux,
`PLATFORM=windows tools/native_build.sh` cross-compiles the Windows library with
mingw-w64 instead.

The `.gdextension` lists every platform's library in `lib/`, not only the one just
built: copy another platform's library there (CI's artifacts, below) and run
`make native` again to list it beside this machine's.

The binaries are built, never committed. CI's verify builds three, each kept a week as
an artifact of the run:

- `native (linux)` — `native-linux`, the `.so` the ten test shards load
  (`SINKING_NATIVE_REQUIRED=1`).
- `native (macos)` — `native-macos`, the universal `.dylib`, built on an Apple-silicon
  runner, where the nine cross-check scripts run against it: arm64 is where a compiler
  contracts `a * b + c` by default, so a difference from the engine's own GDScript
  arithmetic would show there first.
- `native (windows)` — `native-windows`, the `.dll`, cross-compiled on Linux with
  mingw-w64. CI does not run it; the cross-checks are run on Windows by hand.

## Exports

Every desktop export ships the library for its platform: the macOS app and the macOS
server take `macos`, the Windows game `windows.x86_64`, the Linux game and the Linux
dedicated server `linux.x86_64`. The presets export `lib/sinking_native.gdextension`
(they leave out `build/`, `src/` and `build_profile.json`), and Godot copies the library
it lists for the platform beside the binary — into `Contents/Frameworks` on macOS.

`make export-*` checks first (`tools/native_export_check.sh`) and stops when the
export's platform has no library in `lib/`, saying how to get it. `NATIVE=0` exports
without it, and the game runs the GDScript (Godot warns at the export, and the game
logs that no library loads for its platform, when `lib/` holds other platforms'). The
web preset leaves `native/` out, and its pack lists no extension: the web build has no
threads and always runs the GDScript.

The deploy's server image (`deploy/Dockerfile`) builds the Linux library with
`make native` before `make export-server`.

## The fallback

`WalkGraph` asks `WalkSearch.native_graph()` for a graph laid out for C++ once. That is
null unless `ClassDB.class_exists("NativeWalkGraph")`. A `WalkSearch` given one hands
every question to a `NativeWalkSearch`. Otherwise it answers itself. Each
`SinkStepper` asks `SinkNative.made()` for its loops the same way, null without a
`NativeSink`: the stepper keeps every state and hands the extension her layout once and
what its loops read at each turn and step; its `SinkFailures` asks it for the same
`SinkNative` (`native()`) for the heads across what can give way. Each `ShipMotion` makes a `NativeMotion` the
same way and hands it her sections, and her cells' boxes the first time it loads them;
its memo of the last lift stays GDScript's. `ContactsNative.loaded()` decides the same
for the contacts as each `PropStands`, `Surfaces` and `Hazards` is made: a `PropStands`
keeps its props on a `NativeStands`' grid, a `Surfaces` mirrors her surfaces, railings,
doors and fallen funnels into a `NativeSurfaces` the first time it is asked and tells it
of every change `honour()` makes, and `Hazards` hands a `NativeCrates` each tick's
crates for its contact passes, which reads and writes their `PropState`s and calls back
into `Hazards.damage` when a crate would break a railing. A `ShipMesh` asks
`ArtNative.made()` for a `NativeShipMesh` and hands it every face, quad, box and model,
and its `IndoorGrid` hands its grid to a `NativeIndoorGrid`; the extension calls back for
what stays GDScript's (a room's ceiling worked out, what fades, roofed space). A checkout
that never ran `make native`, or the web export, runs the GDScript and the same match,
the same sinking and the same art.

## Determinism

- Each operation keeps the GDScript's types and order. A GDScript `float` is a double
  and a `Vector3` floats, so a distance is worked in float32 and widened before it is
  paced and added. A vector's own sums, products, lengths, dots and clamps are
  godot-cpp's `Vector2` and `Vector3`, the engine's code.
- The heap is the same binary heap, with ties to the lower zone.
- `minf`, `maxf` and `clampf` are the engine's (`a < b ? a : b`, …), and a sort is the
  engine's insertion sort, which places a NaN or a -0 where the engine does.
- Floating-point contraction is off (`-ffp-contract=off`; MSVC `/fp:precise`), for
  godot-cpp's objects as for ours.
- `tests/unit/ai/test_walk_search_native.gd`, `tests/unit/ai/test_water_native.gd`,
  `tests/unit/core/test_sink_native.gd`, `tests/unit/core/test_sink_native_stages.gd`,
  `tests/unit/core/test_motion_native.gd`, `tests/unit/core/test_contacts_native.gd`,
  `tests/unit/art/test_ship_mesh_native.gd` and `tests/unit/match/test_water_fx_native.gd`
  ask both sides the same questions and fail on any difference. CI sets
  `SINKING_NATIVE_REQUIRED=1`, so a library that fails to load fails too — on Linux
  across the suite, on macOS (arm64) for those eight scripts.
