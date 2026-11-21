# The Titanic as she sailed in 1912

What the real-Titanic program (#360, closed 2026-11-08) decided and learned that the code, `git log` and the issues do not say on their own. Read it before layout, flooding or art work on `titanic`. How to trace a plate is in `tools/titanic_plates/README.md`; the plan, slices and calibration findings are in #360.

## The owner's rulings

These are settled. Do not ask them again.

- 2026-10-27, the program: today's ship is kept as `small_titanic`, and `titanic` is rebuilt at 1:1 from the plates.
- 2026-10-27, the program: every cabin is enterable and everything is at true size.
- 2026-10-27, the program: she is the ship that sailed in April 1912, the plates plus the 1912 changes, those parts marked est.
- 2026-10-28, the sisters: the Britannic with her ports open going in 40–80 min is a pending note with the measured number, not an assertion.
- 2026-11-01, flooding fixes (#392, #394): a solver fix merges even when it breaks a story; the story becomes pending with its measured number and its goldens are re-recorded.
- 2026-11-01, the steamer's stories (#394): `fwd_pocket` is pinned to seed 85, `heavy_list` to seed 130, and "lights out early" became `dark_and_afloat`, because no seed makes a steamer go dark and then sink.
- 2026-11-01, the low hull (#395): her hull below F deck is re-fitted to the plates.
- 2026-11-01, the low hull (#396): her pivot band is 176–182 m, and the 2.0 m reading height of the orlop and G deck plans stands, marked est.
- 2026-11-01, the lower decks: the plates are the default truth for bulkheads B and M stepping, the orlop's sheer, the watertight doors in the bunker faces and D's two hinged doors; bring the flooding numbers to the owner.
- 2026-11-02, the tank top (#398): the firemen's passage stays where the plate draws it; the inquiry's 3 1/2 ft is read as its wider forward end.
- 2026-11-02, the night (#398): her holes stay 9 ft², so the slit's width follows whatever the layout does to its length.
- 2026-11-03, flooding (#402): "Find why first". A missed band gets a physical cause, never a tuned number.
- 2026-11-03, the forward decks (#407): they are laid with the plates' sheer.
- 2026-11-03, the forward hatches: the D-deck covers of Nos. 1 and 2 and the bunker hatch, and No. 1's C-deck trunk, go in as drawn, giving way at 1 m (est., no source).
- 2026-11-03, the night: "the late acceleration" stays pending while the break's trim misses 8–23°.
- 2026-11-03, the stern (#408): bulkheads J and K give way at the break, as weak-spot data naming the walls it wrecks (est.; `WRECKS` in `tools/gen_titanic.py`, `WeakSpot.wrecks`).
- 2026-11-03, the stern's roll (#409): water crossing a wide cell shifts a quarter as far, as a per-cell data field (est.; `WIDE_SIDEWAYS`, `FloodCell.sideways`).
- 2026-11-03, her lights (#409): the mains stop when a piece keeps no dry boiler room (est. 1 m; `boiler_cells`, `ShipPower`).
- 2026-11-04, the night: the late port list of 5–15° stays pending. It was a loll at the band's edge, and no physically argued scope brings it back with the stern upright.
- 2026-11-05, the forecastle (#348): its step runs hull-wide and stands forward, clear of Plate IV's after capstans (est. step).
- 2026-11-05, the art (#357): a roofed floor inside her outline reads indoors only below C deck. Every A, B and C promenade stays weather. Art only.
- 2026-11-05, the docking bridge: it has an est. port ladder mirroring the starboard one, so the perch has two routes.
- 2026-11-06, her taper (#492): finer hull sections where she tapers, rooms as drawn, the flooding change accepted and reported, not tuned.
- 2026-11-06, movement (#479): an airborne body gets no step allowance, so runners still fall into holes.
- 2026-11-06, the forecastle head: its hull is widened to Plate IV.
- 2026-11-06, the foremast: it takes Plate IV's size, 0.375 m radius.
- 2026-11-06, benches: optional benches are laid only where a plate draws them. Plates III and IV and the 1912 B deck plan draw none, so none are laid.
- 2026-11-06, bonuses: bonus range scales with the ship's size.

## Decided under the owner's standing word

On 2026-11-06 the owner said to decide and report rather than ask. These calls were made on that word and stand until the owner says otherwise.

- Drawn beats est.: where a plate draws a thing, its reading replaces the estimate.
- Plate against the inquiry: where the inquiry places a 1912 difference (a compartment and its counts), lay est. rooms that match it, as G deck's 26 rooms for 106 and 7 rooms for 34. Where it gives only an unplaced total, the plate stands, as C deck's 135 staterooms against the inquiry's 148.
- Hatch trunks: walls drawn round a hatch mean an enclosed trunk; a bare hatch means an open hatchway at full area, since 'tween hatch boards are not watertight.
- No. 2's and the bunker hatch's trunks stay unlaid on main and the night's hard checks stay hard. Laid, they cut hold 2 off from its 'tween and put the forecastle and the break about 20 min late. Draft PR #512 is the reference, and it waits for a sourced way into hold 2's 'tween.
- Leakage through casings, partitions and doors comes from cited physical sizes, never fitted to a band (`tools/titanic_leakage.py`). The generator fails on an untight face it cannot justify.
- The four hatch covers below the weather deck float off at a 3 in head from below (est. by buoyancy, `HATCH_BOARDS`) and hold from above to 1 m.
- Tunnels through the cross bunkers get their own cells and `*_face` walls. A stepped bulkhead's second stretch is a `*_step` wall. The bulkhead counts in `test_titanic_static` skip both.
- One boiler gap per boiler room opens to 0.9 m so the aisles join for a body.
- E deck's passage aft of O is widened to the generator's passage minimum; the plate draws 0.83 m, and a solid there would seal three cabins.
- The mainmast keeps its est. 0.6 m radius: Plates III and IV disagree on it deck by deck.
- Crane jibs are stowed low on a crutch post, pointing as Plate III draws, with no chain troughs.
- Deck gear's form is composed from part blockers; the models only dress it.
- Ten doorways no body passes are accepted on her (crossed on a flight, or with a way round), the cooks' quarters' among them: `STEEPEST` is not bent for one door.
- Cabins are furnished by rule from the room's name (`tools/titanic_cabins.py`), not traced per cabin. Plate IV's cabins carry a digit and no drawn berths, so placement is est. The owner was told and has not ruled.

## Standing constraints and gotchas

Layout:

- Traced numbers sit on a 1/16 m grain, so a deck and its cell's dry water meet exactly in single precision.
- Bulkhead spans follow the decks: `covered()` gives a bulkhead the widest deck at or above its top. When a deck's breadth changes, diff the walls as well as the rooms.
- `BULKHEADS` holds one x per bulkhead. Plate III steps M forward below F deck and B aft from E down to G; those steps are laid as `*_step` walls.
- Never peg a view on the mainmast's ring: it does not stack between Plates III and IV. Read after ends on Plate III's elevation.
- A ladder between decks is a stair a body climbs. `STEEPEST` is `step_height / body_radius` (0.875); traced flights sit at about 0.86, so leave a margin.
- A deck lifted alone makes its flights too steep. Lift the neighbouring decks with it or run the flights on.
- A door needs 0.8 m of floor past its middle in each room, or the room seals. `test_ship_layout_lint.gd` holds every room to a clear width of two body radii, every flight to being walked end to end, and every room to a doorway a body passes both ways.
- The deck files' own switches for what a body forces are `NUDGES`, `OPENED`, `GONE`, `NOT_ROOMS`, `MADE_SOLID`, `WALLED_SOLIDS` and `AWAIT`, read by `tools/titanic_plates/deck.py`.
- A room's name picks its dressing by the first entry of `RoomDressing.NAMED` it contains, so "restaurant manager" would be dressed as the restaurant. Check `RoomDressing.kind_of` for every new name.
- A change in the room count moves `PINNED` in `test_titanic_cabins.gd` and the bonus-spot counts.
- A room's area feeds the walk graph's zones, the dressing, the wet decks, the HUD and the bonus spots. Compare routes from rest on main and on the branch.
- Below F deck a deck plan's side is not at floor level: the tank top's plan is true 3.75 m over its floor (measured, The Shipbuilder's Fig. 22) and the orlop's and G's 2.0 m (est.). Her floors there are narrower than the plan, by up to about 2 m at the tank top.
- `PASSAGE_Z` is left unpinned on purpose: pinned, the night's hit misses the firemen's passage.
- Her hull sections are cut at `SECTION_TOLERANCE` 0.05 m. 0.1 m and 0.2 m also leave no room past its section, with fewer sections, if their cost ever bites.
- Two branches that regenerate `data/ships/titanic.tres` conflict. Merge main, then regenerate (`make ship SHIP=titanic`, `make ship-scene`, `make bake-check`); never resolve the `.tres` by hand.
- `scenes/art/room_dressing.gd`, `scenes/art/inner_water.gd`, `core/sinking/sink_stepper.gd` and `ai/walk_graph.gd` stand at or a few lines under gdlint's 1100-line cap. Split before adding, and update the branch before merging: two green PRs on one capped file break main together.

Flooding:

- The sisters sit on tipping points. A 5 cm change in a bulkhead's span has flipped both their outcomes while her own notes held to the second.
- She founders at a fixed 22–26 thousand long tons aboard whatever the hole. The night's 16,000 long tons at T+40 cannot be met at any 9–15 ft².
- Her girder gives at boiler rooms 1–2 as her bow plunges. A few hundredths of a m² of hole moves the break's trim across 8°.
- Her stern's upper decks are single cells about 28 m wide. Without the quarter sideways shift the stern is statically unstable at 14–30° of trim and capsizes; no crossing lag alone stops it.
- With the stern upright, lights-out comes from the boiler rooms, not from the roll or the generators' own flooding.
- The night's gash stands 10 ft over her keel, below every 'tween: water reaches the 'tweens over holds 2–3 only by hatchways and flights.
- Read which walls and doors failed from the piece's `state.opened`, not from the bake's events.
- Report the night's and the sisters' numbers from CI's `[Pending]` lines on the PR head (`gh run view RUN --log | grep Pending`), not from an earlier run. Linux CI and a Windows box print the same notes for the same data.
- `body_give` 0.06 m in `data/rules/brawl.tres` is forced by her 0.75 m flights.

Flagged to the owner, never ruled, and not re-measured since her taper was re-sectioned:

- Her counter's flare widens A and B decks aft by up to 0.35 m, and F's flare widens her hull aft between her load waterline and F, against "her hull stays hers".
- The render cost of her lit lamps (a light pass per mesh in the Compatibility renderer) is the one lamp lever left, and it is a look change.

## Still open

- #503: the night's remaining misses, all pending notes: water at T+40, the break's trim (7.1° against 8–23°), 8–12° at 2:35, the late acceleration, the late port list, the Olympic foundering, and the Britannic with ports open in 40–80 min.
- #512 (draft PR): No. 2's and the bunker hatch's trunks as drawn. Nos. 4–6 trunks aft are est. as well. See the ruling above before touching either.
- #411: her launch-to-match time.
- #640: the freeze of about 2.3 s as her match begins.
- #563: her frame time after #410 (render CPU, local wire, transform flush, inner water).
- #678: `make sim-bench` cannot bench her whole match.

## Where the sources are

- `tools/titanic_plates/plates.tsv`: every plate's Internet Archive leaf and SHA-256. The scans are public domain, fetched by `kit.py fetch` into a cache outside the repo, never committed.
- Plates III, IV and V of *The Shipbuilder*'s special number (June 1911): the elevation and every deck from the boat deck to the tank top. Plate V also draws the orlop, the lower orlop and the tank top.
- Plates VI–VIII of the same number: boiler rooms 1 and 2 and the engine rooms.
- The same number's Figs. 22, 25, 44, 54 and 68: hull sections. Fig. 22 is dimensioned amidships; Fig. 44's fore section corrected her bilge forward; its aft section cannot be placed.
- *The Shipbuilder* vol. VI (1911–12), "The White Star Liner Titanic", Fig. 2: her 1912 B deck room by room. It draws no plan of C deck. Check that volume for 1912 changes on any deck.
- The 1912 British inquiry's report ("BOT" in comments): deck heights, compartments and berth counts.
- `tools/titanic_plates/`: one data file per deck in the plate's own pixels, `deck.py` to turn it into ship metres, `deck_check.py` (in `make guard-check`), and `kit.py` to look, propose rooms and draw overlays.
- `tools/gen_titanic.py`: lays `data/ships/titanic.tres` from the deck files, with her hull, bulkheads, cells, openings and hits.
- `tools/titanic_cabins.py`: the cabins' berths by rule; berths are sim blockers.
- `tools/titanic_leakage.py`: seam and door-gap areas from cited sizes.
- `tools/gen_small_titanic.py`: the old ship, frozen. Tests of art or sim code that do not need her true layout build `small_titanic`.
- `tests/unit/core/test_titanic_night.gd`, `test_titanic_static.gd`, `test_titanic_olympic.gd`, `test_titanic_britannic.gd`: her night, her statics and the sisters, which ride on her hull.
