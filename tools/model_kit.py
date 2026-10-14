"""Shared helpers for the props' build scripts (assets/models/NAME/NAME.py), which
headless Blender runs to make each NAME.blend (`make model-sources`), in Godot's axes.

Points are given in Godot space (x along the boat, y up, z to starboard) and
converted to Blender's (x, -z, y) as they are created, so the glTF exporter's +Y-up
conversion hands Godot back exactly these coordinates. Faces are wound so their
right-hand normal points out (glTF's convention); an outward hint fixes any face that
is not. Every face carries a per-corner ink weight (0 inside a face, 1 at a hard edge).
"""

import math

import bmesh
import bpy
from mathutils import Vector

PAINTS = {
    "white": "e8e2d2",
    "teak": "8a5a35",
    "canvas": "6b7458",
    "rope": "c9b07a",
    "dark": "1d1d20",
    "frame": "6b4426",
    "brass": "b8913a",
    "steel": "70757c",
    "bright_steel": "b5bcc0",
    "machine": "3b4a3f",
    "enamel": "f0ebdd",
    "gauge": "efe8d6",
    "chart": "e3d8b8",
    "upholstery": "7a2e2a",
}


def to_blender(p):
    return Vector((p[0], -p[2], p[1]))


def srgb(hex_colour):
    out = []
    for i in range(3):
        c = int(hex_colour[2 * i : 2 * i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def material(paint):
    found = bpy.data.materials.get(paint)
    if found is not None:
        return found
    made = bpy.data.materials.new(paint)
    made.diffuse_color = srgb(PAINTS[paint])
    made.use_nodes = True
    for node in made.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Base Color"].default_value = srgb(PAINTS[paint])
            node.inputs["Roughness"].default_value = 0.9
    return made


def newell(points):
    n = Vector((0.0, 0.0, 0.0))
    for k in range(len(points)):
        a = points[k]
        b = points[(k + 1) % len(points)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


class Part:
    """One object: one paint, its points in Godot space and its inked faces."""

    def __init__(self, name, paint):
        self.name = name
        self.paint = paint
        self.points = []
        self.faces = []

    def point(self, p):
        self.points.append(Vector(p))
        return len(self.points) - 1

    def face(self, indices, inks, outward=None):
        """A face over [indices] with [inks] per corner; flipped if its normal turns
        away from [outward] (a Godot-space vector) when given."""
        indices = list(indices)
        inks = list(inks)
        if outward is not None:
            n = newell([self.points[i] for i in indices])
            if n.dot(Vector(outward)) < 0.0:
                indices.reverse()
                inks.reverse()
        self.faces.append((indices, inks))

    def grid(self, rows, inks, outward, closed=False, row_inks=None):
        """Faces between consecutive rows of points (each a list of Godot points, all
        the same length): [inks] per column, or [row_inks] per row and column;
        [outward](point) the way out at a point. Closed joins the last column to
        the first."""
        ids = [[self.point(p) for p in row] for row in rows]
        columns = len(rows[0])
        made = []
        # One winding for the whole grid, the one most of its area agrees with: a lip
        # or a fold may face across the hint, but it is wound as its neighbours are.
        vote = 0.0
        for j in range(len(rows) - 1):
            for i in range(columns if closed else columns - 1):
                k = (i + 1) % columns
                quad = [ids[j][i], ids[j + 1][i], ids[j + 1][k], ids[j][k]]
                if row_inks is not None:
                    ink = [row_inks[j][i], row_inks[j + 1][i], row_inks[j + 1][k], row_inks[j][k]]
                else:
                    ink = [inks[i], inks[i], inks[k], inks[k]]
                middle = sum((self.points[q] for q in quad), Vector()) / 4.0
                vote += newell([self.points[q] for q in quad]).dot(Vector(outward(middle)))
                made.append((quad, ink))
        for quad, ink in made:
            if vote < 0.0:
                quad = list(reversed(quad))
                ink = list(reversed(ink))
            self.faces.append((quad, ink))
        return ids

    def fan(self, ring, outward, ink=1.0):
        """A flat cap over the closed ring of points, inked at its rim."""
        middle = sum((Vector(p) for p in ring), Vector()) / len(ring)
        centre = self.point(middle)
        ids = [self.point(p) for p in ring]
        for i in range(len(ids)):
            k = (i + 1) % len(ids)
            self.face([centre, ids[i], ids[k]], [0.0, ink, ink], outward)

    def build(self, collection, sharp_angle=35.0):
        bm = bmesh.new()
        ink_layer = bm.loops.layers.float_color.new("ink")
        verts = [bm.verts.new(to_blender(p)) for p in self.points]
        for indices, inks in self.faces:
            if len(set(indices)) < 3:
                continue
            face = bm.faces.new([verts[i] for i in indices])
            for loop, ink in zip(face.loops, inks):
                loop[ink_layer] = (ink, ink, ink, 1.0)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
        for face in bm.faces:
            face.smooth = True
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.set_sharp_from_angle(angle=math.radians(sharp_angle))
        mesh.color_attributes.active_color_name = "ink"
        mesh.materials.append(material(self.paint))
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        return obj


def fresh_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene.collection


def triangles(collection):
    count = 0
    for obj in collection.objects:
        for poly in obj.data.polygons:
            count += len(poly.vertices) - 2
    return count


def save(path):
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)


# The shapes the props are turned and built from, each into a Part, in Godot space.
# An ink row 1 marks a hard edge; the row beside it, RIM_LOOP or so away, carries 0.

RIM_LOOP = 0.015


def _add(*vectors):
    return [sum(v[i] for v in vectors) for i in range(3)]


def _scale(v, k):
    return [c * k for c in v]


def _dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def _cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def _unit(v):
    length = math.sqrt(_dot(v, v)) or 1.0
    return _scale(v, 1.0 / length)


def axes_along(w):
    """Two unit axes square to w and to each other, and w itself, made unit."""
    w = _unit(w)
    side = [0.0, 1.0, 0.0] if abs(w[1]) < 0.9 else [1.0, 0.0, 0.0]
    u = _unit(_cross(side, w))
    v = _cross(w, u)
    return u, v, w


def lathe(part, centre, axes, profile, sides, half=False):
    """A surface turned round the axis axes[2] through centre: profile a list of
    (radius, height along the axis, ink). Whole, or half — from axes[0] round through
    axes[1] to -axes[0] — for a column standing against a wall. Returns its rings."""
    u, v, w = axes
    count = sides + 1 if half else sides
    span = math.pi if half else 2.0 * math.pi
    rows = []
    for radius, height, _ in profile:
        row = []
        for k in range(count):
            a = span * k / sides
            row.append(_add(centre, _scale(u, radius * math.cos(a)), _scale(v, radius * math.sin(a)), _scale(w, height)))
        rows.append(row)
    inks = [[ink] * count for _, _, ink in profile]

    def out(middle):
        rel = [m - c for m, c in zip(middle, centre)]
        return [r - _dot(rel, w) * a for r, a in zip(rel, w)]

    part.grid(rows, None, out, closed=not half, row_inks=inks)
    return rows


def cap(part, ring, centre, outward, ink=1.0, closed=True):
    """A flat cap over ring round centre: inked at its rim, with a loop RIM_LOOP in when
    it is, so the ink stays a band. Closed joins the ring's last point to its first."""
    reach = math.sqrt(_dot([a - b for a, b in zip(ring[0], centre)], [a - b for a, b in zip(ring[0], centre)]))
    inner = ring
    if ink > 0.0 and reach > RIM_LOOP * 2.0:
        k = 1.0 - RIM_LOOP / reach
        inner = [_add(centre, _scale([p - c for p, c in zip(point, centre)], k)) for point in ring]
        outer_ids = [part.point(p) for p in ring]
        inner_ids = [part.point(p) for p in inner]
        for i in range(len(ring) if closed else len(ring) - 1):
            j = (i + 1) % len(ring)
            part.face([outer_ids[i], outer_ids[j], inner_ids[j], inner_ids[i]], [ink, ink, 0.0, 0.0], outward)
        ink = 0.0
    middle = part.point(centre)
    ids = [part.point(p) for p in inner]
    for i in range(len(ids) if closed else len(ids) - 1):
        j = (i + 1) % len(ids)
        part.face([middle, ids[i], ids[j]], [0.0, ink, ink], outward)


def tube(part, start, end, profile, sides, caps=(False, True)):
    """A turned piece from start toward end: profile (radius, share of the way, ink),
    capped at its first and its last ring as caps says."""
    length = math.sqrt(_dot([b - a for a, b in zip(start, end)], [b - a for a, b in zip(start, end)]))
    axes = axes_along([b - a for a, b in zip(start, end)])
    rows = lathe(part, start, axes, [(r, t * length, ink) for r, t, ink in profile], sides)
    if caps[0]:
        cap(part, rows[0], _add(start, _scale(axes[2], profile[0][1] * length)), _scale(axes[2], -1.0), profile[0][2])
    if caps[1]:
        cap(part, rows[-1], _add(start, _scale(axes[2], profile[-1][1] * length)), axes[2], profile[-1][2])
    return rows


def torus(part, centre, axes, major, minor, segments, sides):
    """A ring round the axis axes[2] through centre, of radius major, its section an
    ellipse minor (across, along the axis) — smooth, uninked."""
    u, v, w = axes
    rows = []
    for j in range(segments + 1):
        a = 2.0 * math.pi * j / segments
        d = _add(_scale(u, math.cos(a)), _scale(v, math.sin(a)))
        row = []
        for k in range(sides):
            b = 2.0 * math.pi * k / sides
            row.append(_add(centre, _scale(d, major + minor[0] * math.cos(b)), _scale(w, minor[1] * math.sin(b))))
        rows.append(row)

    def out(middle):
        rel = [m - c for m, c in zip(middle, centre)]
        flat = [r - _dot(rel, w) * a for r, a in zip(rel, w)]
        return [r - n for r, n in zip(rel, _scale(_unit(flat), major))]

    part.grid(rows, [0.0] * sides, out, closed=True)


def sphere(part, centre, radius, sides, rings):
    """A smooth, uninked ball of sides round its axis (up) and rings from pole to pole."""
    axes = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])
    profile = []
    for k in range(1, rings):
        t = math.pi * k / rings
        profile.append((radius * math.sin(t), -radius * math.cos(t), 0.0))
    rows = lathe(part, centre, axes, profile, sides)
    cap(part, rows[0], _add(centre, [0.0, -radius, 0.0]), [0.0, -1.0, 0.0], 0.0)
    cap(part, rows[-1], _add(centre, [0.0, radius, 0.0]), [0.0, 1.0, 0.0], 0.0)


def box(part, low, high, inked=True, rim=RIM_LOOP, skip=()):
    """An axis-aligned box from low to high, each face inked at its edges with a loop
    rim in (or plain when not inked); skip lists faces left off, as (axis, side) — a
    back against a wall is (2, -1)."""
    for axis in range(3):
        for side in (-1, 1):
            if (axis, side) in skip:
                continue
            a, b = [i for i in range(3) if i != axis]
            level = high[axis] if side > 0 else low[axis]
            corners = []
            for pa, pb in ((low[a], low[b]), (high[a], low[b]), (high[a], high[b]), (low[a], high[b])):
                p = [0.0, 0.0, 0.0]
                p[axis], p[a], p[b] = level, pa, pb
                corners.append(p)
            normal = [0.0, 0.0, 0.0]
            normal[axis] = float(side)
            if not inked:
                part.face([part.point(c) for c in corners], [0.0] * 4, normal)
                continue
            ra = min(rim, (high[a] - low[a]) * 0.3)
            rb = min(rim, (high[b] - low[b]) * 0.3)
            inner = []
            for c in corners:
                q = list(c)
                q[a] += ra if c[a] == low[a] else -ra
                q[b] += rb if c[b] == low[b] else -rb
                inner.append(q)
            outer_ids = [part.point(c) for c in corners]
            inner_ids = [part.point(c) for c in inner]
            for i in range(4):
                j = (i + 1) % 4
                part.face([outer_ids[i], outer_ids[j], inner_ids[j], inner_ids[i]], [1.0, 1.0, 0.0, 0.0], normal)
            part.face(inner_ids, [0.0] * 4, normal)


def slab(part, corners, normal, ink=0.0):
    """One flat face over corners (a polygon), facing normal."""
    part.face([part.point(c) for c in corners], [ink] * len(corners), normal)
