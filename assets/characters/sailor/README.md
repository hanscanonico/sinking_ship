# The sailor

Every brawler is this one figure: an original rig, body and set of clips, built in
Blender from `gen_sailor.py` and nothing else, and dressed there in one of three
outfits; its hats are built round its head by `gen_hats.py`. `sailor.blend` and
`hats.blend` are what the scripts save, `sailor.glb` and `hats.glb` what they export
and the game loads (`Brawler.MODEL`, `Brawler.HAT_MODELS`), and the `.glb.import`
files are Godot's.

    make sailor        # Blender headless: gen_sailor.py -> sailor.blend, sailor.glb
                       #                   gen_hats.py   -> hats.blend, hats.glb
    make import        # Godot reimports the .glb files

Neither `make verify` nor CI runs Blender: regenerate after every change to the
script and commit the .blend and the .glb.

## What the game expects

- **Frame and size.** Godot's model frame: +y up, +z ahead, +x the body's left; the
  soles at 0 and the crown at 1.83 model units. `Brawler` scales it to the rules'
  body height. The clothes shader (`scenes/art/brawler.gdshader`) paints jersey,
  coat, face and boots from where each point sits at rest, by height and distance
  from the middle, so the body keeps the landmarks it reads: the wrists at 0.735
  across, the arms held out level above 1.25, the neck between 1.47 and 1.54. The
  generator writes where each point sits at rest into its UVs — `rest` (x, y) and
  `depth` (z, and what the point is: `PART_` in the shader, the body or a piece of
  clothing), each v written as 1 − v for glTF — so the game reads them as they are.
- **Rest pose.** Arms out along x, palms down, thumbs ahead (`BrawlerPose.REST_PALM`).
  Every bone's length runs along its local +y; the head bone's +z faces ahead, as
  the hats (`gen_hats.py`) are built in its space, 0.26 under the crown.
- **Bones.** `root`; `pelvis`, `spine_01`, `spine_02`, `chest`, `neck`, `head`; per
  side (`_l`, `_r`) `clavicle`, `upperarm`, `lowerarm`, `hand`, `fingers`,
  `fingertips`, `thumb`, `thumbtip`, `thigh`, `calf`, `foot`, `toe`. The poses laid
  over the clips (`BrawlerPose`, `BrawlerAnimation.POSES`, `FirstPersonArms.POSES`)
  name them.
- **Body.** One closed surface grown over a stick figure by the skin modifier and
  one round of subdivision, pressed into a brawler's build (`BULGES`: chest,
  shoulders, arms, forearms, jaw, ears) and skinned by Blender's automatic weights,
  smoothed across the wrists. Its proportions are the hats' and the clothes
  shader's: a head about 0.19 wide and 0.23 deep, which every hat fits, on
  a neck about 0.13 wide; shoulders out past the arm band at 0.22. Each hand's four
  fingers and thumb are closed shells of their own set into the palm, weighted by
  hand to `fingers`/`fingertips` and `thumb`/`thumbtip`, so a fist shows its
  knuckles and an open hand its fingers.
- **Outfits.** `Jersey`, `Jacket` and `Greatcoat` (`OUTFITS`, in `Brawler.Coat`'s
  order): each the body dressed and exported as a mesh of its own under the
  skeleton — one surface, one material, at most four bones a point — and a seat
  keeps the one its coat names (`Brawler.OUTFITS`). The cloth bridges the hollows
  between the muscles and hangs straight from the chest (`DRAPE`, `HANG`); a coat's
  skirt hangs from the hips, cloth outside and lining inside, held by the pelvis
  and pulled along by the thighs below; and the pieces are laid over the body by
  casting onto it, weighted as the body is where they lie: a jersey's rolled
  collar, ribbed welt and cuffs and the buckle under them; a reefer jacket's
  lapels, collar, three brass buttons, breast pocket, flapped hip pockets and
  cuffs; a double-breasted greatcoat's broad lapels, high collar, two rows of
  buttons, pocket flaps, turned-back cuffs and half-belt behind. The front within
  0.09 of the middle rides the spine alone (`STEADY_ROWS`), so a raised arm never
  shears a narrow band of it; `make art-lint` checks it. Every colour is the
  shader's, the coat the seat's. Each outfit's triangle budget is pinned in
  `tests/unit/art/test_sailor.gd`.
- **Own arms.** `JerseyArms`, `JacketArms` and `GreatcoatArms` (`Brawler.ARMS`), each
  outfit's arms modelled again under the same skeleton for the seat that looks out
  over them (`FirstPersonArms`), finer than a body drawn eight times over can afford:
  the sleeve from above the elbow, fuller than the arm and bridging the elbow; the
  outfit's own cuff — a jersey's ribbed one, a jacket's with three brass buttons, a
  greatcoat's deep turned-back one with two — with an open mouth and its lining; a
  coat's shirt cuff under it, showing a little past it and ending short of the
  wrist's joint, the lining closed round it a little way in so the eye never sees
  down the sleeve; the wrist coming out of it; a palm with its heel and
  the ball of its thumb; and fingers and a thumb of ten sides, their knuckles proud
  on the back, their joints creased and their nails flat. Each point sits where the
  arm's does at rest, so the clothes shader paints sleeve, cuff and skin in the
  seat's colour. Where a finger or the thumb is set into the palm, and in the web
  between the thumb and the index finger, the outline is left off (`WEB_*`), so a
  fist shows no slivers of ink in its creases. Every body drops them; a seat's own arms draw its coat's in place
  of its body. Each one's triangles are pinned in `tests/unit/art/test_sailor.gd`,
  at most 4,000.
- **Hats.** `Cap`, `Souwester`, `Boater`, `Bare`, `Bobble`, `Top` and `Peaked`
  (`Brawler.HAT_MESHES`, in `Brawler.Hat`'s order), each one small rigid mesh in the
  head bone's space, never skinned: `Brawler` hangs the one its seat wears on the
  head bone, so it rides the head and scales with the body, and `Brawler.headgear()`
  reads its top. A seaman's flat cap with its ribbon, bow, tails and gilt tally; an
  oilskin sou'wester, its brim long down the neck; a straw boater with its ribbon; a
  knitted watch cap with a ribbed cuff and a bobble; a silk topper with its band and
  curled brim; a mate's peaked cap with a leather peak and chin strap and a gilt
  badge; and for a bare head, its hair. Each band is cast round the grown head, a
  little clear of it, and the script stops if any point or face of a hat cuts into
  the head. Parts and ink are written as on the outfits, so the hats wear the same
  clothes shader, the seat's colour and the outline. Each hat's triangles are pinned
  in `tests/unit/art/test_sailor.gd`, at most 300 apiece.
- **Clips.** `idle`, `walk`, `run`, `windup`, `shove`, `stagger`, `fall`, `jump`,
  `brace`, `climb`, `swim` (`BrawlerAnimation.CLIPS`), keyed every frame at 30 fps
  from poses written in the script. A clip that loops is exported as `NAME-loop`,
  which Godot's import reads as looping and names `NAME`. `walk` lasts 1.333 s and
  `run` 0.933 s, as `CuePlanner` counts footfalls; their planted feet slide back at
  the speeds the script prints, which `BrawlerAnimation.WALK_CLIP_SPEED` and
  `RUN_CLIP_SPEED` hold.

## Licence

Original work for this project, listed in `assets/LICENSES.md`.
