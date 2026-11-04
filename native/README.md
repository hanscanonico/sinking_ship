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
  runner, where the two cross-check scripts run against it: arm64 is where a compiler
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
every question to a `NativeWalkSearch`. Otherwise it answers itself. A checkout that
never ran `make native`, or the web export, runs the GDScript and the same match.

## Determinism

- Each operation keeps the GDScript's types and order. A GDScript `float` is a double
  and a `Vector3` floats, so a distance is worked in float32 and widened before it is
  paced and added.
- The heap is the same binary heap, with ties to the lower zone.
- Floating-point contraction is off (`-ffp-contract=off`; MSVC `/fp:precise`), for
  godot-cpp's objects as for ours.
- `tests/unit/ai/test_walk_search_native.gd` and `tests/unit/ai/test_water_native.gd`
  ask both sides the same questions and fail on any difference. CI sets
  `SINKING_NATIVE_REQUIRED=1`, so a library that fails to load fails too — on Linux
  across the suite, on macOS (arm64) for those two scripts.
