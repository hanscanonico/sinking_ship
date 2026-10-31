"""The Titanic's staterooms' furniture by rule (#390): how many berths a cabin's name says,
where they stand against its walls, and a sofa where the plates draw one. It reads only
what the generator already knows (rooms, blockers, ways in, seats' starts) and answers
with boxes the rules hold bodies out of; RoomDressing and CabinDressing draw them.

The numbers the game measures are declared here and in CabinDressing, which a test holds
level: a lower berth stands on the floor, an upper one over it UPPER_BOTTOM up, each
BERTH long and deep.
"""

import math
import re

BERTH = (1.9, 0.7)
BERTH_RISE = 0.46
UPPER_BOTTOM = 1.3
SOFA = (2.0, 0.8)
SOFA_TOP = 0.45
# A first-class stateroom at least this large stands a sofa (est., the plates).
SOFA_AREA = 12.0
# A first-class stateroom with no count in its name sleeps one under this, else two.
TWO_BERTH_AREA = 9.0
# Half the clear way a body needs beside a piece: bodies are 0.8 m across.
AISLE = 0.42
BODY_STEP, BODY_HEIGHT = 0.35, 1.7
GRID = 0.05
SLIDE = 0.05
# How far past a door's gap, either way along its wall, a piece keeps. ways_in widens a
# gap by a body's breadth for a public room's pieces, which a cabin has no room for: the
# flood (Room.without) holds the way to it clear instead.
DOOR_JAMB = 0.1
BREADTH = 0.8
CABIN = re.compile(r"stateroom|third-class room")
COUNTS = {"single": 1, "one": 1, "two": 2, "three": 3, "four": 4, "six": 6}


def named_berths(name):
    """How many berths name says, or 0 when it gives no count."""
    found = re.match(r"(\w+)-berth", name)
    return COUNTS.get(found.group(1), 0) if found else 0


def berths_for(name, width, length):
    """How many berths a cabin named name of that size sleeps: its name's count, else the
    plates' usual layout for its size."""
    named = named_berths(name)
    if named:
        return named
    return 2 if "parlour" in name or width * length >= TWO_BERTH_AREA else 1


def columns_for(count):
    """How many columns on the floor count berths stand in where the room lets them: one
    each for one or two, else in pairs, upper over lower."""
    return count if count <= 2 else math.ceil(count / 2)


def wants_sofa(name, width, length):
    return "parlour" in name or ("first-class" in name and width * length >= SOFA_AREA)


class Room:
    """One cabin's floor as a body's centre can use it: a grid of free cells, and the
    boxes already standing in it."""

    def __init__(self, geo, blocks, ways):
        self.x0, self.x1, self.z0, self.z1, self.floor, self.name = geo
        floor = self.floor
        self.blocks = [b[:6] for b in blocks if b[4] < floor + 2.4 and b[5] > floor
                       and b[0] < self.x1 + 0.5 and self.x0 - 0.5 < b[1]
                       and b[2] < self.z1 + 0.5 and self.z0 - 0.5 < b[3]]
        self.ways = [_door_of(w) for w in ways]
        self.nx = max(1, int((self.x1 - self.x0) / GRID))
        self.nz = max(1, int((self.z1 - self.z0) / GRID))
        self.free = set()
        solid = [b for b in self.blocks if b[4] < floor + BODY_HEIGHT and b[5] > floor + BODY_STEP]
        for i in range(self.nx):
            x = self.x0 + (i + 0.5) * (self.x1 - self.x0) / self.nx
            for k in range(self.nz):
                z = self.z0 + (k + 0.5) * (self.z1 - self.z0) / self.nz
                if not any(_off(b, x, z) < AISLE for b in solid):
                    self.free.add((i, k))
        self.starts = [self._cell(*self._way_middle(w)) for w in ways]
        self.reach = self._reachable(self.free)

    def _way_middle(self, way):
        wx0, wx1, wz0, wz1 = way
        return (min(max((wx0 + wx1) / 2, self.x0), self.x1), min(max((wz0 + wz1) / 2, self.z0), self.z1))

    def _cell(self, x, z):
        i = min(self.nx - 1, max(0, int((x - self.x0) / (self.x1 - self.x0) * self.nx)))
        k = min(self.nz - 1, max(0, int((z - self.z0) / (self.z1 - self.z0) * self.nz)))
        return (i, k)

    def _nearest(self, free, cell):
        best, far = None, 1e9
        for c in free:
            d = (c[0] - cell[0]) ** 2 + (c[1] - cell[1]) ** 2
            if d < far or (d == far and c < best):
                best, far = c, d
        return best if far <= 16 else None

    def _reachable(self, free):
        """The free cells a body reaches from its ways in, when all of them reach one
        another; every free cell for a room with no way in; None when one way is cut off
        or there is nowhere to stand."""
        if not free:
            return None
        if not self.starts:
            return free
        first = None
        seen = set()
        for start in self.starts:
            near = self._nearest(free, start)
            if near is None:
                return None
            if first is None:
                first = near
                todo = [near]
                seen.add(near)
                while todo:
                    i, k = todo.pop()
                    for c in ((i + 1, k), (i - 1, k), (i, k + 1), (i, k - 1)):
                        if c in free and c not in seen:
                            seen.add(c)
                            todo.append(c)
            elif near not in seen:
                return None
        return seen

    def inside(self, area):
        return (area[0] >= self.x0 - 1e-6 and area[1] <= self.x1 + 1e-6
                and area[2] >= self.z0 - 1e-6 and area[3] <= self.z1 + 1e-6)

    def blocked(self, area, bottom, top):
        return any(b[4] < top - 1e-6 and b[5] > bottom + 1e-6 and b[0] < area[1] - 1e-6 and area[0] < b[1] - 1e-6
                   and b[2] < area[3] - 1e-6 and area[2] < b[3] - 1e-6 for b in self.blocks)

    def in_a_way(self, area):
        return any(area[0] < w[1] and w[0] < area[1] and area[2] < w[3] and w[2] < area[3] for w in self.ways)

    def without(self, area):
        """The free cells left once area stands: None when a body no longer gets in."""
        taken = set()
        for c in self.free:
            x = self.x0 + (c[0] + 0.5) * (self.x1 - self.x0) / self.nx
            z = self.z0 + (c[1] + 0.5) * (self.z1 - self.z0) / self.nz
            if _off(area, x, z) < AISLE:
                taken.add(c)
        left = self.free - taken
        return left if self._reachable(left) is not None else None

    def stand(self, area, top):
        self.blocks.append((area[0], area[1], area[2], area[3], self.floor, top))
        self.free = self.without(area)


def _door_of(way):
    """The strip a gap in a wall keeps clear, out of ways_in's wider one."""
    x0, x1, z0, z1 = way
    trim = BREADTH - DOOR_JAMB
    if x1 - x0 <= BREADTH + 1e-6:
        return (x0, x1, z0 + trim, z1 - trim)
    return (x0 + trim, x1 - trim, z0, z1)


def _off(box, x, z):
    return math.hypot(max(box[0] - x, 0.0, x - box[1]), max(box[2] - z, 0.0, z - box[3]))


def _sides(room):
    """Its walls as (axis along, at, out), the long ones first, farthest from a way in
    first, then the short ones: axis 0 runs along x."""
    x0, x1, z0, z1 = room.x0, room.x1, room.z0, room.z1
    long_x = x1 - x0 >= z1 - z0
    longs = [(0, z0, 1.0), (0, z1, -1.0)] if long_x else [(1, x0, 1.0), (1, x1, -1.0)]
    shorts = [(1, x0, 1.0), (1, x1, -1.0)] if long_x else [(0, z0, 1.0), (0, z1, -1.0)]

    def away(side):
        axis, at, _out = side
        mids = [room._way_middle(w) for w in room.ways]
        return -sum(abs((m[1] if axis == 0 else m[0]) - at) for m in mids), at

    return sorted(longs, key=away), sorted(shorts, key=away)


def _face(room, side, a, b, height):
    """How far in from side's line its wall stands over a..b along it."""
    axis, at, out = side
    deepest = 0.0
    for box in room.blocks:
        if box[4] >= room.floor + height or box[5] <= room.floor:
            continue
        lo, hi, s0, s1 = (box[0], box[1], box[2], box[3]) if axis == 0 else (box[2], box[3], box[0], box[1])
        if lo < b and a < hi and s0 - 1e-6 <= at <= s1 + 1e-6:
            deepest = max(deepest, (s1 - at) if out > 0 else (at - s0))
    return deepest


def _area(side, a, b, near, far):
    axis, at, out = side
    s0, s1 = sorted((at + out * near, at + out * far))
    return (a, b, s0, s1) if axis == 0 else (s0, s1, a, b)


def _slot(room, side, size, top, spawns):
    """Where on side a piece of size (long, deep) stands, farthest along it from the ways
    in, its back on the wall, with a body still getting in: its area, or None."""
    axis, _at, _out = side
    lo, hi = (room.x0, room.x1) if axis == 0 else (room.z0, room.z1)
    long, deep = size
    mids = [room._way_middle(w) for w in room.ways]
    tries = []
    a = lo
    while a + long <= hi + 1e-6:
        along = a + long / 2
        tries.append((-min([abs((m[0] if axis == 0 else m[1]) - along) for m in mids] + [99.0]), a))
        a += SLIDE
    for _score, a in sorted(tries):
        near = _face(room, side, a, a + long, top - room.floor)
        area = _area(side, a, a + long, near, near + deep)
        if not room.inside(area) or room.blocked(area, room.floor, top) or room.in_a_way(area):
            continue
        if any(abs(y - room.floor) < 1e-6 and area[0] - 0.4 < x < area[1] + 0.4 and area[2] - 0.4 < z < area[3] + 0.4
               for x, y, z in spawns):
            continue
        if room.without(area) is not None:
            return area
    return None


def furnish(room_geo, block_geo, ways_in, spawns):
    """Every cabin's pieces, in room order: [(room, [lower areas], [upper areas], sofa or
    None, berths folded)]."""
    found = []
    for geo in room_geo:
        if not CABIN.search(geo[5]):
            continue
        room = Room(geo, block_geo, ways_in(geo))
        width, length = sorted((geo[1] - geo[0], geo[3] - geo[2]))
        count = berths_for(geo[5], width, length)
        longs, shorts = _sides(room)
        lowers = []
        wanted = columns_for(count)
        top = room.floor + BERTH_RISE
        # On its long walls by turns, each taking one before either takes a second; the
        # short ones only when both long walls are done.
        passes = longs + longs + shorts
        for side in passes:
            if len(lowers) >= wanted:
                break
            area = _slot(room, side, BERTH, room.floor + UPPER_BOTTOM + BERTH_RISE, spawns)
            if area is not None:
                room.stand(area, top)
                lowers.append(area)
        uppers = []
        for area in lowers:
            if len(lowers) + len(uppers) >= count:
                break
            if not room.blocked(area, room.floor + UPPER_BOTTOM, room.floor + UPPER_BOTTOM + BERTH_RISE):
                uppers.append(area)
        sofa = None
        if wants_sofa(geo[5], width, length):
            for side in longs + shorts:
                sofa = _slot(room, side, SOFA, room.floor + SOFA_TOP, spawns)
                if sofa is not None:
                    room.stand(sofa, room.floor + SOFA_TOP)
                    break
        found.append((geo, lowers, uppers, sofa, max(0, count - len(lowers) - len(uppers))))
    return found
