# Authoring a ship

A ship is the data in `data/ships/NAME.tres` (a `ShipLayout`: her decks, stairs,
blockers, railings, rooms and her structure — hull sections, cells, walls, openings, mass).
The sim reads only that file, and the hull the game draws is generated from it (D6). The
files here are ways of drawing that data so a person can edit it:

- `NAME.tscn`: the ship as a Godot scene of marked pieces (SH17). `make ship-scene
  SHIP=NAME` draws it from her data; `make bake-ship SCENE=… OUT=…` bakes it back.
  A redraw keeps the ids of everything that did not change — each node's `unique_id`
  by its path, each material's and mesh's id by its content — so it diffs as only what
  the data changed; never hand-splice nodes into the scene to spare the diff.
- `NAME.blend`: the same pieces as Blender objects (#125). `make ship-blend SHIP=NAME`
  draws it from her data; `make bake-blend SHIP=NAME [OUT=…]` exports it to `NAME.glb`
  beside it and bakes that. Blender authors the data only: no Blender mesh ever becomes
  the hull.
- `NAME.glb`: the `.blend` as glTF, every object's custom properties as its node's extras,
  which Godot reads back as node metadata (`tools/ship_gltf.gd`). It is committed so
  `make verify` and CI, which have no Blender, can still bake the `.blend`. Godot is told
  to skip importing it (`NAME.glb.import`); the bake reads the file itself.

`make bake-check` (part of `make verify`) bakes every `.tscn` and every `.glb` here, and
every `.blend` too when Blender is on PATH, and fails, printing each field that differs,
unless each one is `data/ships/NAME.tres` field for field. So after editing a `.blend`, run
`make bake-blend SHIP=NAME` before committing: it refreshes the `.glb`.

The steamer, the trawler, the ferry, the tug, the barque, the freighter and the Titanic
are generated (`tools/gen_NAME.py`, held to their `.tres` by `make ship-check`); their
`.tscn` and `.blend` are drawn from that data and held to it. Only the steamer's `.blend`
is committed, so the round trip stays proven in CI while a change to the trawler's, the
ferry's, the tug's, the barque's, the freighter's or the Titanic's generator never
needs Blender to go green. Draw theirs when you want to edit them (`make ship-blend SHIP=titanic`), and commit one only for
a ship whose layout is authored in Blender from then on. `make bake-blend` will not overwrite a generated ship's `.tres`: pass `OUT=` to bake
an edit elsewhere and compare, then carry the change into her generator.

`make ship-blend`, `make bake-blend` and the Blender half of `make bake-check` run Blender
headless (`BLENDER=<path>`, else `blender` on PATH; Blender 5.2). Without it the first two
stop and say so, and `bake-check` holds each `.blend` through its committed `.glb`.

## The vocabulary

A piece is an object whose custom property `ship` says what it is; an object without one
(a folder such as `Platforms`, a camera, a light) is passed over, though its own move still
moves everything parented under it. Every other field of the piece is a custom property of
the field's own name (Object properties → Custom Properties). A field not set keeps its
default. The shape-given fields below are never custom properties: the bake reads them
from the object, and says so if one is set.

`tools/ship_scene_bake.gd` holds the vocabulary for both the scene and the `.blend`:

| `ship` | In Blender | Its shape gives | Its custom properties, for example |
| --- | --- | --- | --- |
| `layout` | the root empty | — | `freeboard`, `deck_thickness`, `min_seats`, `max_seats`, `dressed` |
| `platform` | a box mesh, its top the deck | `area`, `height` | `name`, `slab` |
| `ramp` | a wedge mesh (a stair): its top edge at one end of its local X | `area`, `axis`, `start_height`, `end_height` | — |
| `blocker` | a box mesh, or an upright cylinder mesh | `shape`, `area`, `centre`, `radius`, `bottom`, `top` | — |
| `railing`, `ladder` | a thin box along a platform's edge, from its local −X end to its +X end | `from`, `to` | `platform`: the platform object's name |
| `spawn` | an empty where a seat starts | the point | — |
| `prop` | an upright cylinder mesh, its underside where it stands — a hung one's at its deck's height on its span | `pos`, `radius`, `height` | `kind` (`"lifebuoy"`; cargo when unset), `mass`, `friction`, `grip_angle_deg`; `railing`: the railing object's name a ring hangs on, as a railing names its platform |
| `room` | a box mesh, its bottom the room's floor; its top is not data | `area`, `floor_height` | `name` |
| `bonus_spot` | an empty on its room's floor, where a bonus can come aboard | `point` | `room`: the room object's name it lies in, as a railing names its platform |
| `structure` | an empty | — | `waterline_y`, `keel_y`, the seakeeping numbers |
| `section` | a hull section: the outline as the face at its local +Z end, extruded toward local −Z | `x`, `length`, `outline` | — |
| `cell` | a box mesh | `low`, `high` | `name`, `kind`, `permeability`, `rooms` |
| `wall` | a box mesh flat across ship X or ship Z | `axis`, `at`, `span`, `bottom`, `top` | `name`, `cells`, `leak_head`, `collapse_head` |
| `opening` | a box mesh flat across one axis: its rectangle | `centre`, `size` | `name`, `kind`, `joins`, `starts`, … |
| `mass`, `fitting` | an empty at the item's centre or the fitting's base | the point | `name`, `mass`; `kind`, `side`, … |
| `strength` | an empty; each `weak_spot` an empty under it at its X | `weak`; a weak spot's `x` | — |
| `sure_hit` | an empty | — | the hit's numbers |

Each resource's own script (`core/ship_*.gd`, `core/sinking/*.gd`) says what every field
means. The custom properties take Blender's types:

- a name or an enum is a string: `name = "saloon"`, `kind = "DOOR"`, `starts = "SHUT"`;
- a list of names is a list of strings: `joins = ["saloon", "sky"]`;
- a number is a float, or an int for a field that counts (`min_seats`);
- a vector is a float array (`along = [1.0, 0.0]`), and a list of points its numbers in a
  row: `shipping_edges = [x, y, z, x, y, z, …]`;
- a flag is a boolean.

## Ship space in Blender

One Blender unit is a metre. Ship X (toward the bow) is Blender X, ship Y (up) is
Blender Z, and ship Z (to starboard) is Blender −Y: starboard is toward −Y, port toward +Y.
The deck at height 0 is the main deck.

A box, a wedge, a cylinder or a section is read from its own vertices, in its object's
frame: move, scale and turn it in Object Mode or edit its vertices in Edit Mode, either
reads the same. Boxes stand square to the ship, unturned. A wedge, a railing and a ladder
turn about Blender Z only — wedges by quarter turns. A wall or an opening has no
thickness along the one axis it is flat across. A cylinder reaches its radius on its
local X.

Pieces of a kind are read in order, and the order is data. Blender and the glTF list
objects by name, so a number and a space before a name order an object among its
siblings — `0007 Room_saloon` — and are not part of the name the bake sees. An object
without one comes after the numbered ones, by name. Names are unique; a railing names its
platform without the number (`Platform_poop_deck`).

The rooms and the structure open hidden, so the file opens on her decks; unhide them (Alt
H) to work on them. Hiding an object (H, the eye) does not leave it out of the bake; never
disable one in viewports (the screen icon) instead, as Blender then stops placing it and
the export loses where it stands.

## Snapping to the generators' grain

The bake reads every shape to 4 decimals of a metre (`ShipSceneBake.PLACES`), the
generators' own grain, and rounds anything finer. The generators lay the decks, stairs,
blockers and rooms out on a 0.1 m grid: decks and walls 0.2 m thick (a wall centred on a
room's side), doors 1.1 m wide and 2.1 m high, stairs from one deck's top to the next.

In Blender, snap to that grid: Snapping → Snap To Increment with Absolute Grid Snap, and the
viewport's grid scale (Overlays → Guides → Scale) at 0.1. Type an exact value in the
sidebar (N) for anything off the grid — and check a box's dimensions there, since the bake
reads what the vertices are, not what they look like.

## Adding a room, a door, a stair or a bonus spot

Duplicate a piece of the kind (Shift D) rather than starting from nothing: it keeps the
`ship` property and the fields, and the copy goes under the same folder. Give it a new
name and number it to where it belongs among its siblings.

**A room.** Duplicate a `room` box under `Rooms`, set its `name`, and size it to the
floor's plan out to the middle of its walls, its bottom on the deck it stands on. The room
is an annotation: its walls are `blocker` boxes along its sides (0.2 m thick, centred on
the side, from the deck to the deck above), and the water in it belongs to a `cell` box
under `Structure/Cells` with its own `name`, `kind` and `permeability`.

**A door.** A doorway is a gap in a room's wall blockers: split the wall into two blockers
1.1 m apart and put a lintel blocker over the gap from 2.1 m up to the deck above. For the
water, add an `opening` under `Structure/Openings` in the gap — flat across the wall's
axis, 1.1 by 2.1 m — with `kind = "DOOR"` (or `"WATERTIGHT_DOOR"`) and `joins` the two
cells it joins.

**A stair.** Duplicate a `ramp` wedge under `Ramps`: its low end on the lower deck's top,
its high end on the upper deck's, its top edge at the high end, turned about Z by quarter
turns. The upper deck needs a gap over the stair (split its platform round it) and, where
the stair passes a deck between two cells, a `STAIRWELL` opening joins them.

**A bonus spot.** A room below her main deck — its floor under zero — has one, where a
bonus can come aboard (#308): duplicate an empty under `BonusSpots`, set its `room` to the
room object's name, and stand it on the room's floor, clear of its stairs, blockers and
walls. The layout lint holds it there. A generated ship's spots are her generator's, each
at the free point of its room's floor nearest the middle (`tools/floor_spots.py`).

Then `make bake-blend SHIP=NAME OUT=…` bakes it and lints what it baked
(`ShipLayout.problems`), saying what is wrong and where, before it saves anything.
