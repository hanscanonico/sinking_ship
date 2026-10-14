"""A crate stowed on a hold's tween deck (CargoHold.crate), for the stowed_crate_NN
build scripts (assets/models/stowed_crate_NN/stowed_crate_NN.py): one size each, its
side NN hundredths of a metre, never one model scaled. It is the loose deck crate's
look (assets/models/crate) in pale pine: planked sides and lid, battens round its foot
and its lid and a post up each corner between them, a brace across the sides facing
z, a shipper's stencil on the sides facing x — the open edge of the stow — and a rope
lashed round it both ways over its lid.

In Godot's axes, metres, the middle of its underside at the origin. Nothing of it
stands past the square of its side or over its height: the lashing lies on the
battens at its sides and over its lid, so a crate stacked on it sits on the rope.
"""

import math
import sys

from model_kit import Part, axes_along, fresh_scene, lathe, save, sweep, triangles, turned_box

BATTEN = 0.07
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


def body(collection, half, lid):
    """Its planked body: its sides from the deck to its lid, one seam inked across each
    side between two planks; its lid's planks across it."""
    part = Part("body", "stowed")
    seam = lid * 0.5
    rows = [(0.0, 0.0), (seam - SEAM, 0.0), (seam, 1.0), (seam + SEAM, 0.0), (lid, 0.0)]
    for normal, right in SIDES:
        face = scale(normal, half)
        for j in range(len(rows) - 1):
            low, low_ink = rows[j]
            high, high_ink = rows[j + 1]
            quad = [
                add(face, scale(right, -half), scale(UP, low)),
                add(face, scale(right, half), scale(UP, low)),
                add(face, scale(right, half), scale(UP, high)),
                add(face, scale(right, -half), scale(UP, high)),
            ]
            part.face([part.point(p) for p in quad], [low_ink, low_ink, high_ink, high_ink], normal)
    across = [(-half, 0.0)]
    for seam_at in (-half / 3.0, half / 3.0):
        across += [(seam_at - SEAM, 0.0), (seam_at, 1.0), (seam_at + SEAM, 0.0)]
    across.append((half, 0.0))
    for j in range(len(across) - 1):
        a, ink_a = across[j]
        b, ink_b = across[j + 1]
        quad = [[-half, lid, a], [half, lid, a], [half, lid, b], [-half, lid, b]]
        part.face([part.point(p) for p in quad], [ink_a, ink_a, ink_b, ink_b], UP)
    return part.build(collection)


def battens(collection, half, lid):
    """The battens round its foot and its lid, the posts up its corners between them,
    and a brace across each side facing z."""
    part = Part("battens", "crate")
    out = (half + PROUD) * math.sqrt(2.0)
    inside = half * math.sqrt(2.0)
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [(out, 0.0, 1.0), (out, BATTEN, 1.0), (inside, BATTEN, 1.0)],
        4,
        phase=math.pi / 4,
        wound=True,
    )
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [(inside, lid - BATTEN, 1.0), (out, lid - BATTEN, 1.0), (out, lid, 1.0), (inside, lid, 0.0)],
        4,
        phase=math.pi / 4,
        wound=True,
    )
    low = BATTEN
    high = lid - BATTEN
    for cx in (-1.0, 1.0):
        for cz in (-1.0, 1.0):
            corner = half + PROUD - POST * 0.5
            middle = [cx * corner, (low + high) * 0.5, cz * corner]
            turned_box(
                part,
                middle,
                ((1.0, 0.0, 0.0), UP, (0.0, 0.0, 1.0)),
                (POST * 0.5, (high - low) * 0.5, POST * 0.5),
                SEAM,
                skip=((1, -1.0), (1, 1.0), (0, -cx), (2, -cz)),
            )
    # A brace from the foot's batten at one post up to the lid's at the other.
    for side in (1, 3):
        normal, right = SIDES[side]
        face = scale(normal, half + PROUD * 0.5)
        reach = half - POST
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
        turned_box(
            part,
            middle,
            (along, across, normal),
            (length * 0.5 - 0.03, 0.03, PROUD * 0.5),
            SEAM,
            skip=((2, -1.0), (0, -1.0), (0, 1.0)),
        )
    return part.build(collection)


def stencils(collection, half, lid):
    """A shipper's mark stencilled on each side facing x, clear of the lashing: a
    diamond over a bar."""
    part = Part("stencils", "stencil")
    size = half / 0.38
    for side in (0, 2):
        normal, right = SIDES[side]
        face = add(scale(normal, half + 0.002), scale(right, -0.16 * size))
        centre = add(face, scale(UP, lid * 0.5 + 0.05 * size))
        diamond = [
            add(centre, scale(UP, -0.075 * size)),
            add(centre, scale(right, 0.11 * size)),
            add(centre, scale(UP, 0.075 * size)),
            add(centre, scale(right, -0.11 * size)),
        ]
        inner = [add(centre, scale([p - c for p, c in zip(q, centre)], 0.6)) for q in diamond]
        outer_ids = [part.point(p) for p in diamond]
        inner_ids = [part.point(p) for p in inner]
        for k in range(4):
            n = (k + 1) % 4
            part.face([outer_ids[k], outer_ids[n], inner_ids[n], inner_ids[k]], [0.0] * 4, normal)
        bar = add(face, scale(UP, lid * 0.5 - 0.08 * size))
        quad = [
            add(bar, scale(right, -0.1 * size), scale(UP, -0.016)),
            add(bar, scale(right, 0.1 * size), scale(UP, -0.016)),
            add(bar, scale(right, 0.1 * size), scale(UP, 0.016)),
            add(bar, scale(right, -0.1 * size), scale(UP, 0.016)),
        ]
        part.face([part.point(p) for p in quad], [0.0] * 4, normal)
    return part.build(collection)


def lashing(collection, side, height):
    """A rope lashed round it each way, lying on the battens and across its lid, its
    outside at the crate's side and its top at its height."""
    part = Part("lashing", "rope")
    reach = side * 0.5 - ROPE
    top = height - ROPE
    for axis in ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0)):
        path = []
        for x, y in ((-reach, 0.0), (-reach, top), (reach, top), (reach, 0.0)):
            path.append([axis[0] * x, y, axis[2] * x])
        sweep(part, path, ROPE, 4, caps=False)
    return part.build(collection, sharp_angle=60.0)


def build(name, side, height):
    """Writes the .blend named on the command line: a stowed crate [side] square and
    [height] tall over all, its lashing included."""
    out = sys.argv[sys.argv.index("--") + 1]
    half = side * 0.5 - 2.0 * ROPE - PROUD
    lid = height - 2.0 * ROPE
    collection = fresh_scene()
    body(collection, half, lid)
    battens(collection, half, lid)
    stencils(collection, half, lid)
    lashing(collection, side, height)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
