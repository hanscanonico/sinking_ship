# Tracing the Titanic's plates

The real Titanic (#360) is laid out room by room from the general arrangement plates of
*The Shipbuilder*, June 1911 — Plates III, IV and V, every deck from the boat deck to the
tank top, cabin by cabin (public domain; `plates.tsv` names each leaf and its SHA-256).
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

Plate IV's C deck view (`c.py`) stretches unevenly along her: aft of the second-class lift
it draws about 6% longer than forward of it, and aft of the mainmast 6% shorter again, so
it is calibrated piecewise on the mast, the lifts and the casings A and B decks give, and on
her stern at `X_AFT`; her stem then reads within 0.03 m of the generator's. Its side lines
in her forward body are C deck's own; the dashed line inside them is D deck's side.

What the calibration has shown so far (#360's findings): today's `FUNNELS` stand 2.5–4.4 m
aft of the elevation's funnel bases; the plates put the squash court and the mail room in
No. 3 hold; Plate IV's E deck view's bow does not fit its aft bulkheads' scale; the plan's
lifeboats are spaced ~8% wider than the elevation's davits.

Plate IV's D deck view (`d.py`) is calibrated on its two lift wells and her ends: it is
1.7% longer forward of the lifts than aft of them. The walls standing over bulkheads K–P
come out within 0.3 m of `BULKHEADS`, but its funnel casings are drawn larger than A
deck's, their middles up to 1 m off, so they are no control there.
