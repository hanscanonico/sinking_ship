# Tracing the Titanic's plates

The real Titanic (#360) is laid out room by room from the general arrangement plates of
*The Shipbuilder*, June 1911 — Plates III, IV and V, every deck from the boat deck to the
tank top, cabin by cabin — and where she changed before she sailed, from The Shipbuilder's
1912 plans of her as built (public domain; `plates.tsv` names each leaf and its SHA-256).
Each deck traced from them is a Python data file here (`boat.py`, `a.py`, …), every piece
in the plate's own pixels, read as the plate draws it. `deck.py` turns a deck file into
ship metres for `tools/gen_titanic.py`; it needs nothing beyond Python, so CI runs it.
`deck_check.py` (in `make guard-check`) holds every deck file together. `kit.py` is the
dev tool that helps write them — like `make models`, nothing in `make verify` runs it.

## Setting up the kit

```sh
python3 -m venv ~/.venvs/plates && ~/.venvs/plates/bin/pip install -r tools/titanic_plates/requirements.txt
~/.venvs/plates/bin/python tools/titanic_plates/kit.py fetch      # the plates, into ~/.cache/sinking_ship/plates
```

The scans (11,000 × 5,600 px, about 11.6 px a foot) are fetched into a cache outside the
repo and never committed.

## Tracing a deck

1. **Its view.** Start the deck file with `PLATE` and `CROP`, the view's rectangle on its
   plate. `kit.py look PLATE X0 Y0 X1 Y1 out.png --grid 50` shows any part of a plate
   with its pixels gridded and labelled; read everything off it.
2. **Its calibration.** `X`: two or more features whose ship x is known, each as
   `(plate x, ship x, what)` — read linearly between them (see Calibrating below). `Z`:
   the centre line as drawn at two points, and the view's scale across her, read off her
   breadth in the parallel middle body (92 ft moulded).
3. **Its rooms.** `kit.py rooms DECK --out rooms.png --crop …` proposes every space its
   lines close round, numbered over the view. Copy the drafts into `ROOMS`, name each by
   its plate label, and fix what the draft got wrong: a corridor network comes out as one
   shape, a centre line or a label's underline splits a room, an L-shaped room fills
   half its box. Rooms are rectangles: cut an L into two and join them with `OPEN`.
   A name is also what the art dresses a room by (`RoomDressing.NAMED`,
   `LinerPublic.STYLES`), so a few take the game's own: a grand staircase's landing is
   "grand staircase, A deck" (its chandeliers, the boat deck's dome), a first-class
   cabin corridor "A deck corridor", a stateroom's berths "three-berth …" (a block of
   "berths" is a crew's).
4. **What nobody enters.** Casings, shafts, lifts, closets narrower than a body (W.C.s,
   wardrobes, lockers) go in `SOLIDS`; a raised roof walked on in `RAISED`.
5. **Doors and stairs.** A door stands where the plate draws its swing (`DOORS`). A room
   given none gets one where it meets a passage or corridor (`deck.py`, the plates'
   cabins' habit). Each flight goes in `STAIRS`, from the deck below to the one above.
6. **Check it.** `kit.py overlay DECK out.png` draws the deck file back over its view —
   the walls `deck.py` derives in red (steel thick), its doors green, rooms blue, solids
   grey, stairs gold with a dot at the high end. Compare it with the plate by eye, and
   run `python3 tools/titanic_plates/deck_check.py` until it says nothing.

Edges within 6 px of each other that touch along their length are one wall's two
readings and are snapped together; two readings further apart than that are two walls,
so put a shared wall on one line.

A room's name is also how her cells list it (a cell names the rooms it holds), so a name
belongs to one cell: one another deck's house uses too takes its deck's name after it
("passage, B deck", as "grand staircase, A deck").

## A deck drawn in several views

A deck no one view draws whole is a file naming its parts (`b.py`'s `PARTS`), each a
deck file of its own in its own view's pixels: B deck's after end off Plate IV, and the
rest off the two pages of the 1912 plan, which overlap at the gutter. `deck.py` reads
each part as it reads a deck, then joins them in metres: lines two parts read of one
wall within 0.3 m of each other (`JOIN`) take their mean, each part's whole line with it
— so trace a wall both views draw (where they meet) as one line in each, or `deck.py`
refuses it — and the narrow passages are widened on the joined lines. A part may give
the deck's outline (`DECKS`) alone. `kit.py overlay PART` draws the whole deck's walls
back over the part's view, and `deck_check.py` checks the deck whole.

`deck.load(name, side)` holds the rooms reaching her side to it: `side(x0, x1)` the half
breadth an outer wall's middle takes there, from the generator's strips of her deck.

## Where a body forces a change

Bodies are 0.8 m across (`data/rules/brawl.tres`); the plates' passages and doors were
drawn for people, and their stairs and ladders are steeper than a body climbs. So a
deck file keeps the plate's pixels and says beside a piece what the game changes:

- a flight runs on past the plate's treads to the run `STEEPEST` allows, and stacked
  flights split their footprint (the grand staircase's halves) or switch back;
- a ladder between decks is a stair: `ShipLadder` only lifts a swimmer from the sea;
- a space narrower than a body is a solid, not a room.

## Calibrating

Each plate's scan has its own scale, a little different along her and across her, and
each view on a plate sits a little apart from the others. So every view is calibrated
on its own, piecewise, on features whose ship x is known:

- **Bulkheads**, on the views that draw them (E deck down): their ship x is the
  generator's `BULKHEADS`, traced off Plate III's elevation. The orlop view puts
  bulkheads K–C and the six cross bunkers within 0.1–0.2 m of `BULKHEADS` and `BUNKERS`.
- **Shafts that stack**: the grand staircases and lifts, the casings, the hatches — at
  the ship x the view below or above gives them, so stairs and casings line up from
  deck to deck.
- **Plate III's elevation** for its own plans: the boat deck sits 19 px aft of it, at
  its scale (0.026348 m a pixel): funnels 1–3's casings against the elevation's funnel
  bases, and the bridge's front.

What the calibration has shown so far (#360's findings): today's `FUNNELS` stand 2.5–4.4 m
aft of the elevation's funnel bases; the plates put the squash court and the mail room in
No. 3 hold; Plate IV's E deck view's bow does not fit its aft bulkheads' scale; the plan's
lifeboats are spaced ~8% wider than the elevation's davits.

B deck (#367):

- **Plate IV's B deck view** reads on A deck's shafts: the second-class lift (px 3082) and
  the casings of funnels 3, 2 and 1. Aft of the lift it reads on her after end where
  Plate III's elevation draws it — her superstructure's after face, the after second-class
  entrance's after wall (px 2120; the elevation's px 2200, x -94.40) — as C deck's view
  reads on her stern (#374): there the plate draws 3% larger than forward of the lift, as
  C deck's does between the lift and her stern. Across her, her sides are 1088 px apart
  for 92 ft (0.025773 m a pixel), about the centre line it draws, bowed 4 px over the scan.
  Her deck's forward end there (75.3 m) agrees with Plate III's elevation within 0.4 m.
- **The mainmast's ring** on her centre line, which Plate III's A deck plan (px 2385) and
  Plate IV's B and C deck plans (px 2393, 2405) all draw, does not stack: B deck's reads
  -87.5 and C deck's -87.0 on their after ends, A deck's -88.6 on its lift, and the
  elevation draws the mast's foot at the superstructure's after face (-94.4). Pegged on A
  deck's ring, as B deck first was, B deck's after end stood 1.6 m aft of the
  elevation's, and C deck's poop front 0.8 m. The generator stands the mast on A deck's.
- **The 1912 plan**, The Shipbuilder vol. VI (1911-12), "The White Star Liner Titanic",
  Fig. 2 (pp. 222-223; Internet Archive the_shipbuilder_vol6, leaves n237 and n238, Public
  Domain Mark 1.0): "First-class accommodation on bridge deck B", her B deck from her
  restaurant's after wall to her house's front as she was built — her cabins out to her
  sides, the parlour suites' private promenades, the Café Parisien, the restaurant's
  reception room. It is drawn about 5% larger across her than along (her sides 1331-1340 px
  apart for her 92 ft 6 in extreme), reads on the casings and the lifts, and at its gutter
  on the wall both pages draw (a 240 px overlap; the binding's curl leaves the stretch from
  funnel 3's casing to funnel 2's at one scale, 2.5% larger than the pages' middles).
- Where the two disagree: the plan puts the restaurant's after wall 0.4 m forward of Plate
  IV's, and its second-class stair well 0.6 m shallower. Each deck file says which
  reading it keeps (est.).
- Plate IV's poop and forecastle views: the forecastle's 125 ft (BOT) and its after end
  agree with `FCSL_FROM` within 0.6 m. On B deck's calibration the poop's front stands
  within 0.4 m of the elevation's (px 1740 there, x -106.55, 0.6 m aft of `POOP_TO`, the
  texts' 106 ft), but its view draws the poop a quarter longer than her stern allows, so
  `POOP_TO` stays the texts'.
