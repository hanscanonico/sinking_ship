"""The free floor spot every ship's generator shares (#307): the point of a room's floor
where a thing can lie clear of all that stands there — where each room below her main
deck has its bonus spot (#308).

Every generator keeps her pieces as numbers in the same shapes and hands them here as
they are, in ship-local metres (x toward the bow, z to starboard, y up):

    room       (x0, x1, z0, z1, floor, name)
    plat_geo   (x0, x1, z0, z1, height) per platform
    ramp_geo   (x0, x1, z0, z1, axis, start, end) per stair or ramp
    block_geo  (x0, x1, z0, z1, bottom, top, whether a box) per blocker, a cylinder's
               plan the square round it

Usage, from a generator beside it in tools/:

    from floor_spots import free_floor_spot
    x, y, z = free_floor_spot(room, plat_geo, ramp_geo, block_geo)
"""
import math

# How clear of all that stands on the floor a spot is wanted: a body's radius
# (BrawlRules.body_radius), so a body can stand on it. Where a room has nowhere that
# clear, its clearest point, but never less clear than LEAST: room for a bonus to lie
# (est.).
CLEAR = 0.4
LEAST = 0.2
# How far apart the points tried stand, out from the room's middle.
GRAIN = 0.05
# A stair or a blocker reaching lower than a body's height over the floor
# (BrawlRules.body_height) stands in the way there; a lintel over a door does not.
REACH = 1.7
# Clearances are measured to the generators' grain: four places of a metre.
PLACES = 4
SLIVER = 1e-6


def free_floor_spot(room, plat_geo, ramp_geo, block_geo, clear=CLEAR, least=LEAST):
    """The point (x, y, z) of `room`'s floor nearest its middle with `clear` of free floor
    round it: on her platforms at its floor's height, inside its area, and that far from
    every stair, ramp and blocker standing on that floor. Where no point has that much,
    the clearest, nearest the middle; None when even that is less than `least`. The
    points tried stand GRAIN apart out from the middle; of two as near it, the one aft,
    then the one to port."""
    x0, x1, z0, z1, floor, _name = room
    middle_x, middle_z = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    holes = _holes(room, plat_geo)
    rects, circles = _in_the_way(room, plat_geo, ramp_geo, block_geo, clear)
    shapes = holes + rects

    def clearance(i, j):
        x, z = middle_x + i * GRAIN, middle_z + j * GRAIN
        found = min(clear, x - x0, x1 - x, z - z0, z1 - z)
        for rect in shapes:
            found = min(found, _to_rect(x, z, rect))
        for cx, cz, radius in circles:
            found = min(found, math.hypot(x - cx, z - cz) - radius)
        return round(found, PLACES)

    if clearance(0, 0) >= clear:
        return (middle_x, floor, middle_z)
    reach_x = int((x1 - x0) * 0.5 / GRAIN)
    reach_z = int((z1 - z0) * 0.5 / GRAIN)
    tried = sorted((i * i + j * j, i, j) for i in range(-reach_x, reach_x + 1)
                   for j in range(-reach_z, reach_z + 1))
    best, best_at = -math.inf, None
    for _distance, i, j in tried:
        found = clearance(i, j)
        if found >= clear:
            return (middle_x + i * GRAIN, floor, middle_z + j * GRAIN)
        if found > best:
            best, best_at = found, (i, j)
    if best < least:
        return None
    return (middle_x + best_at[0] * GRAIN, floor, middle_z + best_at[1] * GRAIN)


def _holes(room, plat_geo):
    """The parts of `room`'s area no platform at its floor's height covers, as
    (x0, x1, z0, z1): her plan cut along every edge of those platforms, each piece in no
    platform a hole — a stairwell, a hatch, the open side of a gallery."""
    x0, x1, z0, z1, floor, _name = room
    floors = [p for p in plat_geo if abs(p[4] - floor) < SLIVER]
    xs = sorted({x0, x1} | {v for p in floors for v in p[0:2] if x0 < v < x1})
    zs = sorted({z0, z1} | {v for p in floors for v in p[2:4] if z0 < v < z1})
    holes = []
    for a, b in zip(xs, xs[1:]):
        for c, d in zip(zs, zs[1:]):
            x, z = (a + b) * 0.5, (c + d) * 0.5
            if not any(p[0] <= x <= p[1] and p[2] <= z <= p[3] for p in floors):
                holes.append((a, b, c, d))
    return holes


def _in_the_way(room, plat_geo, ramp_geo, block_geo, clear):
    """The stairs, ramps and blockers standing on `room`'s floor within `clear` of its
    area — anything reaching from no higher than REACH over the floor to above it, and
    not standing on a deck over the floor — as rectangles (x0, x1, z0, z1), and the
    cylinders as circles (x, z, radius)."""
    x0, x1, z0, z1, floor, _name = room
    near = (x0 - clear, x1 + clear, z0 - clear, z1 + clear)

    def reaches(plan, bottom):
        # Down to lower than REACH over the floor, near the room, standing on no deck
        # between: a deck of hers over the floor, at or under its underside, under it.
        if bottom >= floor + REACH or not _overlap(plan, near):
            return False
        return not any(floor + SLIVER < p[4] <= bottom + SLIVER and _overlap(plan, p[0:4])
                       for p in plat_geo)

    rects, circles = [], []
    for rx0, rx1, rz0, rz1, _axis, start, end in ramp_geo:
        # A stair up from the floor, or down from it through a stairwell, alike.
        if max(start, end) >= floor - SLIVER and reaches((rx0, rx1, rz0, rz1), min(start, end)):
            rects.append((rx0, rx1, rz0, rz1))
    for bx0, bx1, bz0, bz1, bottom, top, box in block_geo:
        if top <= floor + SLIVER or not reaches((bx0, bx1, bz0, bz1), bottom):
            continue
        if box:
            rects.append((bx0, bx1, bz0, bz1))
        else:
            circles.append(((bx0 + bx1) * 0.5, (bz0 + bz1) * 0.5, (bx1 - bx0) * 0.5))
    return rects, circles


def _overlap(a, b):
    """Whether the rectangles `a` and `b`, each (x0, x1, z0, z1), overlap."""
    return a[0] < b[1] and a[1] > b[0] and a[2] < b[3] and a[3] > b[2]


def _to_rect(x, z, rect):
    """How far the point (x, z) is from the rectangle (x0, x1, z0, z1): 0 inside it."""
    x0, x1, z0, z1 = rect
    return math.hypot(max(x0 - x, 0.0, x - x1), max(z0 - z, 0.0, z - z1))
