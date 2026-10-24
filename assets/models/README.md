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

## Form and finish

Godot owns the form; Blender owns the finish. The form is everything the game measures:
a blocker's footprint, a walkable surface, a height, an opening, the size a variant is
picked by (`STOWED_CRATES`, `CROSSTREES`, `FOLDED_BERTHS`, `GAUGES`, …), and every other
dimension a fit test reads. It is declared on the Godot side — the ship's layout data,
its authoring scene, the fitting code's tables — and a model dresses it: bevels, trim,
silhouette detail, paint, all inside that envelope.

- **Declare before you model.** A new prop's envelope lands in Godot first; the model is
  built inside it, with the envelope blocked in as a guide.
- **Never read the form from a mesh.** Nothing places, sizes or collides by a model's
  bounds. Cut-away and stretch culling (`ShipModel.bounds`) are drawing, not form.
- **A form changes in Godot.** Making a prop bigger is a change to the data or the
  table, in its own reviewable diff, never a re-sculpt alone. A dimension that today
  exists only in a `NAME.py` (a stowed crate's height, a boiler front's depth) moves to
  the Godot side the next time that prop is touched.
- **Model in Blender, by eye.** New props and reworks are modelled through the Blender
  MCP, judged with `look`; the saved `.blend` is the source and `make models` exports
  the `.glb`. Vertex lists in Python or GDScript are for the form, not for art. The
  `NAME.py` props stay scripted until someone reworks them.
- **One live Blender.** The MCP drives the one Blender open on the machine; one session
  models at a time.
- **Show it.** A `.blend` cannot be diffed, so a model PR carries renders: `look` shots
  from the front, the side and three-quarters, and an in-game capture.
- **Imports are CC0 or licensed**, the source and licence noted in the model's folder;
  `generate_3d` spends the user's credits and needs their go-ahead.

Two known leaks, to retire rather than copy: `IcebergPlanner` takes a berg's radius and
blade from its model's bounds (presentation only — the D7 hit never reads it), and
`ShipBake` accepts a whole ship as a `.glb`. No check yet holds a `.glb` inside its
declared envelope.

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
| `bitts` | `MooringGear`, a pair by either side of the open deck at each end of her | furniture | 388 |
| `rope_coil` | `MooringGear`, a coil of mooring line beside each pair of bitts | furniture | 376 |
| `stowed_crate_80`, `stowed_crate_70`, `stowed_crate_62` | `CargoHold.crate`, a tween deck's stowed crates, the largest that fits (`STOWED_CRATES`), and `FurnitureDressing.stores`, a working space's stacks | furniture | 278 each |
| `crosstree_15`, `crosstree_20`, `crosstree_60` | `DeckWorks.mast`, near each mast's head, the largest no bigger than the mast (`CROSSTREES`) | hero | 660, 660, 740 |
| `masthead_light` | `DeckWorks.mast`, the steaming light on each mast's fore side | hero | 890 |
| `mast_cleat` | `DeckWorks.mast`, either side of each mast over its foot | furniture | 198 |
| `whistle_90`, `whistle_330` | `DeckWorks.funnel`, on each funnel's fore face, the size made for it (`FUNNEL_FITTINGS`) | hero | 1228 each |
| `waste_pipe_head_90`, `waste_pipe_head_330` | `DeckWorks.funnel`, the waste pipe's head over each funnel's top, the size made for it | furniture | 354 each |
| `pipe_clamp_90`, `pipe_clamp_330` | `DeckWorks.funnel`, up each funnel's pipes, `CLAMP_SPACING` times its scale apart, the size made for it | wall decor | 130 each |
| `sconce_tulip` | `LinerPublic._sconce_on` and `LinerCorridor._sconce` (`RoomDressing.SCONCE_MODEL`) | wall decor | 80 |
| `sconce_globe` | `LinerDining._sconce`, the first-class dining saloon's | wall decor | 84 |
| `clock` | `LinerPublic._clock`, `LinerDining._clock`, `LinerService._clock`, `LinerBath._clock` (`RoomDressing.CLOCK_MODEL`) | wall decor | 118 |
| `capital_32`, `capital_38` | `LinerPublic._pilaster` and `LinerDining._pilaster`, by width (`RoomDressing.CAPITALS`) | wall decor | 72, 72 |
| `pilaster_base` | `LinerPublic._pilaster` | wall decor | 32 |
| `stateroom_door` | `LinerCorridor._stateroom_door`, every `DOOR_SPACING` down a first-class corridor | wall decor | 97 |
| `hanging_basket` | `LinerPublic._basket`, the verandah café's | furniture | 140 |
| `copper_pan_120`, `copper_pan_75` | `LinerService._pan_rack`, a galley's rack, by the room under its bar (`PANS`) | furniture | 70 each |
| `stockpot` | `LinerService._pan_rack`, a galley's rack | furniture | 140 |
| `ladle_35`, `ladle_22` | `LinerService._pan_rack`, a galley's rack, by the room under its bar (`LADLES`) | furniture | 80 each |
| `dresser_180`, `dresser_140` | `LinerService._dresser`, by the width of its wall's stretch (`DRESSERS`) | furniture | 340, 292 |
| `wall_bars` | `LinerService._wall_bars`, a gymnasium's wall, bay by bay | furniture | 268 |
| `mail_sack` | `LinerService._mail_sacks`, a post office's longest wall | furniture | 210 |
| `plaque` | `LinerService._plaque`, a gymnasium's wall | furniture | 58 |
| `notice_board` | `LinerService._notice_board`, a gymnasium's and an office's wall | furniture | 212 |
| `bath_lantern` | `LinerBath._lantern`, round each pendant of the Turkish bath | furniture | 376 |
| `pool_ladder` | `LinerBath.pool`, over the swimming bath's rim at its aft end | furniture | 368 |
| `electrolier` | `LinerDining._chandelier`, round each pendant of the first-class dining saloon | hero | 282 |
| `sideboard_180`, `sideboard_64` | `LinerDining._sideboard` and `CabinDressing._sideboard`, by length (`CabinDressing.SIDEBOARDS`) | furniture | 288, 304 |
| `dining_chair` | `LinerDining.laid_table`, one under each edge of a laid table | wall decor | 57 |
| `serving_hatch` | `LinerDining._hatch`, a plain dining saloon's wall nearest the galley | furniture | 120 |
| `stowed_boat` | `DeckFurniture.boat`, a boat stowed on chocks at each of her boat stations | hero | 1350 |
| `boat_davit` | `DeckFurniture.boat`, a Welin davit at either end of each boat stowed on chocks | furniture | 350 |
| `cowl_vent_45`, `cowl_vent_30` | `DeckFurniture.vent`, a ventilator by its trunk's radius (`VENTS`) | hero | 848 each |
| `mushroom_vent` | `DeckFurniture.vent`, a ventilator a hop up (`VENTS`) | furniture | 276 |
| `deck_bench` | `DeckFurniture.bench`, a short box seat on an open deck | furniture | 238 |
| `armchair` | `FurnitureDressing.seat`, a room's seat no larger either way than `ARMCHAIR_SIDE` | furniture | 376 |
| `settee` | `FurnitureDressing.seat`, a room's seat `SETTEE_DEPTH` deep or deeper | hero | 476 |
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
  - `bitts`: on the deck under the middle of its base plate, its two posts along x;
    its box over all is `MooringGear.BITTS_BOX`, under a step (`step_height`), where
    bodies walk. Painted `dark`, so uninked.
  - `rope_coil`: on the deck under the middle of its turns, its end led off toward +x,
    which `MooringGear` turns toward the bitts; its box is `MooringGear.COIL_BOX`, under
    a step. Painted `rope` and round all over, so uninked. Both are modelled in Blender,
    with no build script: the `.blend` is the source.
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
  - `sconce_tulip`, `sconce_globe`: on the wall's face at the back plate's middle, x
    along the wall, z out of it. The tulip stands no further out than
    `RoomDressing.SCONCE_REACH` nor over `SCONCE_RISE`, its glass painted
    `sconce_glass` (a corridor swaps it for its own glow); the globe is
    `LinerDining.SCONCE_GLOBE` round, its middle `SCONCE_OUT` out and `SCONCE_LIFT` up.
  - `clock`: on the wall's face behind the dial's middle, facing +z, placed with
    `RoomDressing.facing()` so it never reads mirrored; its bezel
    `RoomDressing.CLOCK_RADIUS` round, `CLOCK_DEPTH` out.
  - `capital_NN`: on the wall's face at its top's middle, under the ceiling, hanging
    down; NN hundredths of a metre wide, one of `RoomDressing.CAPITALS`, picked by
    `variant()`: `LinerPublic.CAPITAL`'s and `LinerDining.CAPITAL`'s. The shaft under
    it is the placing code's, sized to its wall. Painted `white`, swapped for the
    room's wood or the saloon's gilt. The two widths share `tools/capital.py`.
  - `pilaster_base`: on the floor at the wall's face under its middle,
    `LinerPublic.PILASTER_BASE` over all; painted `white`, swapped as the capital is.
  - `stateroom_door`: on the floor at the wall's face under the door's middle;
    `LinerCorridor.DOOR` in its `ARCHITRAVE`, `DOOR_DEPTH` out, its knob `DOOR_KNOB`
    past that.
  - `hanging_basket`: at its hook under the ceiling, the basket `LinerPublic.BASKET`
    round hanging `BASKET_DROP` to its rim and `BASKET_DEPTH` more to its foot, its
    leaves no more than `BASKET_SPREAD` round. Its wicker is painted `rope` and its
    leaves `canvas`, swapped for the café's `WICKER` and `FOLIAGE`.
  - `copper_pan_NNN`, `stockpot`, `ladle_NN`: on the galley rack's bar's axis at its
    underside, where each hangs from, x along the wall, z out of it. A pan is made for
    a radius NNN thousandths of a metre, one of `LinerService.PANS`, its rim's top
    `PAN_HANDLE` under the bar and its foot two radii under that; a ladle hangs NN
    hundredths of a metre to its bowl's foot, one of `LADLES`; `RoomDressing.variant()`
    picks the largest no bigger than the room under the bar, and none hangs where even
    the least is too big. The stockpot's box is `STOCKPOT`. The pans share
    `tools/copper_pan.py`, the ladles `tools/ladle.py`.
  - `dresser_NNN`: on the floor at the wall's face under its middle, x along the wall,
    z out of it; NNN hundredths of a metre wide, one of `LinerService.DRESSERS`, from
    `DRESSER.x` to `DRESSER.y` over the floor and no deeper than `FLAT`; `variant()`
    picks the widest the stretch allows. The two share `tools/dresser.py`.
  - `wall_bars`: one bay, on the floor at the wall's face under its middle, placed
    once a bay; its box is `LinerService.WALL_BARS`, no deeper than `BARS`.
  - `mail_sack`: on the wall's face under its hook at `RoomDressing.HEADROOM`, nothing
    under it, turned by `RoomDressing.facing()` so its lettering is never mirrored; its
    box is `LinerService.MAIL_SACK`.
  - `plaque`, `notice_board`: on the wall's face at the fitting's middle,
    `LinerService.PLAQUE_HEIGHT` and `NOTICE_HEIGHT` over the floor, facing +z; their
    boxes are `PLAQUE` and `NOTICE_BOARD`, flat to the wall.
  - `bath_lantern`: where the Turkish bath's pendant hangs under the ceiling, nothing
    of it over that; its band about the globe `LinerBath.LANTERN` round, its foot
    `LANTERN_DROP` under the globe's middle; its box is `LANTERN_BOX`.
  - `pool_ladder`: on the pool's rim's top over its inner edge at the middle of its
    aft end, x out over the water; its handles `LinerBath.LADDER_SPAN` apart rise out
    of the water `HANDLE_BAR` in, bend over `HANDLE` over the rim and come down onto it
    `HANDLE_BACK` back; its box is `LADDER`.
  - `electrolier`: where the first-class dining saloon's pendant hangs from under the
    ceiling, y up; nothing of it over that. Its corona is `LinerDining.HOOP` round, its
    gilt's underside `HOOP_DROP` under the origin, at the pendant's globe's height, and
    its drops hang no more than `ELECTROLIER_DEPTH` under it. Its gilt and its shades'
    `sconce_glass` are swapped for the saloon's.
  - `sideboard_NNN`: on the floor at the wall's face under its middle, x along the wall,
    z out of it, placed with `Wall.place()`; its top NNN hundredths of a metre long, one
    of `CabinDressing.SIDEBOARDS`, picked by `variant()`. The dining saloon's is
    `LinerDining.SIDEBOARD` long, deep and tall, its gallery `SIDEBOARD_GALLERY` over
    its top; the saloon's fills `CabinDressing.SIDEBOARD`. No deeper than a wall
    fitting. The two lengths share `tools/sideboard.py`.
  - `dining_chair`: on the floor at the middle of a laid table box's side, x along it, z
    out of the table; all of it inside the box, its back's face `ShipMesh.SLIVER` in,
    `LinerDining.CHAIR` wide, its crest `CHAIR_HEIGHT` up, `CHAIR_UNDER` under the
    table's top, its front legs `CHAIR_DEPTH` in. What the cloth hides is not drawn.
  - `serving_hatch`: on the wall's face at the opening's middle, `LinerDining.HATCH_HEIGHT`
    over the floor, x along the wall, z out of it; the opening `HATCH` each way, its
    architrave `HATCH_RIM` round it, its shelf `HATCH_SILL` thick and out under that,
    its brackets `HATCH_BRACKET` under the shelf. Its shutters are painted `teak`,
    swapped for the saloon's shutter paint.
  - `stowed_boat`: on the deck under the middle of its keel, x along it; its box over all
    `DeckFurniture.STOWED_BOAT` long over its stems and tall to its stem heads,
    `BOAT_BEAM` across, its keel on two chocks. Its blocker is the box from the deck's
    edge in (`STOWED_BOAT.z`), the boat `BOAT_OFF` in from the edge. A boat curves away
    from a box's corners, so art-lint holds its stem heads, its stems, its gunwale on
    the inboard side and its davits' feet to the box (`_boat_probes`), not every face.
  - `boat_davit`: on the deck at the deck's edge under the davit's middle, x along the
    edge, z in from it; its frame in the `BOAT_OFF` the boat leaves, its arm leaning in
    over the boat to its head at `DAVIT_HEAD`, its fall down to the boat's cover; its box
    `DAVIT_BOX`, inside the boat's. `DeckFurniture.boat` stands one `DAVIT_IN` in from
    each end of the box.
  - `cowl_vent_NN`, `mushroom_vent`: on the deck at the trunk's axis, a cowl's mouth
    forward (+x); made for a trunk NN hundredths of a metre round, one of
    `DeckFurniture.VENTS`, and as tall over its axis as `VENT_HEIGHTS` gives, the
    blocker's height. Under `HEAD_ROOM` nothing of it stands outside the trunk's
    footprint; over it a cowl reaches no more than `COWL_REACH` past it. A cowl is
    painted `buff` outside and `red_lead` inside.
  - `deck_bench`: on the deck under the middle of its box, x along it, z out of its
    front; `DeckFurniture.BENCH` long, tall to its seat and deep, solid under its seat,
    its back `BENCH_RISE` and its arms `ARM_RISE` over the seat, under a step.
    `DeckFurniture.bench` turns its back to whatever stands behind it (`back_of`).
  - `armchair`, `settee`: on the floor under the middle of the seat's box, x along it, z
    out of its front; `FurnitureDressing.ARMCHAIR` and `SETTEE` long, tall to the seat
    and deep, solid to the seat on short feet, the arms `ARM_RISE` and the back
    `BACK_RISE` over the seat, under a step, where a body standing on it has its feet.
    The body is painted `upholstery`, the cushions `linen` and the feet and rail `teak`,
    each swapped for its room's (`FurnitureDressing._coverings`): leather in the smoking
    room, wicker under cushions in the café and the reception room, velvet elsewhere.
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
  (linear: ice over the sea, under-ice under it). The scene's `colour_layer` names
  it, so `tools/export_model.py` exports it as the vertex colour the shader reads, in
  place of `ink`. The shader lays the snow, the strata and the sea's wash over it;
- shaded smooth, as weathered ice is, but sharp across its ledges and fractures,
  wherever two faces meet at more than `SHARP_ANGLE`. The planner keeps the model's
  normals, but for the faces it draws out to the blade, which it lays flat.

## Building by script

A model may be built by a script instead of by hand: `assets/models/NAME/NAME.py`,
run by headless Blender, writes `NAME.blend` from nothing. Its points are given in
Godot's axes and its paints, ink and sharp edges set as above; the shared helpers
(`Part`, the paints' preview colours, the axis swap, and the turned, boxed and swept
shapes `lathe`, `tube`, `cap`, `torus`, `sphere`, `box`, `turned_box`, `slab`, `panel`,
`sweep` and `stud`) are in `tools/model_kit.py`.
Every model but the mooring gear's is built so; the pilots' scripts rebuild `.blend`s
whose export is byte for byte the committed `.glb`. The mooring gear (`bitts`,
`rope_coil`) was modelled in Blender through its MCP, and its `.blend`s are its source.

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
planner and its shader read (a colour on every face, smooth normals facing out of
every face, the waterline, its spur), and every model to its row's box and its
class's budget. A model folder with no row
fails, and so does a row with no folder: a new model lands with its row.

## Licence

Every model is original work for this project, listed in `assets/LICENSES.md`.
