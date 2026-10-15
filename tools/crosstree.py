"""A mast's crosstree near its head (DeckWorks.mast), for the crosstree_NN build
scripts (assets/models/crosstree_NN/crosstree_NN.py): one size each, made for a mast
NN hundredths of a metre round, never one model scaled. Two trestle trees bolted to
the mast's sides fore and aft, two crosstrees laid athwart over them fore and aft of
the mast, an iron strap over each pair of ends with the shrouds' eyes under it, an
iron brace up to each arm from the mast, and the mast's iron band over it all.

In Godot's axes, metres: x fore and aft, y up, z athwartships, its origin on the
mast's axis at the trestle trees' foot. Its arms reach DeckWorks.CROSSTREE_REACH past
the mast's side; nothing of it stands higher than CROSSTREE_RISE over its origin or
lower than CROSSTREE_DROP under it, where the braces meet the mast.
"""

import math
import sys

from model_kit import Part, box, fresh_scene, lathe, save, stud, torus, triangles, tube

REACH = 1.1
RISE = 0.36
DROP = 0.6
# A trestle tree: how far past the mast it runs fore and aft, its depth and its
# thickness off the mast's side.
TRESTLE = (0.28, 0.14, 0.08)
# A crosstree: its section, square, and how far its middle stands off the mast's face
# fore and aft.
SPAR = 0.11
SPAR_OFF = 0.12
# The iron strap over each pair of ends: how far in from the arms' tips it reaches.
STRAP = 0.06
# The mast band: its foot over the origin and its depth.
BAND = (0.29, 0.07)
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def trestles(wood, iron, radius):
    """The trestle trees either side of the mast, each held by bolts through it."""
    length, depth, thick = radius + TRESTLE[0], TRESTLE[1], TRESTLE[2]
    for side in (-1.0, 1.0):
        inner = radius - 0.01
        low = [-length, 0.0, inner] if side > 0 else [-length, 0.0, -inner - thick]
        high = [length, depth, inner + thick] if side > 0 else [length, depth, -inner]
        box(wood, low, high)
        face = (inner + thick) * side
        for x in (-length + 0.08, length - 0.08):
            stud(iron, [x, depth * 0.5, face], [0.0, 0.0, side], 0.016, 0.012)


def crosstrees(wood, radius):
    """The two crosstrees over the trestle trees, fore and aft of the mast."""
    span = radius + REACH - STRAP * 0.5
    for x in (-(radius + SPAR_OFF), radius + SPAR_OFF):
        low = [x - SPAR * 0.5, TRESTLE[1], -span]
        high = [x + SPAR * 0.5, TRESTLE[1] + SPAR, span]
        box(wood, low, high)


def straps(iron, radius):
    """The iron strap over each end of the pair, and the shrouds' eyes under it."""
    end = radius + REACH
    across = radius + SPAR_OFF + SPAR * 0.5 + 0.012
    for side in (-1.0, 1.0):
        z = (end - STRAP, end) if side > 0 else (-end, -end + STRAP)
        box(iron, [-across, TRESTLE[1] - 0.012, z[0]], [across, TRESTLE[1] + SPAR + 0.012, z[1]], rim=0.012)
        for x in (-(radius + SPAR_OFF), radius + SPAR_OFF):
            axes = ([0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [1.0, 0.0, 0.0])
            centre = [x, TRESTLE[1] - 0.04, side * (end - STRAP * 0.5)]
            torus(iron, centre, axes, 0.022, (0.007, 0.007), 6, 3)


def braces(iron, radius):
    """An iron brace from the mast's side up under each arm."""
    for side in (-1.0, 1.0):
        foot = [0.0, -DROP + 0.012, side * (radius - 0.004)]
        head = [0.0, TRESTLE[1] - 0.004, side * (radius + REACH * 0.62)]
        tube(iron, foot, head, [(0.012, 0.0, 0.0), (0.012, 1.0, 0.0)], 5, caps=(False, False))


def band(iron, radius):
    """The mast's iron band over the crosstrees."""
    out = radius + 0.012
    rows = [
        (radius - 0.004, BAND[0], 0.0),
        (out, BAND[0], 1.0),
        (out, BAND[0] + 0.016, 0.0),
        (out, BAND[0] + BAND[1] - 0.016, 0.0),
        (out, BAND[0] + BAND[1], 1.0),
        (radius - 0.004, BAND[0] + BAND[1], 0.0),
    ]
    sides = 12 if radius < 0.3 else 20
    lathe(iron, (0.0, 0.0, 0.0), UP, rows, sides, phase=math.pi / sides, wound=True)


def build(name, radius):
    """Writes the .blend named on the command line: a crosstree for a mast of
    [radius]."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    wood = Part("timber", "mast")
    iron = Part("iron", "dark")
    trestles(wood, iron, radius)
    crosstrees(wood, radius)
    straps(iron, radius)
    braces(iron, radius)
    band(iron, radius)
    wood.build(collection)
    iron.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
