"""Every flight's open sides railed, one helper every ship's generator shares (#574, #587):
a balustrade along each long side of a flight wherever a body walking off it would come
down more than a step, laid once her decks, her flights, her railings and what stands by
them are all laid.

Every generator keeps her pieces as numbers in the same shapes and hands them here as
they are, in ship-local metres (x toward the bow, z to starboard, y up):

    plat_geo   (x0, x1, z0, z1, height) per platform
    ramp_geo   (x0, x1, z0, z1, axis, start, end) per stair or ramp
    block_geo  (x0, x1, z0, z1, bottom, top, whether a box) per blocker, a cylinder's
               plan the square round it
    rail_geo   (platform, from, to) per railing
    ramps      each ramp's id, "Ramp_" and its name, in ramp_geo's order

and her box(bid, x0, x1, z0, z1, bottom, top), which lays a blocker and adds it to
block_geo: each rail laid is stood clear of the rails laid before it.

Usage, from a generator beside it in tools/, run from the repo's root as they all are:

    from flight_rails import rail_flight_sides
    rail_flight_sides(plat_geo, ramp_geo, block_geo, rail_geo, ramps, box)

Where a rail goes. A railing (ShipRailing) runs along one deck's edge at that deck's height
and holds a body on a stair only within a step under it and a railing's height over it
(#552), so it cannot follow a flight down: a flight's side is held by a rail of its own, a
balustrade PLATING thick against it outside it, laid in steps along it no longer than
SIDE_STEP, as the Titanic's open decks' flights' outboard sides are (#573), each to a
railing's height over its highest tread (est.). It stands wherever a body walking off that
side would come down more than a step, and only there: along a stretch of it where nothing
beside it stands within a step of its treads — no floor, no landing, no other flight — and
nothing holds a body by it as the rules hold one: nothing standing within a body's radius of
it over its feet and under its head (a wall, a casing, a boiler, the open decks' plating, a
deck's edge, another flight beside it), no deck's railing along it at its feet's height. So
a flight's head and foot stay open, and so does its side wherever it meets a floor or a
landing or another flight within a step; where it meets one at its end, a body's breadth of
it stays open (BREADTH), so a body coming off the flight there turns off it onto that as it
did before — but no farther than a body walking off it would come down more than it jumps
back up (JUMP: a flight beside it going the other way). And it cuts no way a body uses under
it: it hangs from its treads, or a body's height and HEAD_CLEAR over what is under it or
within a body's radius of it where that is higher — a deck, or another flight's treads — so
a body there walks under it and one on its treads is held by it. Where it cannot hang so,
where something stands in the doorway the art heads under it (DoorFrame: what is seen
through across it, DOORWAY_PROBE either side), or by the opening a deck's railing leaves
broken (art-lint's open spans: that doorway's posts would stand in it), it stands on the
deck under it as a wall does, in the gap beside what stands against the flight there; over
another flight's treads, never: that flight is walked as wide as it was. Under what stands
over it, it runs through nothing.
"""
import math
import re


def _rule(key):
    with open("data/rules/brawl.tres") as f:
        return float(re.search(r"^%s = ([\d.]+)$" % key, f.read(), re.M).group(1))


PLATING = 0.1  # a side rail's thickness, as her plating along a deck's edge is
SIDE_STEP = 1.0  # the longest step a side rail is laid in along its flight
RAIL_LEAST = 0.05  # a stretch shorter than this is no way through for anybody
BREADTH = 2 * _rule("body_radius")
RAIL_HALF = 0.05  # half a railing's breadth: its cap rail (ship_art's RAIL_WIDTH, 0.09) either side of its line
WELL_CLEAR = BREADTH + RAIL_HALF
BODY_HEIGHT = _rule("body_height")
SIDE_SAMPLE = 0.05  # how far apart along a flight's side what stands beside it is read
SIDE_BESIDE = 0.05  # how far out past a flight's side what a body comes down on is read
HOLD_GAP = _rule("body_radius")  # what stands this near a flight's side holds a body on it
STEP = _rule("step_height")
RAIL_HEIGHT = _rule("railing_height")
JUMP = _rule("jump_height")
HEAD_CLEAR = 0.01  # how far over a body's head on what is under it a rail hung over that is laid
RAIL_THIN = 0.02  # the least a rail standing in the gap beside what stands by its flight is thick
OPENING_INBOARD = 0.05  # how far inboard of a railing's line art-lint's probes through it start
DOORWAY_PROBE = 0.2  # how far either side of a doorway's head its opening is seen through


def _clamp(v, a, b):
    return min(max(v, a), b)


def _lerp(a, b, t):
    return a + (b - a) * t


def across_along(g, fixed):
    """A box's (x0, x1, z0, z1, ...) ranges across and along a line x = c (fixed 0) or z = c
    (fixed 2)."""
    return (g[0:2], g[2:4]) if fixed == 0 else (g[2:4], g[0:2])


def _level(h):
    return lambda v: h


def _rising(r, a, b):
    """Flight r's height at v along its rise, from a to b."""
    return lambda v: r[5] + (r[6] - r[5]) * (v - a) / (b - a)


def _overlap(g, ranges):
    """Whether g's (x0, x1, z0, z1, ...) plan overlaps ranges' (x0, x1, z0, z1) by more than a sliver."""
    return g[0] < ranges[1] - 1e-3 and ranges[0] < g[1] - 1e-3 and g[2] < ranges[3] - 1e-3 and ranges[2] < g[3] - 1e-3


def _highest(r, ranges):
    """Flight r's highest over the plan ranges."""
    r_lo, r_hi = (r[0], r[1]) if r[4] == 0 else (r[2], r[3])
    a_lo, a_hi = (ranges[0], ranges[1]) if r[4] == 0 else (ranges[2], ranges[3])
    return max(_rising(r, r_lo, r_hi)(_clamp(v, r_lo, r_hi)) for v in (a_lo, a_hi))


def side_open(plat_geo, ramp_geo, block_geo, rail_geo, k, fixed, line, out, lo, hi):
    """The stretches (from, to) along flight k's side on the line x = line (fixed 0) or z = line
    (fixed 2), its outside toward out, between lo and hi along it, where a body walking off it
    would come down more than a step; and the flight's height along it."""
    tread = _rising(ramp_geo[k], lo, hi)
    beside = line + out * SIDE_BESIDE
    floors = []  # ((along from, to), height at v, its base: None for a deck) of what is beside
    ledges = []  # ((along from, to), height) of each deck whose edge stands a gap outside it
    for p in plat_geo:
        p_across, p_along = across_along(p, fixed)
        if not (p_along[0] < hi and p_along[1] > lo):
            continue
        if p_across[0] <= beside <= p_across[1]:
            floors.append((p_along, _level(p[4]), None))
        elif out * line < (p_across[0] if out > 0 else -p_across[1]) <= out * line + HOLD_GAP:
            ledges.append((p_along, p[4]))
    for j, r in enumerate(ramp_geo):
        r_across, r_along = across_along(r, fixed)
        if j == k or not (r_across[0] <= beside <= r_across[1] and r_along[0] < hi and r_along[1] > lo):
            continue
        r_lo, r_hi = (r[0], r[1]) if r[4] == 0 else (r[2], r[3])
        if (0 if r[4] == 0 else 2) == fixed:  # rising across this side's line: level along it
            floors.append((r_along, _level(_rising(r, r_lo, r_hi)(beside)), min(r[5], r[6])))
        else:
            floors.append((r_along, _rising(r, r_lo, r_hi), min(r[5], r[6])))
    walls = []  # ((along from, to), bottom, top) of what stands against the side (a round one by its square)
    for b in block_geo:
        b_across, b_along = across_along(b, fixed)
        inner, outer = (b_across[0], b_across[1]) if out > 0 else (-b_across[1], -b_across[0])
        if b_along[0] < hi and b_along[1] > lo and outer > out * line and inner <= out * line + HOLD_GAP:
            walls.append((b_along, b[4], b[5]))
    rails = []  # ((along from, to), its deck's height) of each deck's railing along the side
    for on, a, b in rail_geo:
        if all(-1e-6 <= out * (e[fixed // 2] - line) <= HOLD_GAP for e in (a, b)):
            ends = sorted((a[1 - fixed // 2], b[1 - fixed // 2]))
            if ends[0] < hi and ends[1] > lo:
                rails.append((ends, plat_geo[on][4]))

    def state(v):
        """At v along the side: "held", a body walking off it there "steps" onto what is
        beside, or it is "open"."""
        t = tread(v)
        for (a, b), bottom, top in walls:
            if a <= v <= b and top > t + STEP and bottom < t + BODY_HEIGHT:
                return "held"
        for (a, b), deck in rails:
            if a <= v <= b and deck - STEP <= t < deck + RAIL_HEIGHT:
                return "held"
        for (a, b), deck in ledges:  # a deck's edge within a body's radius standing over its feet
            if a <= v <= b and t + STEP < deck < t + BODY_HEIGHT:
                return "held"
        steps = False
        for (a, b), height, base in floors:
            if a <= v <= b:
                h = height(v)
                if h > t + STEP and (h if base is None else base) < t + BODY_HEIGHT:
                    return "held"  # a deck's edge or a flight beside standing over its feet
                steps = steps or abs(h - t) <= STEP  # a floor, a landing or a flight within a step
        return "steps" if steps else "open"

    def is_open(v):
        return state(v) == "open"

    ends = [e for (a, b), *_rest in walls + rails + ledges + floors for e in (a, b) if lo < e < hi]

    def change(a, b):
        """Where between a and b, open at one and not at the other, that changes: at the end
        of what stands beside there, where one ends there."""
        state = is_open(a)
        for _ in range(30):
            m = (a + b) * 0.5
            a, b = (m, b) if is_open(m) == state else (a, m)
        return min(ends, key=lambda e: abs(e - b)) if any(abs(e - b) < 1e-3 for e in ends) else b

    count = max(1, math.ceil((hi - lo) / SIDE_SAMPLE - 1e-9))
    middles = [_lerp(lo, hi, (i + 0.5) / count) for i in range(count)]
    spans, begun = [], None
    for i, v in enumerate(middles):
        if is_open(v):
            begun = (lo if i == 0 else change(middles[i - 1], v)) if begun is None else begun
        elif begun is not None:
            spans.append((begun, change(middles[i - 1], v)))
            begun = None
    if begun is not None:
        spans.append((begun, hi))

    def drop(v):
        """How far a body walking off the side at v comes down: onto what is beside it there."""
        t = tread(v)
        under = [h for (a, b), height, _base in floors if a <= v <= b for h in [height(v)] if h <= t + STEP]
        return t - max(under) if under else math.inf

    def open_end(samples, end, way):
        """Where the way off the side by its end at end, onto what is beside it there, stops: a
        body's breadth along it, or sooner where a body walking off it would come down farther
        than it jumps back up (a flight beside going the other way)."""
        if state(samples[0]) != "steps":
            return end
        for v in samples:
            if (v - end) * way >= BREADTH:
                break
            if drop(v) > JUMP:
                return v
        return end + way * BREADTH

    # A way off its end onto what is beside it there stays a body's breadth wide.
    first = open_end(middles, lo, 1)
    last = open_end(middles[::-1], hi, -1)
    spans = [(max(a, first), min(b, last)) for a, b in spans]
    return [(a, b) for a, b in spans if b - a >= RAIL_LEAST], tread


def railing_openings(plat_geo, rail_geo):
    """Per railing span a body's breadth or longer: the plan its opening leaves, broken, from
    OPENING_INBOARD inboard of its line out a body's breadth and half a railing past it away from
    its deck, and the heights a body passes through it at, a step over its deck to a body's
    height (art-lint's open spans)."""
    out = []
    for on, a, b in rail_geo:
        if abs(b[0] - a[0]) + abs(b[1] - a[1]) < BREADTH:
            continue
        x0, x1, z0, z1, deck = plat_geo[on]
        if abs(a[0] - b[0]) < 1e-6:  # along z, at x = a[0]
            away = -1 if (x0 + x1) * 0.5 > a[0] else 1
            plan = (*sorted((a[0] - away * OPENING_INBOARD, a[0] + away * WELL_CLEAR)), *sorted((a[1], b[1])))
        else:
            away = -1 if (z0 + z1) * 0.5 > a[1] else 1
            plan = (*sorted((a[0], b[0])), *sorted((a[1] - away * OPENING_INBOARD, a[1] + away * WELL_CLEAR)))
        out.append((plan, deck + STEP, deck + BODY_HEIGHT))
    return out


def _standing(block_geo, g, bottom, top):
    """The boxes standing in the plan g between bottom and top."""
    return [q for q in block_geo if _overlap(q, g) and q[4] < top - 1e-3 and q[5] > bottom + 1e-3]


def rail_piece(plat_geo, ramp_geo, block_geo, k, fixed, line, out, p0, p1, t0, t1, openings):
    """Flight k's side rail from p0 to p1 along its side on line, outside it toward out, over
    its treads t0 to t1: (x0, x1, z0, z1, bottom, top), or None where none stands."""
    def plan(depth):
        side = sorted((line, line + out * depth))
        return (p0, p1, *side) if fixed == 2 else (*side, p0, p1)
    ranges = plan(PLATING)
    top = round(t1 + RAIL_HEIGHT, 4)
    # What a body under it stands on, and what one outside the flight within its radius of it does.
    side = sorted((line, line + out * (PLATING + HOLD_GAP)))
    near = (p0 - HOLD_GAP, p1 + HOLD_GAP, *side) if fixed == 2 else (*side, p0 - HOLD_GAP, p1 + HOLD_GAP)

    def floors(g):
        return ([q[4] for q in plat_geo if _overlap(q, g) and q[4] <= t0 + 1e-6],
                [h for j, r in enumerate(ramp_geo) if j != k and _overlap(r, g)
                 for h in [_highest(r, g)] if h <= t0 + 1e-6])
    decks, flights = floors(ranges)
    deck = max(decks, default=None)
    floor = max(sum(floors(near), []), default=None)
    # Hung from its treads, or a body's height over what is under it or by it where that is
    # higher: a body on that walks under it, and one on its treads is held by it.
    hung = t0 if floor is None else max(t0, math.ceil((floor + BODY_HEIGHT + HEAD_CLEAR) * 1e4) / 1e4)
    lowest = hung if deck is None else deck
    by_opening = any(_overlap(o, ranges) and lowest < high and top > low for o, low, high in openings)
    # The doorway the art heads under it is seen through across it: nothing stands in that.
    middle = line + out * PLATING * 0.5
    seen = sorted((middle - DOORWAY_PROBE, middle + DOORWAY_PROBE))
    seen = (p0, p1, *seen) if fixed == 2 else (*seen, p0, p1)
    if top - hung >= RAIL_LEAST and not by_opening and not _standing(block_geo, seen, lowest, hung):
        bottom, g = round(hung, 4), ranges
    elif deck is not None and all(h <= deck + 1e-6 for h in flights):
        # Standing on the deck, as a wall does: in the gap beside what stands against the flight
        # there, where it would stand on that (the art heads a doorway under what stands on a
        # wall), and on it where it stands flush with the flight's side.
        depth = PLATING
        for q in _standing(block_geo, ranges, deck, top):
            if q[5] <= top + 1e-6:
                q_across, _q_along = across_along(q, fixed)
                face = q_across[0] - line if out > 0 else line - q_across[1]
                if face >= RAIL_THIN:
                    depth = min(depth, face)
        bottom, g = deck, plan(round(depth, 4))
    else:
        return None
    # On what stands under it, under what stands over it: it runs through none.
    for _pass in range(2):
        for q in _standing(block_geo, g, bottom, top):
            if q[5] <= top:
                bottom = q[5]
            else:
                top = min(top, q[4])
    assert top - bottom >= RAIL_LEAST, "flight %d's side rail at %s stands in something" % (k, g)
    return (*g, bottom, top)


def rail_flight_sides(plat_geo, ramp_geo, block_geo, rail_geo, ramps, box):
    """Rails every open side of every flight in ramp_geo rising a step or more, through box()."""
    openings = railing_openings(plat_geo, rail_geo)
    for k, (rx0, rx1, rz0, rz1, axis, start, end) in enumerate(list(ramp_geo)):
        if abs(end - start) < STEP:
            continue
        rid = ramps[k][len("Ramp_"):]
        fixed = 2 if axis == 0 else 0  # her sides' lines: z = const for a flight along x
        across, (lo, hi) = across_along((rx0, rx1, rz0, rz1), fixed)
        for tag, out, line in (("lo", -1, across[0]), ("hi", 1, across[1])):
            spans, tread = side_open(plat_geo, ramp_geo, block_geo, rail_geo, k, fixed, line, out, lo, hi)
            for n, (a, b) in enumerate(spans):
                steps = math.ceil((b - a) / SIDE_STEP - 1e-9)
                for i in range(steps):
                    p0, p1 = round(_lerp(a, b, i / steps), 4), round(_lerp(a, b, (i + 1) / steps), 4)
                    t0, t1 = sorted((tread(p0), tread(p1)))
                    piece = rail_piece(plat_geo, ramp_geo, block_geo, k, fixed, line, out, p0, p1, t0, t1, openings)
                    if piece is not None:
                        # "side_": the art heads no doorway under one (ShipArt.FLIGHT_SIDE_RAIL).
                        box("side_%s_%s%d_%d" % (rid, tag, n, i), *piece)
