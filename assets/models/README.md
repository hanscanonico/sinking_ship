# Modelled props

A prop modelled in Blender instead of built from boxes in GDScript. Each lives in its
own folder, `assets/models/NAME/`: the source `NAME.blend`, the `NAME.glb` exported
from it, the `.glb.import` Godot writes for it, and, when the model is built by
script, `NAME.py`, the headless-Blender script that builds the `.blend`. The `.blend`
is the source the `.glb` is exported from; the `.glb` is what the game loads. Godot
never imports a `.blend` (`project.godot` turns its Blender importer off), so a
checkout without Blender imports cleanly.

A modelled prop is drawn like any procedural piece of the dressed ship. `ShipModel`
gathers the `.glb`'s meshes into one, and `ShipMesh.model()` adds its triangles to
the ship's batches: painted in the ship's paints, inked at its rims, judged indoors
or out, chunked under the lamp limit, cut by the observer's cut-away, and skipped
when it is wholly off the stretch being drawn. It never becomes a mesh instance of
its own. Where it stands is still decided by the data and the fitting code (D6). The
model is only its shape.

The fitting code asks for a model by name, `ShipModel.named("davit")`. The first ask
in a process loads the `.glb`, gathers it, reads every surface's arrays and judges
whether `model()` can paint it; every later ask, and every placement, reuses that.
A prop placed a hundred times is parsed once.

| Prop | Placed by | Class | Triangles |
|---|---|---|---|
| `lifeboat` | `ShipFittings._lifeboats`, hung in the `Lifeboat` node | lifeboat | 2928 |
| `davit` | `ShipFittings._davit`, two per boat | hero | 556 |
| `wheel_stand` | `RoomDressing._wheel_wall`, a wheelhouse's forward wall | hero | 1461 |
| `chart_case` | `RoomDressing._chart_wall`, a wheelhouse's after wall | hero | 444 |
| `bell` | `ShipFittings._bell`, on the foremast | hero | 620 |
| `gauge_small`, `gauge_large` | `RoomDressing.gauge()`, by radius (`GAUGES`) | furniture | 113 |
| `handwheel_small`, `handwheel_large` | `RoomDressing.wheel()`, by radius (`HANDWHEELS`) | furniture | 166, 190 |
| `iceberg_tabular` | `IcebergPlanner`, one berg a match, drawn by `Iceberg` | world | 764 |
| `iceberg_drydock` | `IcebergPlanner`, one berg a match, drawn by `Iceberg` | world | 896 |
| `iceberg_wedge` | `IcebergPlanner`, one berg a match, drawn by `Iceberg` | world | 596 |

## Triangle budgets

Every model is drawn into the ship's batches once per placement, so its triangles
count as many times as it is placed. Each model belongs to a class with a ceiling:

| Class | Budget | Placed | Examples |
|---|---|---|---|
| Wall decor | ≤150 | 50 and more | sconce, stateroom door, capital, clock |
| Furniture | ≤400 | 10–100 | berth, washstand, locker, crate |
| Hero | ≤1500 | 1–20 | wheel stand, chandelier, boiler face, bell, davit |
| Lifeboat | 2928 | the pilot's, grandfathered | lifeboat |
| World | ≤3000 | 1, far off | the iceberg |

## Authoring

- **Units and axes.** Metres, scale 1. Model in Blender's own axes (Z up). The export
  converts to Godot's (+Y up): Blender +X is Godot +X, Blender +Z is Godot +Y, and
  Blender −Y is Godot +Z.
- **Origin.** Where the fitting code places the prop:
  - `lifeboat`: the middle of its keel, the boat lying fore and aft along X. Its box
    over all (stem to stem, side to side, keel to the top of its cover) is
    `ShipFittings.LIFEBOAT_LENGTH × LIFEBOAT_DEPTH × LIFEBOAT_BEAM`.
  - `davit`: its post's axis at the height of the deck's edge, its swan neck curving
    out toward Godot +Z (Blender −Y). The code turns it half round for port. It rises
    `DAVIT_RISE` and curves through a quarter circle of `DAVIT_REACH`, so its tip
    stands `DAVIT_REACH` out and `DAVIT_RISE + DAVIT_REACH + DAVIT / 2` up. Its foot
    is `DAVIT_FOOT` under the deck.
  - `wheel_stand`, `chart_case`: on the floor at the wall's face under the prop's
    middle, x along the wall (`Wall.right`), z out of it into the room; the code places
    each with `Wall.place()`. Their boxes are `RoomDressing.WHEEL_STAND` and
    `CHART_CASE`, no deeper than a wall fitting.
  - `bell`: where its bracket meets the mast's after face, at `ShipFittings.BELL` over
    the deck, the bracket reaching aft (−x) `BELL_REACH`; its box is `BELL_BOX`.
  - `gauge_*`, `handwheel_*`: a gauge's face's middle, a handwheel's hub, facing +z;
    `RoomDressing.facing()` turns +z along the normal. A gauge's case reaches
    `GAUGE_BACK` behind it, a handwheel's spindle `HANDWHEEL_SPINDLE`. Each variant is
    built at its own radius (`GAUGES`, `HANDWHEELS`); `RoomDressing.variant()` picks the
    largest no bigger than the radius asked for, never a scaled copy.
- **Paints.** One material per paint, named exactly after a `ShipPaints` entry
  (`white`, `teak`, `canvas`, `rope`, `dark`, `steel`, `brass`…). The material's
  name is all the game reads: the colour comes from the paint and the ship shader's
  finish, so recolouring the palette recolours the model. A name that is no paint is
  an error naming the model and the material. Give the material a base colour close
  to the paint's so the `.blend` previews true.
- **Ink.** One colour attribute named `ink`, on the face corners: 1 at a hard edge and
  0 inside a face. The shader darkens a face toward the crew's ink by the
  interpolated weight, so keep the band narrow. Run an edge loop 1–4.5 cm in from
  every hard edge you ink, as the procedural pieces' rims are (`ShipMesh.RIM`). Use
  0 or 1 only: those survive the export exactly. Paint it, or set it from edge
  sharpness by script. A dark paint needs none. A surface without the layer is an
  error naming the model.
- **Shading.** Smooth faces, with sharp edges where the surface creases (Smooth by
  Angle, or edges marked sharp). The export writes split normals.
- **Nothing else.** No UVs, textures, modifiers you have not meant to apply,
  armatures or animation. Any number of mesh objects: each is gathered where it
  stands, so object transforms are fine.
- **Open edges.** Where a prop hangs past a deck's edge, nothing in it may face up
  between a step down and a jump up from that deck, or it reads as floor
  (`make art-lint`). The lifeboat is a closed hull under its cover, with no thwarts.

## World models

A world model is no ship's prop: it is not drawn through `ShipMesh.model()`, carries
no paints and no ink, and stands outside the ship's batches as a mesh of its own. The
iceberg is one: `IcebergPlanner` picks one of `BERGS` by the match's seed, reads its
faces and their colours, scales it uniformly to the height it gives the match's berg
and draws its spur's blade out to the gash; `Iceberg` draws it with
`iceberg.gdshader`. Each berg is built by `tools/berg_kit.py` to the planner's
measure:

- the sea at y = 0, every face wholly over or under it; its top at
  `IcebergPlanner.BERG_HEIGHT` (10 m) and its foot `DRAUGHT × FOOT` of that under;
  square across x = 0 and, each side, as wide as `SPREAD` allows of its height. The
  bergs differ in proportion as discrete models, never by a squash at run time;
- its side toward her along +z: nothing under the sea stands nearer her than the
  furthest it reaches over the sea, but its spur, a ram whose blade is the two
  points furthest along +z, both at x = 0 and under the sea;
- one material, `ice`, and its colour on each face as the colour attribute `ice`
  (linear: ice facing up, shade on the steep faces, under-ice under the sea). The
  scene's `colour_layer` names it, so `tools/export_model.py` exports it as the
  vertex colour the shader reads, in place of `ink`.

## Building by script

A model may be built by a script instead of by hand: `assets/models/NAME/NAME.py`,
run by headless Blender, writes `NAME.blend` from nothing. Its points are given in
Godot's axes and its paints, ink and sharp edges set as above; the shared helpers
(`Part`, the paints' preview colours, the axis swap, and the turned and boxed shapes
`lathe`, `tube`, `cap`, `torus`, `sphere`, `box` and `slab`) are in
`tools/model_kit.py`.
Every model so far is built so; the pilots' scripts rebuild `.blend`s whose export is
byte for byte the committed `.glb`.

    make model-sources              # every NAME.py to its NAME.blend, Blender headless
    make model-sources MODEL=davit  # one

A model with no script is skipped: its `.blend` is its source. Change the script,
never the scripted `.blend` by hand, or the next rebuild loses the change.

## Exporting

    make models                     # every NAME.blend to its NAME.glb, Blender headless
    make models MODEL=davit         # one
    make import                     # Godot reimports the changed .glb

`tools/export_model.py` refuses a mesh with no material or no `ink` layer. Neither
`make verify` nor CI runs Blender, and nothing checks that a `.glb` is up to date with
its `.blend`, or a `.blend` with its script: rebuild and export after every change and
commit them all.

## The contract test

`tests/unit/art/test_committed_models.gd` keeps a table with one row per model: its
budget class and a check of its box or anchor against the placing code's constants
(the lifeboat's box is `ShipFittings`' `LIFEBOAT_*`, the davit's head and foot its
`DAVIT_*`, a berg's top, foot and width `IcebergPlanner`'s), within 2 cm. It holds
every committed ship's `.glb` to its paints and its ink, every world model to what the
planner and its shader read (a colour on every face, the waterline, its spur), and
every model to its row's box and its class's budget. A model folder with no row
fails, and so does a row with no folder: a new model lands with its row.

A variant's script may build with its sibling's builder (`gauge_large.py` calls
`gauge_small.py`'s `build()` at its own radius).

## Licence

Every model is original work for this project, listed in `assets/LICENSES.md`.
