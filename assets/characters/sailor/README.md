# The sailor

Every brawler is this one figure: an original rig, body and set of clips, built in
Blender from `gen_sailor.py` and nothing else. `sailor.blend` is what the script
saves, `sailor.glb` what it exports and the game loads (`Brawler.MODEL`), and
`sailor.glb.import` is Godot's.

    make sailor        # Blender headless: gen_sailor.py -> sailor.blend, sailor.glb
    make import        # Godot reimports the .glb

Neither `make verify` nor CI runs Blender: regenerate after every change to the
script and commit the .blend and the .glb.

## What the game expects

- **Frame and size.** Godot's model frame: +y up, +z ahead, +x the body's left; the
  soles at 0 and the crown at 1.83 model units. `Brawler` scales it to the rules'
  body height. The clothes shader (`scenes/art/brawler.gdshader`) paints jersey,
  coat, face and boots from where each point sits at rest, by height and distance
  from the middle, so the body keeps the landmarks it reads: the wrists at 0.735
  across, the arms held out level above 1.25, the neck between 1.47 and 1.54.
- **Rest pose.** Arms out along x, palms down, thumbs ahead (`BrawlerPose.REST_PALM`).
  Every bone's length runs along its local +y; the head bone's +z faces ahead, as
  the hats (`BrawlerHat`) are built in its space, 0.26 under the crown.
- **Bones.** `root`; `pelvis`, `spine_01`, `spine_02`, `chest`, `neck`, `head`; per
  side (`_l`, `_r`) `clavicle`, `upperarm`, `lowerarm`, `hand`, `fingers`,
  `fingertips`, `thumb`, `thumbtip`, `thigh`, `calf`, `foot`, `toe`. The poses laid
  over the clips (`BrawlerPose`, `BrawlerAnimation.POSES`, `FirstPersonArms.POSES`)
  name them.
- **Body.** One mesh, one material, at most four bones a point. The body is one
  closed surface grown over a stick figure by the skin modifier and one round of
  subdivision, pressed into a brawler's build (`BULGES`: chest, shoulders, arms,
  jaw, ears) and skinned by Blender's automatic weights, smoothed across the wrists.
  Its proportions are the hats' and the clothes shader's: a head about 0.18 wide and
  0.23 deep, which every `BrawlerHat` fits, on a neck about 0.13 wide; shoulders out
  past the arm band at 0.22. Each hand's four fingers and thumb are closed shells of
  their own set into the palm, weighted by hand to `fingers`/`fingertips` and
  `thumb`/`thumbtip`, so a fist shows its knuckles and an open hand its fingers.
  `Brawler` dresses it in code: the coats' skirts, the painted front steadied on the
  spine, the outline. Its triangle budget is pinned in
  `tests/unit/art/test_sailor.gd`.
- **Clips.** `idle`, `walk`, `run`, `windup`, `shove`, `stagger`, `fall`, `jump`,
  `brace`, `climb`, `swim` (`BrawlerAnimation.CLIPS`), keyed every frame at 30 fps
  from poses written in the script. A clip that loops is exported as `NAME-loop`,
  which Godot's import reads as looping and names `NAME`. `walk` lasts 1.333 s and
  `run` 0.933 s, as `CuePlanner` counts footfalls; their planted feet slide back at
  the speeds the script prints, which `BrawlerAnimation.WALK_CLIP_SPEED` and
  `RUN_CLIP_SPEED` hold.

## Licence

Original work for this project, listed in `assets/LICENSES.md`.
