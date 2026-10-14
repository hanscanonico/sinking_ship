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

A lamp's model is the exception: a room's lamp (`ShipLamp`) swings as a pendulum and
its glass glows as it burns, so each lamp draws its kind's model as one mesh instance
of its own under the lamp, every surface in the lamp's own material for its paint
(`sconce_glass` its glass, `brass` its brass, a cargo lamp's `steel` its tin). Every
lamp of a kind shares the one mesh.

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
| `gauge_small` | `RoomDressing.gauge()`, by radius (`GAUGES`) | furniture | 113 |
| `handwheel_large` | `RoomDressing.wheel()`, by radius (`HANDWHEELS`) | furniture | 190 |
| `chandelier` | `LinerPublic._chandelier`, one per pendant of a landing and the lounge | hero | 792 |
| `boiler_100`, `boiler_85`, `boiler_65`, `boiler_50` | `EngineRoom._boiler`, the largest front its bulkhead has room for | hero | 1090, 1066, 640, 592 |
| `crate` | `ShipArt._crate`, each under its own node | furniture | 334 |
| `washstand` | `CabinDressing.washstand()`, in a cabin and by a block of berths | furniture | 294 |
| `locker` | `CabinDressing.locker()`, in a cabin and by a block of berths | furniture | 182 |
| `luggage_shelf` | `CabinDressing.luggage_shelf()`, over a cabin's doorway | furniture | 192 |
| `luggage_rack` | `CabinDressing._rack`, over a narrow cabin's folded berth | furniture | 264 |
| `coat` | `CabinDressing.coat()`, on a cabin's wall | furniture | 261 |
| `folded_berth_190` | `CabinDressing._folded_berth`, by length (`FOLDED_BERTHS`) | furniture | 282 |
| `berth` | `RoomDressing.slung_berth`, every cabin's and block of berths' (`LinerBerths`) | furniture | 234 |
| `lifebelt` | `RoomDressing.lifebelt`, in passages and holds and on deckhouses (`ShipFittings`) | furniture | 192 |
| `fire_buckets` | `RoomDressing.fire_buckets`, a rack over head height | furniture | 344 |
| `pendant_lamp` | `ShipLamp`, a room's pendant, under its own lamp node | wall decor | 130 |
| `cargo_lamp` | `ShipLamp`, a hold's cargo lamp, under its own lamp node | furniture | 292 |
| `furnace_fire` | `ShipLamp`, a furnace's fire, under its own lamp node | furniture | 32 |
| `break_door` | `ShipFittings._break_door`, in a break's face tall enough for it | furniture | 266 |
| `deck_pipe_20`, `deck_pipe_13` | `ShipFittings._deck_pipe`, the hawse and spurling pipes' mouths, by radius (`DECK_PIPES`) | furniture | 288, 280 |
| `stowed_crate_80`, `stowed_crate_70`, `stowed_crate_62` | `CargoHold.crate`, a tween deck's stowed crates, the largest that fits (`STOWED_CRATES`) | furniture | 278 each |
| `crosstree_15`, `crosstree_20`, `crosstree_60` | `DeckWorks.mast`, near each mast's head, the largest no bigger than the mast (`CROSSTREES`) | hero | 660, 660, 740 |
| `masthead_light` | `DeckWorks.mast`, the steaming light on each mast's fore side | hero | 890 |
| `mast_cleat` | `DeckWorks.mast`, either side of each mast over its foot | furniture | 198 |
| `whistle_90`, `whistle_330` | `DeckWorks.funnel`, on each funnel's fore face, the size made for it (`FUNNEL_FITTINGS`) | hero | 1228 each |
| `waste_pipe_head_90`, `waste_pipe_head_330` | `DeckWorks.funnel`, the waste pipe's head over each funnel's top, the size made for it | furniture | 354 each |
| `pipe_clamp_90`, `pipe_clamp_330` | `DeckWorks.funnel`, up each funnel's pipes, `CLAMP_SPACING` apart, the size made for it | wall decor | 130 each |
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
  - `chandelier`: its hub, where the pendant's globe hangs, its corona
    `LinerPublic.CHANDELIER` round; nothing of it more than `CHANDELIER_RISE` over its
    hub or `CHANDELIER_DEPTH` under it.
  - `boiler_NN`: the bulkhead's face at the floor under the front's middle, +Z out into
    the room; its front's radius NN hundredths of a metre, one of
    `EngineRoom.BOILER_FRONTS`, its middle `BOILER_FOOT` + radius up. Under head height
    nothing stands more than art-lint's 0.12 m out from the face. The four sizes share
    `tools/boiler_front.py`.
  - `washstand`, `locker`, `luggage_shelf`, `luggage_rack`, `coat`, `folded_berth_NNN`:
    on the floor at the wall's face under the fitting's middle (a coat's hook), x along
    the wall, z out of it, placed with `Wall.place()`. Their boxes are `CabinDressing`'s
    `WASHSTAND`, `LOCKER`, `LUGGAGE_SHELF`, `LUGGAGE_RACK` and `COAT`, no deeper than a
    wall fitting under `HEADROOM`. A folded berth is NNN hundredths of a metre long, one
    of `FOLDED_BERTHS`, in `FOLDED_BERTH`'s height and depth; `RoomDressing.variant()`
    picks the longest no longer than the berth asked for. The coat's collar and cuffs
    and the berth's bedding are painted `blanket`, swapped for their cabin's colour as
    they are drawn. The two luggage shelves share `tools/luggage.py`.
  - `crate`: the middle of its underside, its body `ShipArt.CRATE_SIDE` of the cargo's
    0.45 m radius each way and 0.8 m tall, its battens `CRATE_PROUD` proud. Every crate
    of every ship is that size.
  - `berth`: on the wall's face under its middle, at `RoomDressing.HEADROOM`, x
    along the wall with its head toward −x, z out of it; `BERTH` long and deep,
    `BERTH_RISE` tall to the eyes at `BERTH_EYE` its chains go up from. The chains
    are the placing code's, each to its own deckhead. A head toward +x is the same
    model mirrored along the wall. Its blanket is painted `blanket`, which
    `ShipMesh.model()`'s `paints` turns into the cabin's own colour.
  - `lifebelt`: its middle on the wall's face, facing +z; its ring
    `RoomDressing.LIFEBELT_RADIUS` round and `LIFEBELT_DEPTH` out, its grab line no
    more than `LIFEBELT_LINE` past it.
  - `fire_buckets`: on the wall's face under the rack's middle at `HEADROOM`, x along
    the wall, z out of it, turned by `RoomDressing.facing()` so its lettering is never
    mirrored; its box is `FIRE_BUCKETS`.
  - `pendant_lamp`, `cargo_lamp`: where the lamp hangs from the ceiling, the pivot it
    swings round, y up; only its swivel's ball rises over it. The globe's middle hangs
    `ShipLamp.CORD` (a cargo lamp's `CARGO_CORD`) under it, `GLOBE_RADIUS` round, where
    the lamp's light burns; a cargo lamp's shade is `CARGO_SHADE` round at its rim.
  - `furnace_fire`: on the bulkhead's face at the furnace mouth's middle, z out of it;
    `ShipLamp.MOUTH` across and up to its ragged crown, `MOUTH_PROUD` out, behind the
    boiler front's grate bars. `ShipLamp` turns it to face the lamp's way.
  - `break_door`: on a break's face at the foot of its sill's middle, x along the
    face, z out of it; `ShipFittings.BREAK_DOOR` standing on a sill
    `BREAK_DOOR_SILL` tall, in its frame; its box `BREAK_DOOR_BOX`, no deeper than a
    wall fitting.
  - `deck_pipe_NN`: the pipe's axis at the deck, its flange NN hundredths of a metre
    round, one of `ShipFittings.DECK_PIPES`, its lip no higher than `DECK_PIPE_RISE`,
    under a toe rail; `RoomDressing.variant()` picks the largest no bigger than the
    radius asked for. The two sizes share `tools/deck_pipe.py`.
  - `stowed_crate_NN`: the middle of its underside, NN hundredths of a metre square,
    as tall over all as `CargoHold.STOWED_CRATE_HEIGHTS` gives for its side, its
    lashing lying on its battens and over its lid inside that box, so a crate stacked
    on it sits on the rope. `CargoHold.stowed_crate()` picks the largest no wider and
    no taller than the crate's spot: a stack's foot is drawn its own size, the crate
    up a stack or on a barrel the largest that fits under it. The three sizes share
    `tools/stowed_crate.py`.
  - `crosstree_NN`: the mast's axis at the trestle trees' foot, `DeckWorks.CROSSTREE_DOWN`
    of the mast's height under its top, made for a mast NN hundredths of a metre
    round, one of `DeckWorks.CROSSTREES`; its arms reach `CROSSTREE_REACH` past the
    mast's side, nothing of it over `CROSSTREE_RISE` or under `CROSSTREE_DROP`, where
    its braces meet the mast. `RoomDressing.variant()` picks the largest no bigger
    than the mast. The three sizes share `tools/crosstree.py`.
  - `masthead_light`: on the mast's fore face at its shelf's top, the lantern
    forward (+x); its lens's middle `DeckWorks.MASTHEAD_LENS` from the origin,
    `MASTHEAD_UNDER` under the crosstree, where the code hangs the light's glow, a
    cylinder just round the lens (`MASTHEAD_LENS_SIZE`). Its box is
    `MASTHEAD_LIGHT_BOX`.
  - `mast_cleat`: on the mast's face at the cleat's middle, `DeckWorks.CLEAT` over
    the mast's foot, z out of the face; one each side. Its box is `CLEAT_BOX`.
  - `whistle_NN`, `waste_pipe_head_NN`, `pipe_clamp_NN`: drawn into the funnel's own
    piece, so a funnel that falls (`FunnelArt`) carries them. Each is made for a
    funnel NN hundredths of a metre round, one of `DeckWorks.FUNNEL_FITTINGS`, at its
    `FUNNEL_FITTING_SCALE`; `RoomDressing.variant()` picks the largest no bigger than
    the funnel. The pipes between are the code's, `FUNNEL_PIPE` round, their axes
    `FUNNEL_PIPE_OUT` out from the funnel's side, both times the scale, running from
    its foot. The whistle's origin is on the funnel's fore face where its steam pipe
    ends, `WHISTLE_AT` of the funnel's height up it; the waste pipe head's on the
    pipe's axis at the funnel's top, the funnel toward +x, its mouth
    `WASTE_PIPE_RISE` times the scale over the top and its stay meeting the rim
    (`FUNNEL_RIM`, the same on every funnel); a clamp's on the funnel's face, the pipe
    along +x, turned half round for the after face. The whistle's and the clamp's
    boxes are `WHISTLE_BOX` and `PIPE_CLAMP_BOX` times the scale. The three share
    `tools/funnel_fittings.py`.
- **Paints.** One material per paint, named exactly after a `ShipPaints` entry
  (`white`, `teak`, `canvas`, `rope`, `dark`, `steel`, `brass`…). The material's
  name is all the game reads: the colour comes from the paint and the ship shader's
  finish, so recolouring the palette recolours the model. A name that is no paint is
  an error naming the model and the material. Give the material a base colour close
  to the paint's so the `.blend` previews true. A placement may swap one paint for
  another (`ShipMesh.model()`'s `paints`): a part that takes its room's colour is
  painted the paint it is swapped from.
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
(`Part`, the paints' preview colours, the axis swap, and the turned, boxed and swept
shapes `lathe`, `tube`, `cap`, `torus`, `sphere`, `box`, `turned_box`, `slab`, `panel`,
`sweep` and `stud`) are in `tools/model_kit.py`.
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

## Licence

Every model is original work for this project, listed in `assets/LICENSES.md`.
