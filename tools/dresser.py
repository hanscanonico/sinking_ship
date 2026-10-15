"""A galley's plate rack flat on its wall (LinerService._dresser), for the
dresser_NNN build scripts (assets/models/dresser_NNN/dresser_NNN.py): one width each,
NNN hundredths of a metre, never one model stretched. A pine rack: a back board
between two posts under a cornice, three shelves, each with its plates stood on
edge leaning back behind a rail, white crockery and every third plate blue.

In Godot's axes, metres: x along the wall, y up, z out of it into the room, the
origin on the floor at the wall's face under its middle. It stands from
LinerService.DRESSER.x to DRESSER.y over the floor, its width along the wall and
no deeper than LinerService.FLAT.
"""

import math
import sys

from model_kit import Part, box, fresh_scene, panel, save, triangles

# From and to how high it stands, and how deep (LinerService.DRESSER and FLAT).
LOW = 0.95
HIGH = 1.8
FLAT = 0.11
# The posts' and the cornice's size; the shelves, how far apart, how thick.
POST = 0.04
CORNICE = 0.05
SHELVES = 3
SHELF_PITCH = 0.28
SHELF = 0.02
# Each rail: from and to how high over its shelf, and how thick.
RAIL = (0.07, 0.085)
RAIL_DEPTH = 0.01
# The plates: their radius, how far apart, how far each leans back from upright, how
# far its middle is dished, and the turns of its rim.
PLATE = 0.085
PLATE_PITCH = 0.2
LEAN = math.radians(14.0)
DISH = 0.008
PLATE_SIDES = 8
BACK = (2, -1)
X = [1.0, 0.0, 0.0]
Y = [0.0, 1.0, 0.0]


def rack(pine, teak, width):
    """The back board, the posts, the cornice, the shelves and their rails."""
    a = -width * 0.5
    b = width * 0.5
    panel(teak, [0.0, (LOW + HIGH) * 0.5, 0.004], X, Y, (b - POST, (HIGH - LOW) * 0.5))
    ends = ((0, -1.0), (0, 1.0), (1, -1.0), (1, 1.0))
    for x in (a, b - POST):
        box(pine, [x, LOW, 0.0], [x + POST, HIGH - CORNICE, FLAT], skip=(BACK,), plain=ends)
    box(pine, [a, HIGH - CORNICE, 0.0], [b, HIGH, FLAT], skip=(BACK,), plain=ends)
    for shelf in range(SHELVES):
        low = LOW + shelf * SHELF_PITCH
        across = ((0, -1.0), (0, 1.0))
        box(pine, [a + POST, low, 0.0], [b - POST, low + SHELF, FLAT - 0.01], skip=(BACK,) + across, plain=ends)
        rail = [a + POST, low + RAIL[0], FLAT - 0.01 - RAIL_DEPTH]
        box(pine, rail, [b - POST, low + RAIL[1], FLAT - 0.01], skip=(BACK,) + across, plain=ends)


def plate(part, x, low):
    """One plate stood on edge on the shelf at [low], leaning back to the board: a
    shallow dish, its hollow toward the room."""
    foot = [x, low + SHELF, FLAT - 0.01 - RAIL_DEPTH - 0.012]
    up = [0.0, math.cos(LEAN), -math.sin(LEAN)]
    out = [0.0, math.sin(LEAN), math.cos(LEAN)]
    centre = [foot[i] + up[i] * PLATE for i in range(3)]
    middle = part.point([centre[i] - out[i] * DISH for i in range(3)])
    ring = []
    for k in range(PLATE_SIDES):
        t = 2.0 * math.pi * (k + 0.5) / PLATE_SIDES
        ring.append(part.point([centre[i] + X[i] * PLATE * math.cos(t) + up[i] * PLATE * math.sin(t) for i in range(3)]))
    for k in range(PLATE_SIDES):
        part.face([middle, ring[k], ring[(k + 1) % PLATE_SIDES]], [0.0, 0.0, 0.0], out)


def plates(white, blue, width):
    """As many plates as stand PLATE_PITCH apart on each shelf, every third blue."""
    count = math.floor((width - 0.12) / PLATE_PITCH + 1e-6)
    first = -count * PLATE_PITCH * 0.5
    for shelf in range(SHELVES):
        low = LOW + shelf * SHELF_PITCH
        for index in range(count):
            part = blue if (index + shelf) % 3 == 0 else white
            plate(part, first + PLATE_PITCH * (index + 0.5), low)


def build(name, width):
    """Writes the .blend named on the command line: a rack [width] along its wall."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    pine = Part("pine", "crate")
    teak = Part("board", "teak")
    white = Part("crockery", "enamel")
    blue = Part("blue", "delft")
    rack(pine, teak, width)
    plates(white, blue, width)
    for part in (pine, teak, white, blue):
        part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
