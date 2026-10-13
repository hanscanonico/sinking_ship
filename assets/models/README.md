# Modelled props

A prop modelled in Blender instead of built from boxes in GDScript. Each lives in its
own folder, `assets/models/NAME/`: the source `NAME.blend`, the `NAME.glb` exported
from it, and the `.glb.import` Godot writes for it. The `.blend` is the source; the
`.glb` is what the game loads. Godot never imports a `.blend` (`project.godot`
turns its Blender importer off), so a checkout without Blender imports cleanly.

A modelled prop is drawn like any procedural piece of the dressed ship. `ShipModel`
gathers the `.glb`'s meshes into one, and `ShipMesh.model()` adds its triangles to
the ship's batches: painted in the ship's paints, inked at its rims, judged indoors
or out, chunked under the lamp limit, cut by the observer's cut-away, and skipped
when it is wholly off the stretch being drawn. It never becomes a mesh instance of
its own. Where it stands is still decided by the data and the fitting code (D6). The
model is only its shape.

| Prop | Placed by | Triangles |
|---|---|---|
| `lifeboat` | `ShipFittings._lifeboats`, hung in the `Lifeboat` node | 2928 |
| `davit` | `ShipFittings._davit`, two per boat | 556 |

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

## Exporting

    make models                     # every NAME.blend to its NAME.glb, Blender headless
    make import                     # Godot reimports the changed .glb

`tools/export_model.py` refuses a mesh with no material or no `ink` layer. Neither
`make verify` nor CI runs Blender, and nothing checks that a `.glb` is up to date with
its `.blend`: export after every change and commit both. The contract test
(`tests/unit/art/test_committed_models.gd`) holds every committed `.glb` to its paints
and its ink, and the lifeboat's and davit's boxes to `ShipFittings`' constants within
2 cm.

## Licence

Both models are original work for this project, listed in `assets/LICENSES.md`.
