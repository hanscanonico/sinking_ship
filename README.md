# Last One Dry

A first-person battle-royale brawl aboard a sinking ship. The sea comes in room by
room: shove the others into it, keep your feet, and be the last one dry. Play against
seven bots, or online in rooms you share by code. Made with Godot 4.7.

## Play

Download the zip for your system from the
[Releases](https://github.com/hanscanonico/sinking_ship/releases) page (or itch.io),
unzip it anywhere and run the game: `LastOneDry.exe` on Windows, `LastOneDry.x86_64` on
Linux, `LastOneDry.app` on macOS — unnotarized, so the first time allow it under System
Settings > Privacy & Security > Open Anyway (right-click > Open before macOS 15). Each
zip's `README.txt` says more.

| | Keyboard and mouse | Gamepad |
|---|---|---|
| Move | W A S D or arrows | Left stick or D-pad |
| Look | Mouse | Right stick |
| Shove | Left mouse or F | Right trigger or X / Square |
| Brace | Right mouse or Shift | Left trigger or right bumper |
| Jump | Space | A / Cross |
| Pause | Esc | Start |
| Rematch, once the match is over | R | Start |
| Once out: next / previous player | E / Q | D-pad right / left |
| Once out: free camera | C | Y / Triangle |

Every key but Rematch can be rebound under Settings > Keys (saved to
`user://key_bindings.json`); Settings also holds sound, mouse, field of view, window
mode, VSync and the frame cap. A match sinks at her slow, realistic pace by default: tick
Fast sinking under Custom match (or `make run FAST=1`) for the fast clock. Bonuses come
aboard below decks by default: untick Bonuses beside it (or `make run BONUSES=0`) for the
plain brawl. The Credits screen carries the licences.

Online play needs a game server: enter its `ws://` or `wss://` address under Play
online. Rooms sink at the server's pace and have bonuses as it says, `fast` and `bonuses`
in `data/net/server.tres`; `deploy/README.md` says how to host one.

## Build from source

Install [Godot 4.7.1](https://godotengine.org/download) (the Makefile finds `$GODOT`,
else `godot` on PATH) and GNU make, then:

```sh
make import        # once per fresh checkout: registers every class_name
make run           # play: you and seven bots
make export-win    # build/win/LastOneDry.exe; export-linux and export-mac likewise
```

The exports need Godot's export templates for the same version (Editor > Manage Export
Templates). Developers: start with [CLAUDE.md](CLAUDE.md) — architecture, conventions,
and the `make verify` gate every pull request passes.

## Cut a release

1. Bump `config/version` in `project.godot` (e.g. `0.9.1`) and merge it.
2. Export and package the three builds: `make export-win export-linux export-mac`, then
   `tools/package_release.sh 0.9.1`. It writes `build/release/LastOneDry-0.9.1-{windows,linux,mac}.zip`,
   each holding the game, its `README.txt` and `licenses/`.
3. Attach the zips to the tag's GitHub Release:
   `gh release create v0.9.1 build/release/LastOneDry-0.9.1-*.zip --generate-notes`.

A tag-triggered workflow that does steps 2 and 3 on CI (and pushes to itch.io) is
waiting to land; it needs a token with the `workflow` scope to be pushed.
