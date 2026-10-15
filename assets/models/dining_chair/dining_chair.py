"""Builds assets/models/dining_chair/dining_chair.blend: a dining saloon's chair tucked
under a laid table's edge (LinerDining.laid_table) — two back posts down to the floor
for its back legs, an arched crest rail over them, a vase splat between them, the
back of its leather seat on its rail, and its front legs showing under the cloth's
hem — in Godot's axes, metres: x along the table's edge, y up, z out of the table, its
origin on the floor at the middle of the table box's side. All of it stands inside
the box: its back's face ShipMesh.SLIVER in from the side, LinerDining.CHAIR wide and
deep, its crest LinerDining.CHAIR_HEIGHT over the floor, its front legs no further in
than CHAIR_DEPTH. The seat and the rest of the frame are under the cloth, unseen and
not drawn; nor are the faces against the cloth. A dark chair, uninked.

    make model-sources MODEL=dining_chair
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/dining_chair/dining_chair.py -- \
        assets/models/dining_chair/dining_chair.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, slab, triangles  # noqa: E402

# LinerDining's CHAIR (its back's width and depth), CHAIR_HEIGHT and CHAIR_DEPTH, and
# ShipMesh.SLIVER, how far in from the box's side its back stands.
HALF = 0.22
BACK = 0.03
HEIGHT = 0.72
DEPTH = 0.42
SLIVER = 0.005
# The back's face and its inside, against the cloth.
FACE = -SLIVER
INSIDE = FACE - BACK + 0.001
# The posts' width; the crest rail's foot and its shoulders; the seat's rail and the
# leather over it; the splat's foot, its swell and their half widths; the front legs'
# height (the cloth's hem and a little over) and their width.
POST = 0.035
CREST = 0.635
SHOULDER = 0.685
RAIL = 0.37
SEAT = (0.405, 0.465)
SWELL = 0.55
LEG = 0.16
LEG_WIDE = 0.03

X = [1.0, 0.0, 0.0]
Z = [0.0, 0.0, 1.0]
# The faces a piece of the back leaves off: against the cloth, and its top or its
# underside where a rail meets it.
CLOTH = (2, -1)
TOP = (1, 1)
UNDER = (1, -1)


def posts(wood):
    """The back posts, from the floor to the crest, each its face and its sides."""
    for side in (-1.0, 1.0):
        outer = side * HALF
        inner = side * (HALF - POST)
        low = [min(outer, inner), 0.0, INSIDE]
        high = [max(outer, inner), CREST, FACE]
        box(wood, low, high, inked=False, skip=(CLOTH, TOP, UNDER))


def crest(wood):
    """The crest rail across the posts' heads, its top arched to the middle: its face,
    its top in two pitches, its ends and its underside between the posts."""
    top = [[-HALF, SHOULDER], [0.0, HEIGHT], [HALF, SHOULDER]]
    face = [[-HALF, CREST, FACE], [HALF, CREST, FACE]] + [[x, y, FACE] for x, y in reversed(top)]
    slab(wood, face, Z)
    for (xa, ya), (xb, yb) in zip(top, top[1:]):
        rise = [-(yb - ya), xb - xa, 0.0]
        slab(wood, [[xa, ya, FACE], [xb, yb, FACE], [xb, yb, INSIDE], [xa, ya, INSIDE]], rise)
    for side in (-1.0, 1.0):
        x = side * HALF
        slab(wood, [[x, CREST, FACE], [x, SHOULDER, FACE], [x, SHOULDER, INSIDE], [x, CREST, INSIDE]], [side, 0.0, 0.0])
    inner = HALF - POST
    slab(wood, [[-inner, CREST, FACE], [inner, CREST, FACE], [inner, CREST, INSIDE], [-inner, CREST, INSIDE]], [0.0, -1.0, 0.0])


def splat(wood):
    """The vase splat from the seat up to the crest, set a little back from the
    posts' faces: its face, a swelling hexagon, and its four slanting sides."""
    face = FACE - 0.008
    foot = SEAT[1]
    outline = [[-0.04, foot], [0.04, foot], [0.075, SWELL], [0.045, CREST], [-0.045, CREST], [-0.075, SWELL]]
    slab(wood, [[x, y, face] for x, y in outline], Z)
    for a, b in ((1, 2), (2, 3), (4, 5), (5, 0)):
        (xa, ya), (xb, yb) = outline[a], outline[b]
        out = [yb - ya, -(xb - xa), 0.0]
        slab(wood, [[xa, ya, face], [xb, yb, face], [xb, yb, INSIDE], [xa, ya, INSIDE]], out)


def seat(wood, leather):
    """The seat's back rail between the posts and the leather stuffed over it, its
    face swelling out to the posts' faces and its top."""
    inner = HALF - POST
    slab(wood, [[-inner, RAIL, FACE - 0.006], [inner, RAIL, FACE - 0.006], [inner, SEAT[0], FACE - 0.006], [-inner, SEAT[0], FACE - 0.006]], Z)
    low, high = SEAT
    middle = (low + high) * 0.5
    edge = FACE - 0.01
    rows = [[low, edge], [middle, FACE], [high, edge]]
    for (ya, za), (yb, zb) in zip(rows, rows[1:]):
        out = [0.0, -(zb - za), yb - ya]
        slab(leather, [[-inner, ya, za], [inner, ya, za], [inner, yb, zb], [-inner, yb, zb]], out)
    slab(leather, [[-inner, high, edge], [inner, high, edge], [inner, high, INSIDE], [-inner, high, INSIDE]], [0.0, 1.0, 0.0])


def front_legs(wood):
    """The front legs under the cloth's hem, their sides and their inner faces."""
    for side in (-1.0, 1.0):
        outer = side * (HALF - 0.005)
        inner = side * (HALF - 0.005 - LEG_WIDE)
        low = [min(outer, inner), 0.0, -DEPTH]
        high = [max(outer, inner), LEG, -DEPTH + LEG_WIDE]
        box(wood, low, high, inked=False, skip=((2, 1), TOP, UNDER))


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    wood = Part("frame", "frame")
    leather = Part("upholstery", "upholstery")
    posts(wood)
    crest(wood)
    splat(wood)
    seat(wood, leather)
    front_legs(wood)
    wood.build(collection)
    leather.build(collection)
    print("dining_chair: %d triangles" % triangles(collection))
    save(out)


main()
