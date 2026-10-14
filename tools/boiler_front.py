"""A Scotch boiler's front, flat in an engine room's bulkhead (EngineRoom._boiler), for
the boiler_NN build scripts (assets/models/boiler_NN/boiler_NN.py): one size each,
its front's radius NN hundredths of a metre, never one model scaled.

In Godot's axes, metres: x along the bulkhead, y up from the floor, z out of the
bulkhead's face into the room, its origin on the face at the floor under the front's
middle. The front's middle stands EngineRoom.BOILER_FOOT + radius up; the furnace's
mouth, where the fire (ShipLamp) glows, at EngineRoom.FURNACE_HEIGHT, kept open in a
steel frame. Under a body's height nothing stands more than FURNISHING_OUT from the
face (art-lint); a front tall enough to stand its stop valve over head height
(RoomDressing.HEADROOM) carries it on top, as the procedural front did.
"""

import math

from model_kit import Part, axes_along, fresh_scene, lathe, save, stud, sweep, triangles, turned_box

FOOT = 0.2
FURNACE = 0.62
# ShipLamp.MOUTH, halved: the fire's mouth.
MOUTH = (0.21, 0.13)
HEADROOM = 1.85
OUT = (0.0, 0.0, 1.0)
UP = (0.0, 1.0, 0.0)
X = (1.0, 0.0, 0.0)
Y = (0.0, 1.0, 0.0)
Z = (0.0, 0.0, 1.0)
# How far out from the face the front plate, the shell's ring and the furnace's
# surround stand.
PLATE = 0.03
RING = 0.05
SURROUND = 0.04


def proud(part, centre, half, rim=None, skip=((2, -1.0),)):
    """A box square to the face round [centre] by [half] each way, its back left off
    (it stands on the face or in front of it)."""
    turned_box(part, centre, (X, Y, Z), half, rim, skip=skip)


def rect_frame(part, centre, outer, inner, low, high, rim):
    """A rectangular frame round [centre] (x, y) in the plane of the face, from
    [outer] (half x, half y) in to [inner], standing from z [low] out to [high]: its
    front inked at both edges, [rim] in to 0, and its outside and inside edges."""
    cx, cy = centre

    def loop(hx, hy, z):
        return [
            (cx - hx, cy - hy, z),
            (cx + hx, cy - hy, z),
            (cx + hx, cy + hy, z),
            (cx - hx, cy + hy, z),
        ]

    rings = [
        (loop(outer[0], outer[1], low), 0.0),
        (loop(outer[0], outer[1], high), 1.0),
        (loop(outer[0] - rim, outer[1] - rim, high), 0.0),
        (loop(inner[0] + rim, inner[1] + rim, high), 0.0),
        (loop(inner[0], inner[1], high), 1.0),
        (loop(inner[0], inner[1], low), 0.0),
    ]
    for j in range(len(rings) - 1):
        a, ink_a = rings[j]
        b, ink_b = rings[j + 1]
        for k in range(4):
            n = (k + 1) % 4
            quad = [a[k], a[n], b[n], b[k]]
            middle = [sum(p[i] for p in quad) / 4.0 for i in range(3)]
            if j == 0:
                outward = (middle[0] - cx, middle[1] - cy, 0.0)
            elif j == len(rings) - 2:
                outward = (cx - middle[0], cy - middle[1], 0.0)
            else:
                outward = OUT
            ids = [part.point(p) for p in quad]
            part.face(ids, [ink_a, ink_a, ink_b, ink_b], outward)


def shell(collection, radius, sides):
    """The front plate and the steel ring of the shell round it, riveted."""
    centre = (0.0, FOOT + radius, 0.0)
    plate = Part("plate", "boiler")
    disc = [(radius - 0.03, PLATE, 0.0), (0.0, PLATE, 0.0)]
    lathe(plate, centre, axes_along(OUT), disc, sides, wound=True)
    plate.build(collection, sharp_angle=60.0)
    ring = Part("ring", "steel")
    lathe(
        ring,
        centre,
        axes_along(OUT),
        [
            (radius + 0.015, RING, 1.0),
            (radius - 0.0175, RING, 0.0),
            (radius - 0.05, RING, 1.0),
            (radius - 0.05, PLATE, 1.0),
        ],
        sides,
        wound=True,
    )
    for k in range(sides):
        turn = 2.0 * math.pi * (k + 0.5) / sides
        reach = radius - 0.0175
        at = (math.cos(turn) * reach, FOOT + radius + math.sin(turn) * reach, RING)
        stud(ring, at, OUT, 0.011, 0.009, 4, turn)
    # The bearer the shell stands on, down to the floor.
    bearer = (FOOT + 0.06) * 0.5
    proud(ring, (0.0, bearer, 0.02), (radius * 0.55, bearer, 0.02), skip=((1, -1.0), (2, -1.0)))
    ring.build(collection, sharp_angle=40.0)


def furnace(steel, dark, x, y, open_mouth):
    """A furnace at [x] along the front, [y] up: open, its mouth framed round the fire with
    grate bars across it, or shut behind a round door on hinges with its latch; an
    ashpit door under it either way."""
    if open_mouth:
        mouth = MOUTH
        proud(dark, (x, y, SURROUND * 0.5), (mouth[0] + 0.09, mouth[1] + 0.08, SURROUND * 0.5))
        frame = (mouth[0] + 0.05, mouth[1] + 0.05)
        rect_frame(steel, (x, y), frame, mouth, SURROUND, 0.065, 0.015)
        for bar in range(4):
            bx = x + mouth[0] * (bar - 1.5) * 0.5
            proud(dark, (bx, y, 0.055), (0.012, mouth[1], 0.006))
        ash = y - mouth[1] - 0.2
        ash_half = (mouth[0], 0.06)
    else:
        door = 0.15
        proud(dark, (x, y, SURROUND * 0.5), (door + 0.03, door + 0.03, SURROUND * 0.5))
        lathe(
            steel,
            (x, y, 0.0),
            axes_along(OUT),
            [(door, SURROUND, 0.0), (door, 0.062, 1.0), (0.0, 0.068, 0.0)],
            10,
            wound=True,
        )
        # Its latch bar across, and its hinges on the left.
        proud(steel, (x + 0.02, y, 0.074), (0.11, 0.014, 0.006))
        for hy in (-0.08, 0.08):
            proud(steel, (x - door - 0.01, y + hy, 0.055), (0.03, 0.018, 0.012))
        ash = y - door - 0.17
        ash_half = (0.14, 0.05)
    proud(dark, (x, ash, 0.04), (ash_half[0], ash_half[1], 0.008))
    proud(steel, (x, ash + ash_half[1] - 0.012, 0.052), (ash_half[0] * 0.6, 0.008, 0.006))


def stays(part, radius, clear):
    """The stays' nuts across the front over the furnaces, none on what [clear] holds
    (x, y, how far round)."""
    middle = FOOT + radius
    spots = [(-0.5, 0.06), (-0.25, 0.06), (0.0, 0.06), (0.25, 0.06), (0.5, 0.06)]
    spots += [(-0.3, 0.42), (0.3, 0.42), (-0.15, 0.62), (0.15, 0.62)]
    for sx, sy in spots:
        x = sx * radius
        y = middle + sy * radius
        if any(math.hypot(x - cx, y - cy) < reach + 0.04 for cx, cy, reach in clear):
            continue
        lathe(
            part,
            (x, y, 0.0),
            axes_along(OUT),
            [(0.03, PLATE, 0.0), (0.03, 0.052, 1.0), (0.0, 0.052, 0.0)],
            4,
            phase=math.pi / 4,
            wound=True,
        )


def gauge_glass(brass, glass, x, low):
    """A water gauge glass at [x], [low] up: brass cocks top and bottom on stubs out
    of the front, the glass between them, a drain cock under."""
    z = 0.075
    for y in (low - 0.035, low + 0.4):
        lathe(
            brass,
            (x, y, z),
            axes_along(UP),
            [(0.0, 0.0, 0.0), (0.026, 0.0, 1.0), (0.026, 0.035, 1.0), (0.0, 0.035, 0.0)],
            6,
            phase=math.pi / 6,
            wound=True,
        )
        proud(brass, (x, y + 0.0175, (PLATE + z) * 0.5), (0.012, 0.012, (z - PLATE) * 0.5))
    tube = [(0.0, 0.0, 0.0), (0.012, 0.0, 0.0), (0.012, 0.4, 0.0), (0.0, 0.4, 0.0)]
    lathe(glass, (x, low, z), axes_along(UP), tube, 6, wound=True)
    # The drain cock's handle under it.
    proud(brass, (x + 0.03, low - 0.05, z), (0.03, 0.006, 0.006), skip=())


def pressure_gauge(brass, face, dark, top):
    """The pressure gauge high on the front: a brass bezel round its dial, its needle."""
    centre = (0.0, top - 0.28, 0.0)
    lathe(
        brass,
        centre,
        axes_along(OUT),
        [(0.11, PLATE, 0.0), (0.11, 0.062, 1.0), (0.088, 0.062, 1.0)],
        12,
        wound=True,
    )
    lathe(face, centre, axes_along(OUT), [(0.088, 0.058, 0.0), (0.0, 0.058, 0.0)], 12, wound=True)
    turn = math.radians(40.0)
    tip = (math.cos(turn) * 0.065, top - 0.28 + math.sin(turn) * 0.065, 0.062)
    sweep(dark, [(0.0, top - 0.28, 0.062), tip], 0.004, 3)


def stop_valve(brass, bright, top):
    """The steam stop valve on top, where the main steam pipe leaves it
    (EngineRoom._steam_pipe), out of the wall on its branch, under its handwheel."""
    y = top + 0.04
    z = 0.16
    sweep(brass, [(0.0, y - 0.03, 0.0), (0.0, y - 0.03, z - 0.05)], 0.04, 8)
    lathe(
        brass,
        (0.0, y, z),
        axes_along(UP),
        [
            (0.0, -0.07, 0.0),
            (0.065, -0.07, 1.0),
            (0.08, -0.02, 0.0),
            (0.05, 0.05, 1.0),
            (0.03, 0.08, 0.0),
            (0.0, 0.08, 0.0),
        ],
        8,
        phase=math.pi / 8,
        wound=True,
    )
    sweep(bright, [(0.0, y + 0.08, z), (0.0, y + 0.11, z)], 0.008, 4, caps=True)
    hub = (0.0, y + 0.1, z)
    rim = []
    for k in range(11):
        turn = 2.0 * math.pi * k / 10
        rim.append((math.cos(turn) * 0.11, y + 0.1, z + math.sin(turn) * 0.11))
    sweep(bright, rim, 0.012, 3, caps=False)
    for k in range(4):
        turn = 2.0 * math.pi * (k + 0.5) / 4
        spoke = (math.cos(turn) * 0.1, y + 0.1, z + math.sin(turn) * 0.1)
        sweep(bright, [hub, spoke], 0.006, 3, caps=False)


def build(radius):
    """Builds the front of [radius] into the blend file named after `--`."""
    import sys

    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    sides = 20 if radius >= 0.8 else 18
    shell(collection, radius, sides)
    steel = Part("furnace_steel", "bright_steel")
    dark = Part("furnace_dark", "dark")
    # A front of three furnaces' breadth fires three; a smaller, one.
    furnace(steel, dark, 0.0, FURNACE, True)
    top = FOOT + radius * 2.0
    glasses = [(side * radius * 0.6, FOOT + radius * 1.1) for side in (-1.0, 1.0)]
    # What the stays keep clear of: the furnaces, the gauge glasses and the gauge.
    clear = [(0.0, FURNACE, 0.32), (0.0, top - 0.28, 0.11)]
    clear += [(x, low + h, 0.03) for x, low in glasses for h in (0.0, 0.2, 0.4)]
    if radius >= 0.8:
        for side in (-1.0, 1.0):
            x = side * 0.55 * radius
            y = FURNACE + 0.2 * radius
            furnace(steel, dark, x, y, False)
            clear.append((x, y, 0.2))
    brass = Part("brass", "brass")
    glass = Part("glass", "gauge")
    nuts = Part("stays", "steel")
    stays(nuts, radius, clear)
    for x, low in glasses:
        gauge_glass(brass, glass, x, low)
    face = Part("dial", "gauge")
    pressure_gauge(brass, face, dark, top)
    if top >= HEADROOM:
        stop_valve(brass, steel, top)
    for part in (steel, dark, brass, glass, nuts, face):
        part.build(collection, sharp_angle=50.0)
    name = out.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
