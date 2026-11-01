"""The Titanic's decks as her plates draw them, in ship metres (#360): the plain-Python
half of the tracing kit. tools/gen_titanic.py reads every traced deck through it, so it
needs nothing beyond Python itself — `make ship-gen-check` runs it in CI.

Each deck is a file beside this one (boat.py, …): its plate, its view's crop, its
calibration, and every piece in the plate's own pixels as read. Plate x runs toward her
bow and plate y to starboard. The calibration turns pixels into metres:

    X   [(plate x, ship x in metres, what both are), …]: ship x read linearly between
        the two nearest; past the last, along the nearest two's line.
    Z   dict(centre=((plate x, plate y), (plate x, plate y)), scale=metres a pixel):
        ship z is the plate y's distance from the centre line drawn through the two
        points, at scale. The scans are not scaled alike along her and across her, so Z
        has a scale of its own, read off her breadth.

A deck's pieces, each a rectangle (x0, y0, x1, y1) in plate pixels unless said:

    ROOMS   [(name, x0, y0, x1, y1), …]: a room to its walls' middles. Its edges are its
            walls, but where OPEN says not or a SOLID stands along them.
    SOLIDS  [(what, x0, y0, x1, y1, height or None), …]: a block nobody enters — a casing,
            a shaft, a closet narrower than a body — to the deck above (None) or height
            metres over the deck.
    RAISED  [(name, x0, y0, x1, y1, height), …]: a floor height metres over the deck: a
            raised roof walked on.
    HOUSES  [(name, x0, y0, x1, y1), …]: a house on an open deck, on its outer walls'
            middles: what the generator roofs over and makes a cell of.
    DOORS   [(x, y), …]: a door's middle, on a room's edge, where the plate draws its
            swing.
    OPEN    [(x0, y0, x1, y1), …]: stretches of rooms' edges with no wall: two rooms
            that are one space, as a corridor's turns are.
    STAIRS  [(name, x0, y0, x1, y1, rises, lower, upper), …]: a flight over the
            rectangle, rising toward rises ("fore", "aft", "port" or "starboard") from
            the deck called lower to the one called upper.

Rooms snap to shared lines: edges within SNAP pixels of each other are one wall.

A deck drawn in more than one view — B deck, on Plate IV and on both pages of The
Shipbuilder's 1912 plan of the Titanic's — is a file naming its parts:

    PARTS   [name, …]: each a deck file of its own (PLATE, CROP, X, Z and its pieces),
            read in its own view's pixels, the deck the parts joined in metres (JOIN).
"""
import importlib.util
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Edges this close, in plate pixels, are one line: the ink of a wall is ~5 px wide, and
# two rooms read either side of it differ by about that.
SNAP = 6.0
# The grain a traced number is kept to, in metres: a sixteenth, which single precision
# holds exactly at her lengths, so a stair's end and the deck it meets, read off the same
# pixel, meet in Godot's Rect2 too (the generators' joins()); finer than the plates read.
GRAIN = 0.0625
# The narrowest a passage or a corridor is laid, between its walls' middles: a body's
# door (1 m, the layout lint's least) and its panelling either side, to the grain. The
# plates' tandem passages are 0.8-1 m: they take what they lack from the rooms beside them.
WAY_LEAST = 1.125
# The rooms a cabin's door opens onto when the plate's swing is not given: a room whose
# name holds one of these.
PASSAGES = ("passage", "corridor", "entrance", "lobby", "staircase")
# How far apart, in metres, two views' readings of one wall may stand and still be
# joined onto one line: each view is calibrated on its own, good to about 0.2 m.
JOIN = 0.3
# An outer wall this near her side, in metres, is her side's (Deck's side).
SIDE_REACH = 0.3
BODY_WIDTH = 0.8
DOOR_CLEAR = 1.0 + 2 * 0.03  # the lint's least door, between two partitions' faces
# A piece's end this near a deck's end over it, in metres, is that end's (Deck's ends),
# unless the load gives a reach of its own.
END_REACH = 0.2


def _module(name):
    spec = importlib.util.spec_from_file_location("titanic_deck_" + name, HERE / ("%s.py" % name))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def kept(v):
    return round(round(v / GRAIN) * GRAIN, 4)


class View:
    """A deck's view on its plate: plate pixels to ship metres."""

    def __init__(self, x_controls, z):
        self.controls = sorted((px, metres) for px, metres, _what in x_controls)
        assert len(self.controls) >= 2, "a view needs two x controls"
        (cx0, cy0), (cx1, cy1) = z["centre"]
        self.centre = (cx0, cy0, (cy1 - cy0) / float(cx1 - cx0))
        self.z_scale = z["scale"]

    def x(self, px):
        c = self.controls
        k = 1
        while k < len(c) - 1 and px > c[k][0]:
            k += 1
        (p0, m0), (p1, m1) = c[k - 1], c[k]
        return m0 + (px - p0) * (m1 - m0) / float(p1 - p0)

    def z(self, px, py):
        cx0, cy0, slope = self.centre
        return (py - (cy0 + (px - cx0) * slope)) * self.z_scale

    def px(self, x):
        """The plate x of ship x: x()'s inverse."""
        c = self.controls
        k = 1
        while k < len(c) - 1 and x > c[k][1]:
            k += 1
        (p0, m0), (p1, m1) = c[k - 1], c[k]
        return p0 + (x - m0) * (p1 - p0) / float(m1 - m0)

    def py(self, px, z):
        """The plate y of ship z at plate x px: z()'s inverse."""
        cx0, cy0, slope = self.centre
        return cy0 + (px - cx0) * slope + z / self.z_scale

    def rect(self, x0, y0, x1, y1):
        """A plate rectangle as ship (x0, x1, z0, z1), its z read at its middle's x."""
        mid = (x0 + x1) * 0.5
        a, b = sorted((self.x(x0), self.x(x1)))
        c, d = sorted((self.z(mid, y0), self.z(mid, y1)))
        return kept(a), kept(b), kept(c), kept(d)


def _passage(name):
    return any(word in name for word in PASSAGES)


def _lines(values):
    """Plate values within SNAP of each other, each mapped to their group's mean."""
    groups = []
    for v in sorted(values):
        if groups and v - groups[-1][-1] <= SNAP:
            groups[-1].append(v)
        else:
            groups.append([v])
    mapped = {}
    for group in groups:
        mean = sum(group) / len(group)
        for v in group:
            mapped[v] = mean
    return mapped


class Deck:
    """One traced deck in ship metres: rooms, walls, doors, solids, raised floors, stairs.

    Every rectangle is (x0, x1, z0, z1). Walls are (axis, at, from, to, kind, doors):
    axis 0 a wall across her at x = at from z from to z to, axis 2 one along her at
    z = at; kind "steel" where it faces the open deck or a solid, else "partition";
    doors the (from, to) of each door in it, along it.

    A deck drawn in more views than one names them in PARTS, each a file of its own in
    its view's pixels (b.py's): every part read as a deck of its own is, then its pieces
    joined in metres, the edges two parts read of one wall moved onto one line (JOIN).

    side, when given, is her half breadth a room's outer wall's middle may take from x0
    to x1, side(x0, x1): every room, solid, raised floor and house reaching it, or within
    SIDE_REACH of it, is held to it — her side as the generator lays her hull, inside
    the deck's own edge.

    ends, when given, are lines across her (ship x) a piece's end within reach (END_REACH
    unless given) of is held to: where the generator ends a deck over this one — a deck's
    front over the rooms under it, read off another view — so the rooms under it end
    where it does; or where it parts her water into cells, so a room ends where its cell
    does. Given lead too, a room's end past one of them by less than lead is pushed out
    to lead from it: the generator splits a room the line runs through (its cells part
    there), and each part keeps a body's step into it."""

    def __init__(self, name, side=None, ends=(), reach=END_REACH, lead=0.0):
        module = _module(name)
        self.name = name
        if hasattr(module, "PARTS"):
            parts = [_Part(p, _module(p), widen=False) for p in module.PARTS]
        else:
            parts = [_Part(name, module)]
        self.parts = parts
        self.plate = parts[0].plate
        self.view = parts[0].view if len(parts) == 1 else None
        self.rooms = [r for p in parts for r in p.rooms]
        self.solids = [s for p in parts for s in p.solids]
        self.raised = [r for p in parts for r in p.raised]
        self.houses = [h for p in parts for h in p.houses]
        self.decks = [d for p in parts for d in p.decks]
        self.doors = [d for p in parts for d in p.doors]
        self.stairs = [s for p in parts for s in p.stairs]
        if len(parts) > 1:
            self._join(parts)
        self._nudged(module)
        if ends:
            self._ended(ends, reach, lead)
        if side is not None:
            self._held(side)
        self.open = [self._shared(o) for p in parts for o in p.open] + list(getattr(module, "OPENED", ()))
        if lead:
            self._alcoves()
        self.walls = self._walls()

    def _nudged(self, module):
        """NUDGES, a deck file's lines moved so a door fits where the plate's rooms leave it
        under DOOR_LEAST: (axis, at, to, lo, hi), the end of every piece at x (axis 0) or z
        (axis 2) at, overlapping lo..hi the other way, moved to to. DOOR_MOVES, each door
        (x, z) moved to (x, z) likewise, or gone with its room (None).
        SHUT, the open join at each (x, z) walled. MADE_SOLID, the room at each (x, z) a
        solid block, too small for a door. STAIR_MOVES, each flight (name, x0, z0) laid over
        (x0, x1, z0, z1) instead, off the plate so its foot finds a floor. OPENED, a join
        (x0, x1, z0, z1) a landing's way in needs, just so long. NOT_ROOMS, each (x, z) in a well and no
        room once her cells have split it, its flight taking all a body could stand on
        behind its door: its walls stay, its floor is no room's. GONE, the room or solid at
        each (x, z) her hull takes, walls and all. WALLED_SOLIDS, a
        solid at each (x, z) whose face only touches a room's edge, the edge walled."""
        for axis, at, to, lo, hi in getattr(module, "NUDGES", ()):
            found = False
            for list_name in ("rooms", "solids"):
                pieces = getattr(self, list_name)
                for k, p in enumerate(pieces):
                    x0, x1, z0, z1 = p[1:5]
                    if axis == 0 and z0 < hi and z1 > lo and at in (x0, x1):
                        x0, x1 = (to if x0 == at else x0), (to if x1 == at else x1)
                    elif axis == 2 and x0 < hi and x1 > lo and at in (z0, z1):
                        z0, z1 = (to if z0 == at else z0), (to if z1 == at else z1)
                    else:
                        continue
                    pieces[k] = p[:1] + (x0, x1, z0, z1) + p[5:]
                    found = True
            assert found, ("a nudge moves nothing", axis, at)
            for part in self.parts:
                for k, (x0, x1, z0, z1) in enumerate(part.open):
                    if axis == 0 and x1 - x0 < z1 - z0 and abs((x0 + x1) * 0.5 - at) < 0.2 and z0 < hi and z1 > lo:
                        part.open[k] = (x0 + to - at, x1 + to - at, z0, z1)
                    elif axis == 2 and x1 - x0 >= z1 - z0 and abs((z0 + z1) * 0.5 - at) < 0.05 and x0 < hi and x1 > lo:
                        part.open[k] = (x0, x1, z0 + to - at, z1 + to - at)
            for k, (x, z) in enumerate(self.doors):
                if axis == 0 and abs(x - at) < 0.3 and lo < z < hi:
                    self.doors[k] = (x + to - at, z)
                elif axis == 2 and abs(z - at) < 0.3 and lo < x < hi:
                    self.doors[k] = (x, z + to - at)
        for (name, x0, z0), new in getattr(module, "STAIR_MOVES", ()):
            k = next(i for i, s in enumerate(self.stairs) if s[:2] == (name, x0) and s[3] == z0)
            # (x0, x1, z0, z1), and the way it rises where that changes.
            self.stairs[k] = self.stairs[k][:1] + new[:4] + new[4:] + self.stairs[k][5 + len(new[4:]):]
        for old, new in getattr(module, "DOOR_MOVES", ()):
            if old is None:
                self.doors.append(new)
                continue
            near = min(self.doors, key=lambda d: abs(d[0] - old[0]) + abs(d[1] - old[1]))
            assert abs(near[0] - old[0]) + abs(near[1] - old[1]) < 0.2, ("no such door", old)
            self.doors.remove(near)
            if new is not None:
                self.doors.append(new)
        for x, z in getattr(module, "SHUT", ()):
            for part in self.parts:
                kept = [o for o in part.open if not (o[0] - 0.3 < x < o[1] + 0.3 and o[2] - 0.3 < z < o[3] + 0.3)]
                assert len(kept) < len(part.open) or len(self.parts) > 1, ("no such open join", x, z)
                part.open[:] = kept
        for x, z in getattr(module, "MADE_SOLID", ()):
            self._solid(next(r for r in self.rooms if r[1] < x < r[2] and r[3] < z < r[4]))
        # AWAITS, the stretches (x0, x1) whose solids wait for the spaces under them to be laid.
        for x0, x1 in getattr(module, "AWAITS", ()):
            self.solids[:] = [s for s in self.solids if not x0 < (s[1] + s[2]) * 0.5 < x1]
        for x, z in getattr(module, "GONE", ()):
            pieces = self.rooms if any(r[1] < x < r[2] and r[3] < z < r[4] for r in self.rooms) else self.solids
            pieces.remove(next(r for r in pieces if r[1] < x < r[2] and r[3] < z < r[4]))
        self.not_rooms = list(getattr(module, "NOT_ROOMS", ()))
        self.walled_solids = list(getattr(module, "WALLED_SOLIDS", ()))

    def _join(self, parts):
        """The lines two parts read of one wall moved onto one: of each kind, lines of
        different parts within JOIN of each other that touch along their length take the
        mean of the parts' readings, each part's once, and every edge on them with it. A
        part reading two lines of one wall (another part's line touching both) is a trace
        to fix, and is refused. Then each passage or corridor narrower than WAY_LEAST is
        widened on the joined lines, as a deck of one view's are in its own (_snapped)."""
        lists = ("rooms", "solids", "raised", "houses")
        offsets = {}  # (part, list name) -> where the part's pieces start in the deck's list
        for list_name in lists:
            at = 0
            for p_index, p in enumerate(parts):
                offsets[(p_index, list_name)] = at
                at += len(getattr(p, list_name))
        lines = [(p_index,) + line for p_index, p in enumerate(parts) for line in p.lines]
        parent = list(range(len(lines)))

        def root(k):
            while parent[k] != k:
                parent[k] = parent[parent[k]]
                k = parent[k]
            return k

        # each line: (part, kind, value, lo, hi, [(list name, index, slot)])
        order = sorted(range(len(lines)), key=lambda k: (lines[k][1], lines[k][2]))
        for i, a in enumerate(order):
            for b in order[i + 1:]:
                if lines[b][1] != lines[a][1] or lines[b][2] - lines[a][2] > JOIN:
                    break
                if lines[a][0] == lines[b][0]:
                    continue
                if lines[b][3] <= lines[a][4] + JOIN and lines[a][3] <= lines[b][4] + JOIN:
                    parent[root(b)] = root(a)
        groups = {}
        for k in range(len(lines)):
            groups.setdefault(root(k), []).append(k)
        value_of, line_of = {}, {}  # a joined line's value; (list, deck index, slot) -> its line
        for g, members in groups.items():
            readings = {}
            for k in members:
                readings.setdefault(lines[k][0], set()).add(lines[k][2])
            for p_index, values in readings.items():
                assert len(values) == 1, "deck %s: part %s reads %s as one wall's line" % (
                    self.name, parts[p_index].name, sorted(values))
            value_of[g] = kept(sum(next(iter(v)) for v in readings.values()) / len(readings))
            for k in members:
                for list_name, index, slot in lines[k][5]:
                    line_of[(list_name, offsets[(lines[k][0], list_name)] + index, slot)] = g
        # Each passage's two sides across it; a side two passages share — one either side of
        # it — is held, and the passage widened from its other side alone.
        narrow = {}
        for index, room in enumerate(self.rooms):
            if _passage(room[0]):
                ends = [line_of[("rooms", index, slot)] for slot in (1, 2, 3, 4)]
                x0, x1, z0, z1 = (value_of[g] for g in ends)
                narrow[index] = (ends[0], ends[1]) if abs(x1 - x0) < abs(z1 - z0) else (ends[2], ends[3])
        shared = {}
        for low, high in narrow.values():
            for g in (low, high):
                shared[g] = shared.get(g, 0) + 1
        for index, (low, high) in narrow.items():
            if value_of[low] > value_of[high]:
                low, high = high, low
            width = value_of[high] - value_of[low]
            if width < WAY_LEAST - 1e-6:
                grow = math.ceil((WAY_LEAST - width) / 2 / GRAIN - 1e-9) * GRAIN
                if shared[high] > 1 and shared[low] == 1:
                    value_of[low] = kept(value_of[low] - 2 * grow)
                elif shared[low] > 1 and shared[high] == 1:
                    value_of[high] = kept(value_of[high] + 2 * grow)
                else:
                    value_of[low], value_of[high] = kept(value_of[low] - grow), kept(value_of[high] + grow)
        for list_name in lists:
            pieces = getattr(self, list_name)
            for index, piece in enumerate(pieces):
                piece = list(piece)
                for slot in (1, 2, 3, 4):
                    piece[slot] = value_of[line_of[(list_name, index, slot)]]
                x0, x1, z0, z1 = piece[1:5]
                piece[1:5] = [min(x0, x1), max(x0, x1), min(z0, z1), max(z0, z1)]
                pieces[index] = tuple(piece)

    def _ended(self, ends, reach, lead):
        """Every piece's end within reach of one of ends held to it, and a room's end past
        one by less than lead (and more than reach) pushed out to lead from it — each a
        line across her, every piece's end on it moved with it. An OPEN across her on a
        line held to an end moves with it, so it still finds the two rooms it joins
        (_shared), and a door in its end too."""
        pushed = {}
        for room in self.rooms if lead else ():
            for e in ends:
                if room[1] + 1e-6 < e < room[2] - 1e-6:
                    if reach < e - room[1] < lead:
                        pushed[room[1]] = e - lead
                    if reach < room[2] - e < lead:
                        pushed[room[2]] = e + lead

        def held(v):
            if v in pushed:
                return pushed[v]
            near = min(ends, key=lambda e: abs(e - v))
            return near if abs(near - v) <= reach else v

        # A door in a room's end moves with it, so it still finds its wall (_walls).
        for k, (x, z) in enumerate(self.doors):
            ends_at = [v for r in self.rooms if r[3] + 0.05 < z < r[4] - 0.05 for v in (r[1], r[2]) if abs(v - x) < 0.3]
            if ends_at:
                v = min(ends_at, key=lambda e: abs(e - x))
                self.doors[k] = (x + held(v) - v, z)
        for list_name in ("rooms", "solids", "raised", "houses"):
            pieces = getattr(self, list_name)
            for k, piece in enumerate(pieces):
                pieces[k] = piece[:1] + (held(piece[1]), held(piece[2])) + piece[3:]
        self.rooms = [r for r in self.rooms if r[2] - r[1] > 0.1]
        for part in self.parts:
            for k, (x0, x1, z0, z1) in enumerate(part.open):
                if x1 - x0 < z1 - z0:
                    shift = held((x0 + x1) * 0.5) - (x0 + x1) * 0.5
                    part.open[k] = (x0 + shift, x1 + shift, z0, z1)

    def _held(self, side):
        """Every piece reaching her side, or within SIDE_REACH of it, held to it."""
        for list_name in ("rooms", "solids", "raised", "houses"):
            pieces = getattr(self, list_name)
            for k, piece in enumerate(pieces):
                x0, x1, z0, z1 = piece[1:5]
                half = side(x0, x1)
                if z0 < -(half - SIDE_REACH):
                    z0 = -half
                if z1 > half - SIDE_REACH:
                    z1 = half
                pieces[k] = piece[:1] + (x0, x1, z0, z1) + piece[5:]
        # A room her side leaves narrower than a body is no room but a solid block, its
        # doors gone with it (#360: "a space narrower than a body").
        # (And what her side leaves nothing of is gone.)
        self.rooms = [r for r in self.rooms if r[4] - r[3] > 0.1]
        self.solids = [r for r in self.solids if r[4] - r[3] > 0.1]
        for room in [r for r in self.rooms if r[4] - r[3] < BODY_WIDTH]:
            self._solid(room)

    def _solid(self, room):
        """A room made a solid block to the deck over it, the doors on its edges gone."""
        self.rooms.remove(room)
        self.solids.append((room[0], room[1], room[2], room[3], room[4], None))
        _n, x0, x1, z0, z1 = room
        self.doors = [(x, z) for x, z in self.doors if not (
            (min(abs(x - x0), abs(x - x1)) < 0.3 and z0 + 0.05 < z < z1 - 0.05)
            or (min(abs(z - z0), abs(z - z1)) < 0.3 and x0 + 0.05 < x < x1 - 0.05))]

    def _alcoves(self):
        """A piece of a room opening into the rest of it through less than a door's width,
        all its width (DOOR_CLEAR): no body's way in, so a solid, as the plates' narrow
        closets are, and its OPEN goes with it (#360: "its notch becomes a closet")."""
        for opening in list(self.open):
            x0, x1, z0, z1 = opening
            across = (x1 - x0) < (z1 - z0)
            lo, hi = (z0, z1) if across else (x0, x1)
            if hi - lo >= DOOR_CLEAR:
                continue
            line = (x0 + x1) * 0.5 if across else (z0 + z1) * 0.5
            near = []
            for r in self.rooms:
                ends, a, b = ((r[1], r[2]), r[3], r[4]) if across else ((r[3], r[4]), r[1], r[2])
                if not _passage(r[0]) and min(abs(e - line) for e in ends) < 0.02 and abs(a - lo) < 0.02 and abs(b - hi) < 0.02:
                    near.append(r)
            if near:
                self._solid(min(near, key=lambda r: (r[2] - r[1]) * (r[4] - r[3])))
                self.open.remove(opening)

    def _shared(self, opening):
        """An OPEN rectangle as the whole stretch of edge the two rooms it joins share, on
        their snapped line: a passage widened for a body opens all of its mouth. Of the
        pairs of rooms on its line, the one whose shared stretch it lies along the furthest
        — an OPEN read a little past a room's corner runs on along the next pair's edge
        for a few pixels, which no join is — then the nearest its middle."""
        x0, x1, z0, z1 = opening
        across = (x1 - x0) < (z1 - z0)
        mid = (x0 + x1) * 0.5 if across else (z0 + z1) * 0.5
        lo, hi = (z0, z1) if across else (x0, x1)
        best = None
        for r in self.rooms:
            for s in self.rooms:
                ra, sa = (r[2], s[1]) if across else (r[4], s[3])
                if r is s or abs(ra - sa) > 1e-6 or abs(ra - mid) > 0.2:
                    continue
                a, b = (max(r[3], s[3]), min(r[4], s[4])) if across else (max(r[1], s[1]), min(r[2], s[2]))
                along = min(b, hi) - max(a, lo)
                if b - a > 1e-6 and along > 0 and (
                        best is None or (along, -abs(ra - mid)) > (best[3], -abs(best[0] - mid))):
                    best = (ra, a, b, along)
        if best is None:
            return opening
        line, a, b, _along = best
        return (line - 0.01, line + 0.01, a, b) if across else (a, b, line - 0.01, line + 0.01)

    def _covered(self, axis, at, a, b, boxes):
        """The stretches of the line (axis, at) from a to b along that some box's side lies on."""
        out = []
        for x0, x1, z0, z1 in boxes:
            sides = (x0, x1) if axis == 0 else (z0, z1)
            lo, hi = (z0, z1) if axis == 0 else (x0, x1)
            if any(abs(s - at) < 1e-6 for s in sides) and hi > a and lo < b:
                out.append((max(lo, a), min(hi, b)))
        return out

    def _walls(self):
        """Every room's edges as walls, merged where rooms share them, less the open
        stretches and a solid's sides; steel where only one room has the edge."""
        edges = {}  # (axis, at) -> [(from, to, room index)]
        for k, (_name, x0, x1, z0, z1) in enumerate(self.rooms):
            for axis, at, a, b in [(0, x0, z0, z1), (0, x1, z0, z1), (2, z0, x0, x1), (2, z1, x0, x1)]:
                edges.setdefault((axis, at), []).append((a, b, k))
        solid_boxes = [s[1:5] for s in self.solids
                       if not any(s[1] < x < s[2] and s[3] < z < s[4] for x, z in self.walled_solids)]
        walls = []
        for (axis, at), spans in sorted(edges.items()):
            cuts = sorted({v for a, b, _k in spans for v in (a, b)})
            for a, b in zip(cuts, cuts[1:]):
                owners = [k for lo, hi, k in spans if lo <= a and hi >= b]
                if not owners:
                    continue
                gaps = self._covered(axis, at, a, b, solid_boxes) + [
                    (max(lo, a), min(hi, b)) for lo, hi in self._open_on(axis, at) if hi > a and lo < b]
                for s0, s1 in _minus(a, b, gaps):
                    kind = "partition" if len(owners) > 1 else "steel"
                    walls.append([axis, at, s0, s1, kind, []])
        walls = _joined(walls)
        for x, z in self.doors + self._auto_doors(walls):
            best = None
            for wall in walls:
                axis, at, a, b = wall[:4]
                along, across = (z, x) if axis == 0 else (x, z)
                if a - 0.05 <= along <= b + 0.05:
                    d = abs(across - at)
                    if best is None or d < best[0]:
                        best = (d, wall, along)
            assert best is not None and best[0] < 0.3, "deck %s: no wall under the door at %s" % (self.name, (x, z))
            best[1][5].append(best[2])
        return [tuple(w) for w in walls]

    def _auto_doors(self, walls):
        """A door for each room DOORS gives none: in the longest stretch of wall it shares
        with a passage or corridor, at that stretch's middle — where the plates draw a
        cabin's door. A room that shares none keeps none, and the lint says so."""
        def edges_of(room):
            _name, x0, x1, z0, z1 = room
            return [(0, x0, z0, z1), (0, x1, z0, z1), (2, z0, x0, x1), (2, z1, x0, x1)]

        def on_edge(x, z, room):
            for axis, at, a, b in edges_of(room):
                along, across = (z, x) if axis == 0 else (x, z)
                if abs(across - at) < 0.3 and a - 0.05 <= along <= b + 0.05:
                    return True
            return False

        ways = [r for r in self.rooms if _passage(r[0])]
        solid_boxes = [s[1:5] for s in self.solids]
        out = []
        for room in self.rooms:
            if _passage(room[0]) or any(on_edge(x, z, room) for x, z in self.doors):
                continue
            best = None
            for axis, at, a, b in edges_of(room):
                for way in ways:
                    for w_axis, w_at, w_a, w_b in edges_of(way):
                        if w_axis != axis or abs(w_at - at) > 1e-6:
                            continue
                        # Of the edge they share, the stretches no solid's side stands on
                        # and no OPEN opens: an open edge is no wall for a door.
                        s0, s1 = max(a, w_a), min(b, w_b)
                        gaps = self._covered(axis, at, s0, s1, solid_boxes) + [
                            (max(o0, s0), min(o1, s1)) for o0, o1 in self._open_on(axis, at) if o1 > s0 and o0 < s1]
                        for lo, hi in _minus(s0, s1, gaps):
                            if hi - lo > 0.9 and (best is None or hi - lo > best[0]):
                                mid = (lo + hi) * 0.5
                                best = (hi - lo, (at, mid) if axis == 0 else (mid, at))
            if best is not None:
                out.append(best[1])
        return out

    def _open_on(self, axis, at):
        """The open stretches of the line (axis, at): an OPEN rectangle drops only the wall
        it runs along — a thin one across her the wall across her it lies on — never the
        ends of the walls that run into its mouth."""
        out = []
        for x0, x1, z0, z1 in self.open:
            across = (x1 - x0) < (z1 - z0)
            if axis == 0 and across and x0 - 0.05 <= at <= x1 + 0.05:
                out.append((z0, z1))
            if axis == 2 and not across and z0 - 0.05 <= at <= z1 + 0.05:
                out.append((x0, x1))
        return out


class _Part:
    """One view of a deck: its pieces in ship metres, read through the view's calibration
    and snapped to its own lines in its own pixels."""

    def __init__(self, name, module, widen=True):
        self.name = name
        self.plate = module.PLATE
        self.view = View(module.X, module.Z)
        rooms = list(getattr(module, "ROOMS", []))
        solids = list(getattr(module, "SOLIDS", []))
        raised = list(getattr(module, "RAISED", []))
        houses = list(getattr(module, "HOUSES", []))
        boxes = [r[1:5] for r in rooms] + [s[1:5] for s in solids] + [r[1:5] for r in raised] + [h[1:5] for h in houses]
        n_rooms, n_solids, n_raised = len(rooms), len(solids), len(raised)
        self._counts = (n_rooms, n_solids, n_raised)
        # A part of a deck of several views leaves its passages' widening to the deck.
        metres = self._snapped(boxes, [k for k, r in enumerate(rooms) if _passage(r[0])] if widen else [])
        self.rooms = [(r[0],) + metres[k] for k, r in enumerate(rooms)]
        self.solids = [(s[0],) + metres[n_rooms + k] + (s[5],) for k, s in enumerate(solids)]
        self.raised = [(r[0],) + metres[n_rooms + n_solids + k] + (r[5],) for k, r in enumerate(raised)]
        self.houses = [(h[0],) + metres[n_rooms + n_solids + n_raised + k] for k, h in enumerate(houses)]
        # The deck's own pieces: (x0, x1, z0, z1), z None for her whole breadth there.
        self.decks = []
        for x0, y0, x1, y1 in getattr(module, "DECKS", []):
            a, b = sorted((kept(self.view.x(x0)), kept(self.view.x(x1))))
            if y0 is None:
                self.decks.append((a, b, None, None))
            else:
                mid = (x0 + x1) * 0.5
                c, d = sorted((kept(self.view.z(mid, y0)), kept(self.view.z(mid, y1))))
                self.decks.append((a, b, c, d))
        self.doors = [(kept(self.view.x(x)), kept(self.view.z(x, y))) for x, y in getattr(module, "DOORS", [])]
        # OPEN as ship rectangles; the deck takes each as the edge its rooms share (_shared).
        self.open = [self.view.rect(*o) for o in getattr(module, "OPEN", [])]
        self.stairs = [(stair_name,) + self.view.rect(x0, y0, x1, y1) + (rises, lower, upper)
                       for stair_name, x0, y0, x1, y1, rises, lower, upper in getattr(module, "STAIRS", [])]

    def _owner(self, box):
        """The list and index of box, by its place among the rooms, solids, raised floors
        and houses."""
        n_rooms, n_solids, n_raised = self._counts
        for name, count in (("rooms", n_rooms), ("solids", n_solids), ("raised", n_raised)):
            if box < count:
                return (name, box)
            box -= count
        return ("houses", box)

    def _snapped(self, boxes, ways=()):
        """Each plate box (x0, y0, x1, y1) as ship (x0, x1, z0, z1), its edges snapped to
        the lines they share: two edges of one kind within SNAP px of each other that
        touch along their length are one wall's two readings, and take its mean. A line
        along her is read in ship z at its own middle, so a centre line tilted over the
        scan bends no wall. Each box of ways — a passage or a corridor — narrower across
        than WAY_LEAST between its walls' middles has its two sides moved apart to it, and
        every edge on either side's line with it: the rooms beside it give up the width."""
        edges = []  # [kind, value, lo, hi]: kind "x" an edge at plate x = value, "y" at plate y
        for x0, y0, x1, y1 in boxes:
            edges += [["x", x0, y0, y1], ["x", x1, y0, y1], ["y", y0, x0, x1], ["y", y1, x0, x1]]
        parent = list(range(len(edges)))

        def root(k):
            while parent[k] != k:
                parent[k] = parent[parent[k]]
                k = parent[k]
            return k

        order = sorted(range(len(edges)), key=lambda k: (edges[k][0], edges[k][1]))
        for i, a in enumerate(order):
            for b in order[i + 1:]:
                if edges[b][0] != edges[a][0] or edges[b][1] - edges[a][1] > SNAP:
                    break
                if edges[b][2] <= edges[a][3] + SNAP and edges[a][2] <= edges[b][3] + SNAP:
                    parent[root(b)] = root(a)
        groups = {}
        for k in range(len(edges)):
            groups.setdefault(root(k), []).append(k)
        ship = {}
        for members in groups.values():
            value = sum(edges[k][1] for k in members) / len(members)
            lo = min(edges[k][2] for k in members)
            hi = max(edges[k][3] for k in members)
            if edges[members[0]][0] == "x":
                v = kept(self.view.x(value))
            else:
                v = kept(self.view.z((lo + hi) * 0.5, value))
            for k in members:
                ship[k] = v
        for k in ways:
            x0, x1, z0, z1 = ship[4 * k], ship[4 * k + 1], ship[4 * k + 2], ship[4 * k + 3]
            low, high = (4 * k, 4 * k + 1) if abs(x1 - x0) < abs(z1 - z0) else (4 * k + 2, 4 * k + 3)
            width = abs(ship[high] - ship[low])
            if width < WAY_LEAST - 1e-6:
                grow = math.ceil((WAY_LEAST - width) / 2 / GRAIN - 1e-9) * GRAIN
                for side, by in [(low, -grow), (high, grow)]:
                    line = ship[side]
                    for m in groups[root(side)]:
                        ship[m] = kept(line + by)
        out = []
        for k in range(len(boxes)):
            x0, x1, y0, y1 = ship[4 * k], ship[4 * k + 1], ship[4 * k + 2], ship[4 * k + 3]
            out.append((min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1)))
        # Its lines, for a deck of several parts to join (Deck._join): (kind, value, from,
        # to, [(list, index, slot)]), from and to along the line in ship metres.
        self.lines = []
        for members in groups.values():
            kind = "x" if edges[members[0]][0] == "x" else "z"
            value = ship[members[0]]
            lo = min(edges[k][2] for k in members)
            hi = max(edges[k][3] for k in members)
            if kind == "x":
                px = sum(edges[k][1] for k in members) / len(members)
                ends = sorted((self.view.z(px, lo), self.view.z(px, hi)))
            else:
                ends = sorted((self.view.x(lo), self.view.x(hi)))
            slots = []
            for k in members:
                box = k // 4
                x0, x1, z0, z1 = out[box]
                first = (x0, z0)[(k % 4) // 2]
                slot = 1 + 2 * ((k % 4) // 2) + (0 if abs(ship[k] - first) < 1e-9 else 1)
                slots.append(self._owner(box) + (slot,))
            self.lines.append((kind, value, ends[0], ends[1], slots))
        return out


def _minus(a, b, gaps):
    spans, at = [], a
    for g0, g1 in sorted(gaps):
        if g0 > at:
            spans.append((at, g0))
        at = max(at, g1)
    if at < b:
        spans.append((at, b))
    return [(s0, s1) for s0, s1 in spans if s1 - s0 > 0.02]


def _joined(walls):
    """Touching stretches of one line and one kind joined."""
    walls.sort(key=lambda w: (w[0], w[1], w[2]))
    out = []
    for w in walls:
        if out and out[-1][0] == w[0] and out[-1][1] == w[1] and out[-1][4] == w[4] and abs(out[-1][3] - w[2]) < 1e-6:
            out[-1][3] = w[3]
        else:
            out.append(w)
    return out


def load(name, side=None, ends=(), reach=END_REACH, lead=0.0):
    return Deck(name, side, ends, reach, lead)
