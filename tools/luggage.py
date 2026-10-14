"""A luggage shelf over head height on a cabin's wall, for the luggage build scripts
(assets/models/luggage_shelf/luggage_shelf.py and luggage_rack/luggage_rack.py): a
board on two knees with a brass rail along its front, and the luggage on it.

In Godot's axes, metres: x along the wall (Wall.right), y up from the floor, z out of
the wall's face into the room, its origin on the floor at the wall's face under the
shelf's middle.
"""

import sys

from model_kit import Part, box, fresh_scene, save, slab, stud, sweep, triangles, tube

BACK = (2, -1)
UNDER = (1, -1)
X = [1.0, 0.0, 0.0]
Z = [0.0, 0.0, 1.0]
# The board's thickness, and its knees' drop under it and their thickness.
BOARD = 0.03
KNEE = 0.16
KNEE_THICK = 0.024
# The brass rail along the board's front: how high over it and how far in.
RAIL = 0.05
RAIL_IN = 0.02


def shelf(frame, brass, half, low, depth, knees):
    """The board from -half to half along the wall at low, depth out; a knee under it
    at each of knees along it, its face a triangle from the wall out under the board;
    a brass rail on two posts along its front."""
    box(frame, [-half, low, 0.0], [half, low + BOARD, depth], rim=0.01, skip=(BACK,))
    for x in knees:
        reach = depth * 0.75
        for face in (-1.0, 1.0):
            edge = x + face * KNEE_THICK * 0.5
            slab(frame, [[edge, low, 0.0], [edge, low, reach], [edge, low - KNEE, 0.0]], [face, 0.0, 0.0])
        a = x - KNEE_THICK * 0.5
        b = x + KNEE_THICK * 0.5
        slab(frame, [[a, low, reach], [b, low, reach], [b, low - KNEE, 0.0], [a, low - KNEE, 0.0]], [0.0, -reach, KNEE], 1.0)
    top = low + BOARD
    z = depth - RAIL_IN
    ends = (-half + 0.04, half - 0.04)
    sweep(brass, [[ends[0], top, z], [ends[0], top + RAIL, z], [ends[1], top + RAIL, z], [ends[1], top, z]], 0.007, 4, caps=False)


def suitcase(body, band, brass, a, b, low, high, near, far, straps):
    """A suitcase of body from a to b along the wall, low to high, near to far out:
    its lid's seam round it a band of band, two straps of band over it at straps, and
    on its front a brass handle and two catches."""
    box(body, [a, low, near], [b, high, far], skip=(UNDER,))
    seam = high - (high - low) * 0.3
    box(band, [a - 0.004, seam - 0.012, near - 0.004], [b + 0.004, seam + 0.012, far + 0.004], inked=False, skip=(UNDER, (1, 1)))
    for x in straps:
        box(band, [x - 0.015, low, near - 0.003], [x + 0.015, high + 0.003, far + 0.003], inked=False, skip=(UNDER,))
    middle = (a + b) * 0.5
    grip = [[middle - 0.05, high - 0.03, far], [middle - 0.035, high + 0.005, far + 0.012], [middle + 0.035, high + 0.005, far + 0.012], [middle + 0.05, high - 0.03, far]]
    sweep(brass, grip, 0.007, 4, caps=False)
    for x in (a + 0.06, b - 0.06):
        stud(brass, [x, seam, far + 0.004], Z, 0.014, 0.008, 4)


def bundle(linen, rope, a, b, low, near, far):
    """A blanket rolled up and tied, lying along the wall from a to b on low, from near
    to far out."""
    radius = (far - near) * 0.5
    centre_y = low + radius * 0.85
    centre_z = (near + far) * 0.5
    tube(linen, [a, centre_y, centre_z], [b, centre_y, centre_z], [(radius, 0.0, 1.0), (radius, 1.0, 1.0)], 6, caps=(True, True))
    for share in (0.25, 0.75):
        x = a + (b - a) * share
        tube(rope, [x - 0.008, centre_y, centre_z], [x + 0.008, centre_y, centre_z], [(radius + 0.004, 0.0, 0.0), (radius + 0.004, 1.0, 0.0)], 6, caps=(False, False))


def build(name, half, low, depth, knees, luggage):
    """The model name: a shelf (shelf()) and luggage(parts) on it, written to the
    .blend named after the script's argument."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("frame", "brass", "upholstery", "leather", "dark", "linen", "rope")}
    shelf(parts["frame"], parts["brass"], half, low, depth, knees)
    luggage(parts, low + BOARD)
    for part in parts.values():
        if part.faces:
            part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
