# native/ — the game's GDExtension (#410)

The bots' hottest loops in C++, giving the same answers as the GDScript they stand in
for, bit for bit. So far that is the walk-graph search (`ai/walk_search.gd`).

## Layout

- `src/` — the extension's sources: `walk_search_native.{h,cpp}` (`NativeWalkGraph`,
  `NativeWalkSearch`), `register_types.cpp` (the entry, `sinking_native_init`).
- `SConstruct` — the build, over godot-cpp's; `build_profile.json` — the engine
  classes godot-cpp binds (few, so it compiles quickly).
- `build/` — not tracked: godot-cpp at its pinned commit (`tools/native_build.sh`) and
  its objects, hidden from Godot by a `.gdignore`.
- `lib/` — not tracked: `libsinking_native.<platform>.<arch>.<ext>` and the
  `sinking_native.gdextension` that loads it, written together by the build.

## Building

`make native` builds for this machine, then imports once so Godot registers the
extension. It needs `scons` (`pip install scons` in a venv, `SCONS=<path>`) and a C++
compiler: gcc or clang on Linux, Xcode's clang on macOS, and on Windows
[llvm-mingw](https://github.com/mstorsjo/llvm-mingw/releases) (the `ucrt-x86_64` zip,
unpacked anywhere, `LLVM_MINGW=<folder>`). Nothing goes on PATH.

The binaries are built, never committed. CI builds Linux's in its `native` job, and the
test shards load it.

## The fallback

`WalkGraph` asks `WalkSearch.native_graph()` for a graph laid out for C++ once. That is
null unless `ClassDB.class_exists("NativeWalkGraph")`. A `WalkSearch` given one hands
every question to a `NativeWalkSearch`. Otherwise it answers itself. A checkout that
never ran `make native`, or the web export, runs the GDScript and the same match.

## Determinism

- Each operation keeps the GDScript's types and order. A GDScript `float` is a double
  and a `Vector3` floats, so a distance is worked in float32 and widened before it is
  paced and added.
- The heap is the same binary heap, with ties to the lower zone.
- Floating-point contraction is off (`-ffp-contract=off`; MSVC `/fp:precise`), for
  godot-cpp's objects as for ours.
- `tests/unit/ai/test_walk_search_native.gd` asks both sides the same questions and
  fails on any difference. CI sets `SINKING_NATIVE_REQUIRED=1`, so a library that fails
  to load fails too.
