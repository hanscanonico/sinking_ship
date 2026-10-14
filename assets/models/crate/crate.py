"""Builds assets/models/crate/crate.blend: a loose cargo crate (ShipArt._crate), in
Godot's axes, metres, the middle of its underside at the origin. Its body is the
square ShipArt draws a crate's circle as, CRATE_SIDE of a 0.45 m radius each way of
its middle, 0.8 m tall (the cargo's ShipProp in tools/gen_steamer.py and
gen_trawler.py): planked sides and lid, battens round its foot and its lid
8 cm tall and ShipArt's CRATE_PROUD proud, a post up each corner between them, a
diagonal brace on two sides and a shipper's stencil on the other two, and a rope
lashed round it both ways over its lid.

    make model-sources MODEL=crate
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/crate/crate.py -- assets/models/crate/crate.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, triangles  # noqa: E402
from model_shapes import block, lathe, sweep  # noqa: E402

HALF = 0.45 * 0.85
HEIGHT = 0.8
BATTEN = 0.08
PROUD = 0.015
SEAM = 0.015
POST = 0.05
ROPE = 0.008
UP = (0.0, 1.0, 0.0)
# Each side's way out, and its way along (to the right, looking at it).
SIDES = [
    ((1.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
    ((0.0, 0.0, 1.0), (1.0, 0.0, 0.0)),
    ((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
    ((0.0, 0.0, -1.0), (-1.0, 0.0, 0.0)),
]


def add(*vectors):
    return [sum(v[i] for v in vectors) for i in range(3)]


def scale(v, s):
    return [c * s for c in v]


def body(collection):
    """The crate's planked body: its sides from the deck to its lid, a seam inked
    between each two planks; its lid's planks across it."""
    part = Part("body", "crate")
    rows = [(0.0, 0.0)]
    for seam in (0.32, 0.48):
        rows += [(seam - SEAM, 0.0), (seam, 1.0), (seam + SEAM, 0.0)]
    rows.append((HEIGHT, 0.0))
    for normal, right in SIDES:
        face = scale(normal, HALF)
        for j in range(len(rows) - 1):
            low, low_ink = rows[j]
            high, high_ink = rows[j + 1]
            quad = [
                add(face, scale(right, -HALF), scale(UP, low)),
                add(face, scale(right, HALF), scale(UP, low)),
                add(face, scale(right, HALF), scale(UP, high)),
                add(face, scale(right, -HALF), scale(UP, high)),
            ]
            part.face([part.point(p) for p in quad], [low_ink, low_ink, high_ink, high_ink], normal)
    across = [(-HALF, 0.0)]
    for seam in (-HALF / 3.0, HALF / 3.0):
        across += [(seam - SEAM, 0.0), (seam, 1.0), (seam + SEAM, 0.0)]
    across.append((HALF, 0.0))
    for j in range(len(across) - 1):
        a, ink_a = across[j]
        b, ink_b = across[j + 1]
        quad = [[-HALF, HEIGHT, a], [HALF, HEIGHT, a], [HALF, HEIGHT, b], [-HALF, HEIGHT, b]]
        part.face([part.point(p) for p in quad], [ink_a, ink_a, ink_b, ink_b], UP)
    return part.build(collection)


def battens(collection):
    """The battens round its foot and its lid, the posts up its corners between them,
    and a brace across each side facing x."""
    part = Part("battens", "frame")
    out = (HALF + PROUD) * math.sqrt(2.0)
    inside = HALF * math.sqrt(2.0)
    lathe(
        part,
        (0.0, 0.0, 0.0),
        UP,
        [
            (out, 0.0, 1.0),
            (out, SEAM, 0.0),
            (out, BATTEN - SEAM, 0.0),
            (out, BATTEN, 1.0),
            (inside, BATTEN, 1.0),
        ],
        4,
        math.pi / 4,
    )
    lathe(
        part,
        (0.0, 0.0, 0.0),
        UP,
        [
            (inside, HEIGHT - BATTEN, 1.0),
            (out, HEIGHT - BATTEN, 1.0),
            (out, HEIGHT - BATTEN + SEAM, 0.0),
            (out, HEIGHT - SEAM, 0.0),
            (out, HEIGHT, 1.0),
            (inside, HEIGHT, 0.0),
        ],
        4,
        math.pi / 4,
    )
    low = BATTEN
    high = HEIGHT - BATTEN
    for cx in (-1.0, 1.0):
        for cz in (-1.0, 1.0):
            corner = HALF + PROUD - POST * 0.5
            middle = [cx * corner, (low + high) * 0.5, cz * corner]
            block(
                part,
                middle,
                ((1.0, 0.0, 0.0), UP, (0.0, 0.0, 1.0)),
                (POST * 0.5, (high - low) * 0.5, POST * 0.5),
                SEAM,
                skip=((1, -1.0), (1, 1.0), (0, -cx), (2, -cz)),
            )
    # A brace from the foot's batten at one post up to the lid's at the other.
    for side in (0, 2):
        normal, right = SIDES[side]
        face = scale(normal, HALF + PROUD * 0.5)
        reach = HALF - POST
        start = add(face, scale(right, -reach), scale(UP, low))
        end = add(face, scale(right, reach), scale(UP, high))
        along = [e - s for s, e in zip(start, end)]
        length = math.sqrt(sum(c * c for c in along))
        along = [c / length for c in along]
        middle = [(s + e) * 0.5 for s, e in zip(start, end)]
        across = [
            normal[1] * along[2] - normal[2] * along[1],
            normal[2] * along[0] - normal[0] * along[2],
            normal[0] * along[1] - normal[1] * along[0],
        ]
        block(
            part,
            middle,
            (along, across, normal),
            (length * 0.5 - 0.03, 0.035, PROUD * 0.5),
            SEAM,
            skip=((2, -1.0), (0, -1.0), (0, 1.0)),
        )
    return part.build(collection)


def stencils(collection):
    """A shipper's mark stencilled on each side facing z, clear of the lashing: a
    diamond over a bar."""
    part = Part("stencils", "stencil")
    for side in (1, 3):
        normal, right = SIDES[side]
        face = add(scale(normal, HALF + 0.002), scale(right, -0.17))
        centre = add(face, scale(UP, HEIGHT * 0.5 + 0.06))
        diamond = [
            add(centre, scale(UP, -0.09)),
            add(centre, scale(right, 0.13)),
            add(centre, scale(UP, 0.09)),
            add(centre, scale(right, -0.13)),
        ]
        inner = [add(centre, scale([p - c for p, c in zip(q, centre)], 0.6)) for q in diamond]
        outer_ids = [part.point(p) for p in diamond]
        inner_ids = [part.point(p) for p in inner]
        for k in range(4):
            n = (k + 1) % 4
            part.face([outer_ids[k], outer_ids[n], inner_ids[n], inner_ids[k]], [0.0] * 4, normal)
        bar = add(face, scale(UP, HEIGHT * 0.5 - 0.1))
        quad = [
            add(bar, scale(right, -0.12), scale(UP, -0.018)),
            add(bar, scale(right, 0.12), scale(UP, -0.018)),
            add(bar, scale(right, 0.12), scale(UP, 0.018)),
            add(bar, scale(right, -0.12), scale(UP, 0.018)),
        ]
        part.face([part.point(p) for p in quad], [0.0] * 4, normal)
    return part.build(collection)


def lashing(collection):
    """A rope lashed round it each way, over the battens and across its lid."""
    part = Part("lashing", "rope")
    reach = HALF + PROUD + ROPE * 0.5
    top = HEIGHT + ROPE
    for axis in ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0)):
        path = []
        for x, y in ((-reach, 0.0), (-reach, top), (reach, top), (reach, 0.0)):
            path.append([axis[0] * x, y, axis[2] * x])
        sweep(part, path, ROPE, 4, caps=False)
    return part.build(collection, sharp_angle=60.0)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    body(collection)
    battens(collection)
    stencils(collection)
    lashing(collection)
    print("crate: %d triangles" % triangles(collection))
    save(out)


main()
