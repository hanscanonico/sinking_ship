"""`make sailor`: builds the brawlers' hats in Blender, headless, from nothing.

    blender --background --factory-startup --python-exit-code 1 \
        --python assets/characters/sailor/gen_hats.py -- hats.blend hats.glb

Every hat a seat can wear (HATS, in Brawler.Hat's order), and the bare head's hair,
as one small mesh each: a seaman's flat cap with its ribbon, an oilskin sou'wester,
a straw boater, a knitted bobble hat, a silk topper and a mate's peaked cap. Each is
built round the sailor's own head — gen_sailor.py grows it, and the bands are cast
onto it so each hat seats as snugly as it should — in the head bone's space: the
model frame's axes, its origin at the head bone's head, 0.26 under the crown.
Brawler hangs it on that bone, so it rides the head and scales with the body.

What each point is goes into its second UV, as on the outfits, so the clothes
shader (brawler.gdshader's PART_) colours it and the seat's colour is the shader's:
rest x and y in the first UV, rest z and the part in the second, each v written as
1 - v for glTF; how wide its outline is drawn in the alpha of its colour.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sailor as sailor  # noqa: E402
from gen_sailor import BRASS, CLOTH, FACING, HAIR, INK, LEATHER, STRAW, TO_BLENDER, Kit  # noqa: E402

## The hats, in Brawler.Hat's order, named as Brawler.HAT_MESHES finds them.
HATS = ("Cap", "Souwester", "Boater", "Bare", "Bobble", "Top", "Peaked")
## Where the head bone stands at rest, in the model frame.
HEAD = Vector(sailor.REST["head"][0])
## The head's middle, front to back, in the head bone's space; and the height a hat's
## band seats at, which every hat tips about.
MIDDLE = -0.005
BAND = 0.165
## Facets round a hat: few, as the rest of the ship is faceted.
SEGMENTS = 16
## How wide the outline is drawn round small pieces, as a share of the body's.
DETAIL_INK = sailor.DETAIL_INK
BUTTON_INK = sailor.BUTTON_INK
## How far a band stands off the head, and the heights it is fitted over.
GAP = 0.008
FIT = (0.15, 0.21)
## Facets round a knitted cuff: enough for its ribs to read.
KNIT = 24


class Head:
    """The sailor's head, grown as gen_sailor.py grows it, in the head bone's space:
    what a hat's band is fitted round and every hat is checked to clear."""

    def __init__(self):
        grown = sailor._grow()
        points = [TO_BLENDER.transposed() @ vert.co - HEAD for vert in grown.vertices]
        triangles = [tuple(polygon.vertices) for polygon in grown.polygons]
        self.tree = BVHTree.FromPolygons(points, triangles, all_triangles=True)
        bpy.data.meshes.remove(grown)

    def reach(self, height, angle, tilt=0.0):
        """How far the head reaches out from its middle at `height`, `angle` round
        from ahead toward its left, in a frame tipped `tilt` radians forward; 0
        over the crown."""
        origin = _tipped(Vector((0.0, height, MIDDLE)), tilt)
        way = Matrix.Rotation(tilt, 3, "X") @ Vector((math.sin(angle), 0.0, math.cos(angle)))
        hit = self.tree.ray_cast(origin, way.normalized(), 1.0)
        return hit[3] if hit[0] is not None else 0.0

    def band(self, tilt=0.0, low=FIT[0], high=FIT[1], segments=SEGMENTS):
        """Per angle round the head, how far out a band fitted over it between `low`
        and `high` stands: the widest the head reaches there, GAP clear of it."""
        return [
            max(self.reach(low + (high - low) * k / 3.0, _angle(step, segments), tilt) for k in range(4)) + GAP
            for step in range(segments)
        ]

    def inside(self, point):
        """How far `point`, in the head bone's space, is inside the head: the head's
        reach past it, level from the middle toward it; 0 or less when clear."""
        out = Vector((point.x, 0.0, point.z - MIDDLE))
        if out.length < 1e-6:
            return 0.0
        hit = self.tree.ray_cast(Vector((0.0, point.y, MIDDLE)), out.normalized(), 1.0)
        return hit[3] - out.length if hit[0] is not None else -1.0


def _angle(step, segments=SEGMENTS):
    """The angle round the head of a ring's `step`, from ahead toward the left."""
    return 2.0 * math.pi * step / segments


def _tipped(point, tilt):
    """`point`, in a hat's own frame, in the head bone's: tipped `tilt` radians
    forward (the front down) about the ear-to-ear line through the band."""
    pivot = Vector((0.0, BAND, MIDDLE))
    return pivot + Matrix.Rotation(tilt, 3, "X") @ (Vector(point) - pivot)


class Hat:
    """A hat being put together in its own frame, tipped `tilt` forward: its pieces
    as rings round the head's middle, lofted into bands, crowns and brims."""

    def __init__(self, tilt=0.0):
        self.kit = Kit()
        self.tilt = tilt

    def ring(self, height, radii, part, ink=1.0, ribs=0.0, segments=SEGMENTS):
        """A ring of points `height` up, `radii` out from the middle — one per step
        round, or one for all — every other one `ribs` further out."""
        points = []
        for step in range(segments):
            radius = radii[step] if isinstance(radii, (list, tuple)) else radii
            radius += ribs if step % 2 else 0.0
            angle = _angle(step, segments)
            at = Vector((math.sin(angle) * radius, height, MIDDLE + math.cos(angle) * radius))
            points.append(self.kit.add(_tipped(at, self.tilt), part, {}, ink))
        return points

    def point(self, at, part, ink=1.0):
        return self.kit.add(_tipped(Vector(at), self.tilt), part, {}, ink)

    def loft(self, rings, outward=None, closed=True):
        """Joins each ring of `rings` to the next, each face turned out from the
        middle — or `outward`'s way, up or down, per pair of rings when it is a list."""
        for number in range(len(rings) - 1):
            low, high = rings[number], rings[number + 1]
            count = len(low) if closed else len(low) - 1
            for step in range(count):
                following = (step + 1) % len(low)
                corners = (low[step], low[following], high[following], high[step])
                way = outward[number] if isinstance(outward, list) else outward
                if way is None:
                    middle = sum((self.kit.points[i] for i in corners), Vector()) * 0.25
                    axis = _tipped(Vector((0.0, 0.0, MIDDLE)), self.tilt)
                    up = _tipped(Vector((0.0, 1.0, MIDDLE)), self.tilt) - axis
                    way = middle - axis
                    way -= up * way.dot(up)
                self.kit.face(corners, Vector(way))

    def cap(self, ring, at, way):
        """Closes `ring` with a fan to a point at `at`, turned `way`."""
        part = self.kit.parts[ring[0]]
        ink = self.kit.inks[ring[0]]
        centre = self.point(at, part, ink)
        for step in range(len(ring)):
            self.kit.face((ring[step], ring[(step + 1) % len(ring)], centre), Vector(way))

    def block(self, angle, height, out, size, part, ink=BUTTON_INK, lean=0.0):
        """A small block on the hat, `out` from the middle at `angle` round and
        `height` up: `size` across, high and deep, leaning `lean` radians back."""
        normal = Vector((math.sin(angle), 0.0, math.cos(angle)))
        side = Vector((math.cos(angle), 0.0, -math.sin(angle)))
        up = Vector((0.0, 1.0, 0.0))
        normal, up = (Matrix.Rotation(-lean, 3, side) @ normal, Matrix.Rotation(-lean, 3, side) @ up)
        centre = Vector((0.0, height, MIDDLE)) + Vector((math.sin(angle), 0.0, math.cos(angle))) * out
        corners = {}
        for i in (-1, 1):
            for j in (-1, 1):
                for k in (-1, 1):
                    at = centre + side * (i * size[0] * 0.5) + up * (j * size[1] * 0.5) + normal * (k * size[2] * 0.5)
                    corners[(i, j, k)] = self.point(at, part, ink)
        faces = (
            ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)),
            ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)),
            ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)),
            ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),
            ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)),
            ((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)),
        )
        for face in faces:
            way = sum((Vector(c) for c in face), Vector((0.0, 0.0, 0.0)))
            local = side * way.x + up * way.y + normal * way.z
            self.kit.face(tuple(corners[c] for c in face), _tipped(local, self.tilt) - _tipped(Vector(), self.tilt))


def _plus(radii, more):
    return [r + more for r in radii]


def _scaled(radii, rate, more=0.0):
    return [r * rate + more for r in radii]


def _around(rule, segments=SEGMENTS):
    """A value per step round, `rule` of the angle (0 ahead, pi behind)."""
    return [rule(_angle(step, segments)) for step in range(segments)]


def cap(head):
    """A seaman's flat cap: a broad, flat crown over a black ribbon round the band,
    its bow over the left ear and the ship's name in gilt across the front."""
    hat = Hat(-0.06)
    band = head.band(hat.tilt)
    ribbon = [
        hat.ring(0.156, _plus(band, -0.004), INK),
        hat.ring(0.16, band, INK),
        hat.ring(0.2, _plus(band, 0.002), INK),
        hat.ring(0.204, _plus(band, -0.003), INK),
    ]
    hat.loft(ribbon)
    crown = [
        hat.ring(0.2, _plus(band, -0.002), CLOTH),
        hat.ring(0.222, _plus(band, 0.018), CLOTH),
        hat.ring(0.244, _plus(band, 0.046), CLOTH),
        hat.ring(0.26, _plus(band, 0.038), CLOTH),
    ]
    hat.loft(crown)
    hat.cap(crown[-1], (0.0, 0.267, MIDDLE), (0.0, 1.0, 0.0))
    left = math.pi * 0.5
    hat.block(left - 0.12, 0.18, band[4] + 0.006, (0.03, 0.022, 0.008), INK, DETAIL_INK)
    hat.block(left + 0.12, 0.18, band[4] + 0.006, (0.03, 0.022, 0.008), INK, DETAIL_INK)
    hat.block(0.0, 0.18, band[0] + 0.003, (0.07, 0.008, 0.004), BRASS)
    # The ribbon's two tails, hanging down the back of the head from the bow.
    for turn in (0.35, 0.55):
        hat.block(left + turn, 0.14, band[5] + 0.004, (0.018, 0.06, 0.004), INK, DETAIL_INK, lean=-0.15)
    return hat


def souwester(head):
    """An oilskin sou'wester: a round crown over the head and a brim turned down,
    short over the brow and long down the back of the neck, dark beneath."""
    hat = Hat(-0.1)
    band = head.band(hat.tilt, 0.15, 0.2)
    reach = _around(lambda a: 0.04 + 0.075 * (1.0 - math.cos(a)) * 0.5)
    drop = _around(lambda a: 0.018 + 0.07 * ((1.0 - math.cos(a)) * 0.5) ** 1.5)
    rise = 0.112
    crown = []
    for number, lift in enumerate((0.0, 0.35, 0.65, 0.88)):
        rate = math.cos(lift * math.pi * 0.5) if number else 1.0
        crown.append(hat.ring(0.155 + rise * math.sin(lift * math.pi * 0.5) ** 0.8, _scaled(band, rate, 0.008), CLOTH))
    hat.loft(crown)
    hat.cap(crown[-1], (0.0, 0.155 + rise + 0.004, MIDDLE - 0.004), (0.0, 1.0, 0.0))

    def brim(part, lift, out):
        rings = []
        for share in (0.0, 0.45, 1.0):
            radii = [b + 0.004 + r * share + out for b, r in zip(band, reach)]
            heights = [0.152 + lift - d * share ** 1.4 for d in drop]
            rings.append(_ring_at(hat, radii, heights, part))
        return rings

    top = brim(CLOTH, 0.006, 0.0)
    hat.loft(top, outward=[(0.0, 1.0, 0.0)] * 2)
    under = brim(FACING, 0.0, 0.0)
    hat.loft(under, outward=[(0.0, -1.0, 0.0)] * 2)
    hat.loft([top[-1], _ring_at(hat, None, None, CLOTH, under[-1])])
    return hat


def _ring_at(hat, radii, heights, part, copy=None):
    """A ring at its own height per step, or a copy of ring `copy` in `part`."""
    if copy is not None:
        return [hat.kit.add(hat.kit.points[i], part, {}, hat.kit.inks[i]) for i in copy]
    points = []
    for step, (radius, height) in enumerate(zip(radii, heights)):
        angle = _angle(step, len(radii))
        at = Vector((math.sin(angle) * radius, height, MIDDLE + math.cos(angle) * radius))
        points.append(hat.point(at, part))
    return points


def boater(head):
    """A straw boater: a flat-topped crown, stiff and straight-sided, a ribbon round
    it in the seat's colour with its bow over the left ear, and a flat brim."""
    hat = Hat(-0.06)
    band = head.band(hat.tilt)
    crown = [
        hat.ring(0.168, _plus(band, 0.004), STRAW),
        hat.ring(0.262, _plus(band, -0.002), STRAW),
        hat.ring(0.27, _plus(band, -0.01), STRAW),
    ]
    hat.loft(crown)
    hat.cap(crown[-1], (0.0, 0.27, MIDDLE), (0.0, 1.0, 0.0))
    ribbon = [
        hat.ring(0.172, _plus(band, 0.008), CLOTH),
        hat.ring(0.21, _plus(band, 0.007), CLOTH),
        hat.ring(0.213, _plus(band, 0.0), CLOTH),
    ]
    hat.loft(ribbon)
    brim = [
        hat.ring(0.172, _plus(band, 0.004), STRAW),
        hat.ring(0.172, _plus(band, 0.078), STRAW),
        hat.ring(0.164, _plus(band, 0.078), STRAW),
        hat.ring(0.164, _plus(band, 0.004), STRAW),
    ]
    hat.loft(brim, outward=[(0.0, 1.0, 0.0), None, (0.0, -1.0, 0.0)])
    hat.block(math.pi * 0.5, 0.19, band[4] + 0.012, (0.035, 0.03, 0.008), CLOTH, DETAIL_INK)
    return hat


def bare(head):
    """No hat: hair cut short over the crown and down the back of the head, combed
    back from a parting, a lock lifted over the brow."""
    hat = Hat(0.0)
    centre = Vector((0.0, 0.12, MIDDLE))
    rings = []
    shares = (0.0, 0.2, 0.45, 0.7, 0.88)
    for number, share in enumerate(shares):
        ring = []
        for step in range(SEGMENTS):
            angle = _angle(step, SEGMENTS)
            behind = (1.0 - math.cos(angle)) * 0.5
            # The hairline: high over the brow, over the ears, low at the nape.
            edge = math.radians(48.0 - 70.0 * behind ** 0.8 - 14.0 * math.sin(angle) ** 2 * (1.0 - behind))
            rise = edge + (math.pi * 0.5 - edge) * share
            way = Vector((math.sin(angle) * math.cos(rise), math.sin(rise), math.cos(angle) * math.cos(rise)))
            hit = head.tree.ray_cast(centre, way, 1.0)
            thick = 0.0 if number == 0 else 0.011 + (0.003 if step % 2 else 0.0)
            # A lock over the brow, lifted and swept a little to the left.
            front = math.exp(-((angle - 0.35 if angle < math.pi else angle - 2.0 * math.pi - 0.35) / 0.7) ** 2)
            thick += 0.03 * front * math.sin(share * math.pi) ** 0.7 if number else 0.0
            ring.append(hat.point(hit[0] + way * thick, HAIR))
        rings.append(ring)
    hat.loft(rings)
    last = [hat.kit.points[i] for i in rings[-1]]
    middle = sum(last, Vector()) / len(last)
    hat.cap(rings[-1], (middle.x, max(p.y for p in last) + 0.004, middle.z), (0.0, 1.0, 0.0))
    return hat


def bobble(head):
    """A knitted watch cap: a ribbed crown snug over the head, its cuff turned up
    and ribbed in a darker yarn, and a bobble on top."""
    hat = Hat(-0.08)
    band = head.band(hat.tilt, 0.13, 0.2)
    ribbed = head.band(hat.tilt, 0.13, 0.2, KNIT)
    cuff = [
        hat.ring(0.135, _plus(ribbed, 0.0), FACING, segments=KNIT),
        hat.ring(0.14, _plus(ribbed, 0.012), FACING, ribs=0.009, segments=KNIT),
        hat.ring(0.192, _plus(ribbed, 0.014), FACING, ribs=0.009, segments=KNIT),
        hat.ring(0.198, _plus(ribbed, 0.002), FACING, segments=KNIT),
    ]
    hat.loft(cuff)
    crown = []
    for lift in (0.0, 0.4, 0.7, 0.9):
        rate = math.cos(lift * math.pi * 0.5)
        height = 0.19 + 0.115 * math.sin(lift * math.pi * 0.5)
        crown.append(hat.ring(height, _scaled(band, rate, 0.008), CLOTH))
    hat.loft(crown)
    hat.cap(crown[-1], (0.0, 0.31, MIDDLE), (0.0, 1.0, 0.0))
    _ball(hat, Vector((0.0, 0.335, MIDDLE)), 0.038, CLOTH, segments=6)
    return hat


def _ball(hat, centre, radius, part, segments=8, rows=4):
    """A rough ball of yarn round `centre`, its points pulled in and out by turns."""
    rings = []
    for row in range(1, rows):
        polar = math.pi * row / rows
        ring = []
        for step in range(segments):
            angle = 2.0 * math.pi * (step + 0.5 * (row % 2)) / segments
            rough = radius * (1.0 + (0.12 if (step + row) % 2 else -0.06))
            out = Vector((math.sin(polar) * math.sin(angle), math.cos(polar), math.sin(polar) * math.cos(angle)))
            ring.append(hat.point(centre + out * rough, part))
        rings.append(ring)
    for number in range(len(rings) - 1):
        low, high = rings[number], rings[number + 1]
        for step in range(segments):
            following = (step + 1) % segments
            way = (hat.kit.points[low[step]] + hat.kit.points[high[following]]) * 0.5 - _tipped(centre, hat.tilt)
            hat.kit.face((low[step], low[following], high[following], high[step]), way)
    top = hat.point(centre + Vector((0.0, radius, 0.0)), part)
    bottom = hat.point(centre - Vector((0.0, radius, 0.0)), part)
    for step in range(segments):
        following = (step + 1) % segments
        hat.kit.face((rings[0][step], rings[0][following], top), (0.0, 1.0, 0.0))
        hat.kit.face((rings[-1][step], rings[-1][following], bottom), (0.0, -1.0, 0.0))


def top(head):
    """A silk topper: a tall crown, waisted and flaring to its flat top, a black band
    and a brim curled up at the sides."""
    hat = Hat(-0.05)
    band = head.band(hat.tilt)
    crown = [
        hat.ring(0.168, _plus(band, 0.004), CLOTH),
        hat.ring(0.27, _plus(band, -0.006), CLOTH),
        hat.ring(0.38, _plus(band, 0.01), CLOTH),
        hat.ring(0.388, _plus(band, 0.002), CLOTH),
    ]
    hat.loft(crown)
    hat.cap(crown[-1], (0.0, 0.389, MIDDLE), (0.0, 1.0, 0.0))
    ribbon = [
        hat.ring(0.172, _plus(band, 0.007), INK),
        hat.ring(0.208, _plus(band, 0.005), INK),
        hat.ring(0.212, _plus(band, -0.002), INK),
    ]
    hat.loft(ribbon)
    out = _around(lambda a: 0.05 - 0.008 * math.sin(a) ** 2)
    curl = _around(lambda a: 0.03 * math.sin(a) ** 2 - 0.006 * math.cos(a) ** 2)
    rings = [
        _ring_at(hat, _plus(band, 0.004), [0.174] * SEGMENTS, CLOTH),
        _ring_at(hat, [b + 0.004 + o for b, o in zip(band, out)], [0.174 + c for c in curl], CLOTH),
        _ring_at(hat, [b + 0.004 + o for b, o in zip(band, out)], [0.166 + c for c in curl], CLOTH),
        _ring_at(hat, _plus(band, 0.004), [0.164] * SEGMENTS, CLOTH),
    ]
    hat.loft(rings, outward=[(0.0, 1.0, 0.0), None, (0.0, -1.0, 0.0)])
    return hat


def peaked(head):
    """A mate's peaked cap: a band in a darker cloth with a gilt badge, a wide top
    stiffened high at the front, a leather peak and chin strap with its buttons."""
    hat = Hat(-0.02)
    band = head.band(hat.tilt)
    rim = [
        hat.ring(0.156, _plus(band, -0.004), FACING),
        hat.ring(0.16, band, FACING),
        hat.ring(0.212, _plus(band, 0.002), FACING),
    ]
    hat.loft(rim)
    front = _around(lambda a: 0.016 * max(math.cos(a), 0.0))
    top_rings = [
        _ring_at(hat, _plus(band, -0.002), [0.208] * SEGMENTS, CLOTH),
        _ring_at(hat, _plus(band, 0.034), [0.246 + f for f in front], CLOTH),
        _ring_at(hat, _plus(band, 0.03), [0.262 + f for f in front], CLOTH),
    ]
    hat.loft(top_rings)
    hat.cap(top_rings[-1], (0.0, 0.27, MIDDLE), (0.0, 1.0, 0.0))
    # The peak: a crescent out from the band's front, tipped down over the brow.
    columns = 9
    spread = math.radians(72.0)
    upper, lower, edge_up, edge_down = [], [], [], []
    for c in range(columns):
        angle = -spread + 2.0 * spread * c / (columns - 1)
        root = head.reach(0.165, angle, hat.tilt) + GAP
        reach = 0.062 * math.cos(angle * 0.5 * math.pi / spread) ** 0.8
        way = Vector((math.sin(angle), 0.0, math.cos(angle)))
        base = Vector((0.0, 0.162, MIDDLE)) + way * root
        tip = base + way * reach + Vector((0.0, -0.36 * reach, 0.0))
        upper.append(hat.point(base + Vector((0.0, 0.003, 0.0)), LEATHER))
        edge_up.append(hat.point(tip + Vector((0.0, 0.002, 0.0)), LEATHER))
        edge_down.append(hat.point(tip - Vector((0.0, 0.002, 0.0)), LEATHER))
        lower.append(hat.point(base - Vector((0.0, 0.003, 0.0)), LEATHER))
    hat.loft([upper, edge_up], outward=(0.0, 1.0, 0.25), closed=False)
    hat.loft([edge_up, edge_down], closed=False)
    hat.loft([edge_down, lower], outward=(0.0, -1.0, -0.25), closed=False)
    # The chin strap, across the band's front just over the peak, and its buttons.
    strap = []
    reach = math.radians(64.0)
    for height, off in ((0.166, 0.0), (0.168, 0.004), (0.18, 0.004), (0.182, 0.0)):
        row = []
        for c in range(7):
            angle = -reach + 2.0 * reach * c / 6
            out = head.reach(height, angle, hat.tilt) + GAP + 0.001 + off
            at = (math.sin(angle) * out, height, MIDDLE + math.cos(angle) * out)
            row.append(hat.point(at, LEATHER, DETAIL_INK))
        strap.append(row)
    hat.loft(strap, closed=False)
    for side in (-1.0, 1.0):
        angle = side * reach
        hat.block(angle, 0.174, head.reach(0.174, angle, hat.tilt) + GAP + 0.006, (0.012, 0.012, 0.006), BRASS)
    hat.block(0.0, 0.19, band[0] + 0.004, (0.044, 0.022, 0.006), BRASS, lean=0.04)
    hat.block(0.0, 0.206, band[0] + 0.004, (0.018, 0.012, 0.006), BRASS, lean=0.04)
    return hat


BUILD = {"Cap": cap, "Souwester": souwester, "Boater": boater, "Bare": bare, "Bobble": bobble, "Top": top,
         "Peaked": peaked}


def build_hat(name, head, material):
    """`name`'s hat as a mesh object, in the head bone's space, its points' rest
    and parts in its UVs and its ink in its colours."""
    kit = BUILD[name](head).kit
    # Every point and every face's middle, which a face's sag brings nearer the head.
    probes = kit.points + [sum((kit.points[i] for i in face), Vector()) / len(face) for face in kit.faces]
    deepest, worst = max((head.inside(point), number) for number, point in enumerate(probes))
    if deepest > 0.002:
        raise RuntimeError("gen_hats: %s cuts %.3f into the head at %s" % (name, deepest, tuple(probes[worst])))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([TO_BLENDER @ p for p in kit.points], [], kit.faces)
    shape = bmesh.new()
    shape.from_mesh(mesh)
    bmesh.ops.triangulate(shape, faces=shape.faces[:], quad_method="BEAUTY")
    shape.to_mesh(mesh)
    shape.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    rest = mesh.uv_layers.new(name="rest")
    depth = mesh.uv_layers.new(name="depth")
    for loop in mesh.loops:
        at = kit.points[loop.vertex_index] + HEAD
        rest.data[loop.index].uv = (at.x, 1.0 - at.y)
        depth.data[loop.index].uv = (at.z, 1.0 - kit.parts[loop.vertex_index])
    ink = mesh.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
    for index, share in enumerate(kit.inks):
        ink.data[index].color = (1.0, 1.0, 1.0, share)
    mesh.color_attributes.active_color = ink
    mesh.materials.append(material)
    hat = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(hat)
    print("gen_hats: %s %d triangles, %.3f clear of the head, top %.3f" % (
        name, len(mesh.polygons), -deepest, max(p.y for p in kit.points)))
    return hat


def export(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_normals=True,
        export_texcoords=True,
        export_vertex_color="ACTIVE",
        export_tangents=False,
        export_materials="EXPORT",
        export_skins=False,
        export_animations=False,
        export_morph=False,
        export_cameras=False,
        export_lights=False,
        export_extras=False,
    )


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    head = Head()
    material = bpy.data.materials.new("hat")
    material.diffuse_color = (0.84, 0.37, 0.0, 1.0)
    for name in HATS:
        build_hat(name, head, material)
    if argv:
        bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    if len(argv) > 1:
        export(argv[1])


if __name__ == "__main__":
    main()
