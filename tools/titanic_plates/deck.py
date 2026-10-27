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
    DOORS   [(x, y), …]: a door's middle, on a room's edge, where the plate draws its
            swing.
    OPEN    [(x0, y0, x1, y1), …]: stretches of rooms' edges with no wall: two rooms
            that are one space, as a corridor's turns are.
    STAIRS  [(name, x0, y0, x1, y1, rises, lower, upper), …]: a flight over the
            rectangle, rising toward rises ("fore", "aft", "port" or "starboard") from
            the deck called lower to the one called upper.

Rooms snap to shared lines: edges within SNAP pixels of each other are one wall.
"""
import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Edges this close, in plate pixels, are one line: the ink of a wall is ~5 px wide, and
# two rooms read either side of it differ by about that.
SNAP = 6.0
# The grain a traced number is kept to, in metres.
GRAIN = 0.01
# The rooms a cabin's door opens onto when the plate's swing is not given: a room whose
# name holds one of these.
PASSAGES = ("passage", "corridor", "entrance", "lobby")


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
    doors the (from, to) of each door in it, along it."""

    def __init__(self, name):
        module = _module(name)
        self.name = name
        self.plate = module.PLATE
        self.view = View(module.X, module.Z)
        rooms = list(getattr(module, "ROOMS", []))
        solids = list(getattr(module, "SOLIDS", []))
        raised = list(getattr(module, "RAISED", []))
        boxes = [r[1:5] for r in rooms] + [s[1:5] for s in solids] + [r[1:5] for r in raised]
        metres = self._snapped(boxes)
        n_rooms, n_solids = len(rooms), len(solids)
        self.rooms = [(r[0],) + metres[k] for k, r in enumerate(rooms)]
        self.solids = [(s[0],) + metres[n_rooms + k] + (s[5],) for k, s in enumerate(solids)]
        self.raised = [(r[0],) + metres[n_rooms + n_solids + k] + (r[5],) for k, r in enumerate(raised)]
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
        self.open = [self.view.rect(*o) for o in getattr(module, "OPEN", [])]
        self.stairs = [(stair_name,) + self.view.rect(x0, y0, x1, y1) + (rises, lower, upper)
                       for stair_name, x0, y0, x1, y1, rises, lower, upper in getattr(module, "STAIRS", [])]
        self.walls = self._walls()

    def _snapped(self, boxes):
        """Each plate box (x0, y0, x1, y1) as ship (x0, x1, z0, z1), its edges snapped to
        the lines they share: two edges of one kind within SNAP px of each other that
        touch along their length are one wall's two readings, and take its mean. A line
        along her is read in ship z at its own middle, so a centre line tilted over the
        scan bends no wall."""
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
        out = []
        for k in range(len(boxes)):
            x0, x1, y0, y1 = ship[4 * k], ship[4 * k + 1], ship[4 * k + 2], ship[4 * k + 3]
            out.append((min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1)))
        return out

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
        solid_boxes = [s[1:5] for s in self.solids]
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
                        lo, hi = max(a, w_a), min(b, w_b)
                        if hi - lo > 0.9 and (best is None or hi - lo > best[0]):
                            mid = (lo + hi) * 0.5
                            best = (hi - lo, (at, mid) if axis == 0 else (mid, at))
            if best is not None:
                out.append(best[1])
        return out

    def _open_on(self, axis, at):
        out = []
        for x0, x1, z0, z1 in self.open:
            if axis == 0 and x0 - 0.05 <= at <= x1 + 0.05:
                out.append((z0, z1))
            if axis == 2 and z0 - 0.05 <= at <= z1 + 0.05:
                out.append((x0, x1))
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


def load(name):
    return Deck(name)
