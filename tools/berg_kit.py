"""The iceberg's build scripts' shared builder (assets/models/iceberg_*/iceberg_*.py),
which headless Blender runs to make each NAME.blend (`make model-sources`).

A berg is a world mesh, not a ship's prop: IcebergPlanner reads its faces and their
colours, scales it uniformly to the height it gives the match's berg, and Iceberg
draws it with iceberg.gdshader. So it is modelled to the planner's measure, in Godot's
axes and metres:

- the sea at y = 0, every face wholly over it or wholly under it (a waterline loop);
- its top at y = HEIGHT (IcebergPlanner.BERG_HEIGHT) and its foot at
  y = -HEIGHT * DRAUGHT * FOOT (IcebergPlanner.DRAUGHT, FOOT);
- square across x = 0, half as wide over all as SPREAD of its height says;
- its side toward her along +z: nothing under the sea stands nearer her than the
  furthest it reaches over the sea, but the spur, a ram under the sea whose blade is
  the two points furthest along +z, both at x = 0, one over the other. The planner
  draws the blade out to her shell and up and down to the gash's depths.

Each face carries its colour as the colour attribute `ice` on its corners, linear:
ice facing up, shade on the steep faces, under-ice under the sea, no two faces quite
alike. The scene's `colour_layer` tells tools/export_model.py to export `ice` in
place of the props' `ink`.
"""

import random

import bmesh
import bpy
from mathutils import Vector

from model_kit import fresh_scene, save, srgb, to_blender

HEIGHT = 10.0
DRAUGHT = 2.0
FOOT = 1.05
LAYER = "ice"
# The ice facing up, on its steep faces and under the sea (the procedural berg's).
ICE = "dfe8ee"
ICE_SHADE = "a9c3d3"
ICE_UNDER = "4f8f9e"
# The spur: how far its blade stands out past the rest, and its root's and blade's
# heights, in metres, as modelled; the planner moves its blade.
SPUR_OUT = 1.5
SPUR_ROOT = (-0.3, -8.0)
SPUR_BLADE = (-0.5, -5.0)
SPUR_HALF = 0.9
SPUR_DEPTH = 3.0


def footprint(corners, rng, chamfer=0.07, notch=0.07):
    """A blocky outline from its main [corners] (x, z): each corner cut back toward
    both neighbours, and a point between corners pushed in or out a little."""
    out = []
    count = len(corners)
    for i in range(count):
        c = Vector(corners[i])
        p = Vector(corners[i - 1])
        n = Vector(corners[(i + 1) % count])
        out.append(c + (p - c) * chamfer)
        out.append(c + (n - c) * chamfer)
        edge = n - c
        across = Vector((edge.y, -edge.x)).normalized()
        middle = c + edge * rng.uniform(0.4, 0.6)
        out.append(middle + across * rng.uniform(-notch, notch) * edge.length)
    return out


def ring(outline, y, width, rng, offset=(0.0, 0.0), jitter=0.03, rise=0.0, tilt=None):
    """[outline] at height [y], [width] times as wide round [offset], each corner
    stood out unevenly by [jitter] and up by up to [rise]; [tilt](x, z) raises it
    where given."""
    points = []
    for x, z in outline:
        grow = width * (1.0 + rng.uniform(-jitter, jitter))
        px = x * grow + offset[0]
        pz = z * grow + offset[1]
        py = y + (rng.uniform(-rise, rise) if rise > 0.0 else 0.0)
        if tilt is not None:
            py += tilt(px, pz)
        points.append([px, py, pz])
    return points


class Loft:
    """One mass of ice: rings of points stacked from its foot to its top, an optional
    foot point under the lowest, and a cap over the highest."""

    def __init__(self, rings, foot=None, top=None, inner=0.55, lift=0.25):
        self.rings = rings
        self.foot = foot
        self.top = top
        self.inner = inner
        self.lift = lift

    def points(self):
        found = [p for r in self.rings for p in r]
        if self.foot is not None:
            found.append(self.foot)
        return found

    def faces(self, rng):
        """Its faces, each a list of points, wound outward."""
        made = []
        for low, high in zip(self.rings, self.rings[1:]):
            for i in range(len(low)):
                k = (i + 1) % len(low)
                made.append([low[i], low[k], high[k], high[i]])
        last = self.rings[-1]
        middle = [sum(p[j] for p in last) / len(last) for j in range(3)]
        inner = []
        for p in last:
            inner.append(
                [
                    middle[0] + (p[0] - middle[0]) * self.inner,
                    p[1] + self.lift * rng.uniform(0.3, 1.0),
                    middle[2] + (p[2] - middle[2]) * self.inner,
                ]
            )
        for i in range(len(last)):
            k = (i + 1) % len(last)
            made.append([last[i], last[k], inner[k], inner[i]])
        crown = sum(p[1] for p in inner) / len(inner) + self.lift * 0.5
        top = self.top if self.top is not None else [middle[0], crown, middle[2]]
        for i in range(len(inner)):
            k = (i + 1) % len(inner)
            made.append([inner[i], inner[k], top])
        # Closed underneath: down to its foot, or a flat floor hidden in the ice it
        # stands on.
        first = self.rings[0]
        foot = self.foot
        if foot is None:
            foot = [sum(p[j] for p in first) / len(first) for j in range(3)]
        for i in range(len(first)):
            k = (i + 1) % len(first)
            made.append([first[k], first[i], foot])
        return made


def fit(lofts, spread):
    """Stands [lofts] square across x = 0 and stretches them about the y axis, x and z
    alike, so they are as wide over all as [spread] of HEIGHT each side."""
    points = [p for loft in lofts for p in loft.points()]
    low = min(p[0] for p in points)
    high = max(p[0] for p in points)
    scale = spread * HEIGHT / ((high - low) * 0.5)
    middle = (low + high) * 0.5
    for loft in lofts:
        for p in loft.points():
            p[0] = (p[0] - middle) * scale
            p[2] = p[2] * scale


def shade(normal, centre, rng):
    """A face's colour, linear: ice, bluer the steeper; under-ice under the sea; each
    face a little lighter or darker than the next."""
    if centre.z < 0.0:
        colour = srgb_plain(ICE_UNDER)
    else:
        up = abs(normal.z)
        colour = [s + (i - s) * up for s, i in zip(srgb_plain(ICE_SHADE), srgb_plain(ICE))]
    jitter = rng.uniform(0.9, 1.04)
    out = []
    for c in colour:
        c = min(c * jitter, 1.0)
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def srgb_plain(hex_colour):
    return [int(hex_colour[2 * i : 2 * i + 2], 16) / 255.0 for i in range(3)]


def build(name, lofts, spread, seed):
    """Fits [lofts] to the planner's measure, adds the spur toward her, and writes
    the berg as one object [name] with its faces' colours; returns its triangles."""
    rng = random.Random(seed)
    fit(lofts, spread)
    foot_y = -HEIGHT * DRAUGHT * FOOT
    faces = []
    for loft in lofts:
        faces.extend(loft.faces(rng))
    # Its top and foot exactly where the planner measures them from: what stands over
    # the sea stood up or down to HEIGHT, nothing under its foot.
    every = list({id(p): p for face in faces for p in face}.values())
    top = max(p[1] for p in every)
    for p in every:
        if p[1] > 0.0:
            p[1] *= HEIGHT / top
        p[1] = max(p[1], foot_y)
    # Nothing under the sea nearer her than the most it reaches over it.
    inboard = max(p[2] for p in every if p[1] >= 0.0)
    for p in every:
        if p[1] < 0.0:
            p[2] = min(p[2], inboard)
    faces.extend(spur(inboard))
    return write(name, faces, rng)


def spur(inboard):
    """The ram under the sea toward her: a wedge from a root deep in the ice out to
    its blade, the two points furthest along +z."""
    root_z = inboard - SPUR_DEPTH
    tip_z = inboard + SPUR_OUT
    rt = [[-SPUR_HALF, SPUR_ROOT[0], root_z], [SPUR_HALF, SPUR_ROOT[0], root_z]]
    rb = [[-SPUR_HALF, SPUR_ROOT[1], root_z], [SPUR_HALF, SPUR_ROOT[1], root_z]]
    bt = [0.0, SPUR_BLADE[0], tip_z]
    bb = [0.0, SPUR_BLADE[1], tip_z]
    return [
        [rt[0], rt[1], bt],
        [rb[1], rb[0], bb],
        [rt[1], rb[1], bb, bt],
        [rb[0], rt[0], bt, bb],
        [rt[0], rb[0], rb[1], rt[1]],
    ]


def write(name, faces, rng):
    collection = fresh_scene()
    bpy.context.scene["colour_layer"] = LAYER
    bm = bmesh.new()
    layer = bm.loops.layers.float_color.new(LAYER)
    verts = {}

    def vert(p):
        key = tuple(round(c, 5) for c in p)
        if key not in verts:
            verts[key] = bm.verts.new(to_blender(p))
        return verts[key]

    for face in faces:
        corners = [vert(p) for p in face]
        if len(set(corners)) < len(corners):
            continue
        try:
            bm.faces.new(corners)
        except ValueError:
            continue
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    # Every mass is closed: each face turned out of the one it bounds.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    for face in bm.faces:
        face.smooth = False
        centre = face.calc_center_median()
        colour = shade(face.normal, centre, rng)
        for loop in face.loops:
            loop[layer] = colour
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    count = len(bm.faces)
    bm.free()
    mesh.color_attributes.active_color_name = LAYER
    mesh.materials.append(material())
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return count


def material():
    made = bpy.data.materials.new("ice")
    made.diffuse_color = srgb(ICE)
    made.use_nodes = True
    for node in made.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Base Color"].default_value = srgb(ICE)
            node.inputs["Roughness"].default_value = 0.7
    return made


def under_rings(outline, rng, offset=(0.0, 0.0)):
    """The mass under the sea every berg stands on, from its foot up to the waterline
    ring: wider than it is over the sea, as ice is."""
    return [
        ring(outline, -19.0, 0.4, rng, offset, 0.08, 0.6),
        ring(outline, -15.0, 0.85, rng, offset, 0.06, 0.6),
        ring(outline, -10.0, 1.05, rng, offset, 0.05, 0.5),
        ring(outline, -5.0, 1.08, rng, offset, 0.04, 0.4),
        ring(outline, -1.6, 1.0, rng, offset, 0.03, 0.2),
        ring(outline, 0.0, 0.94, rng, offset, 0.02),
    ]


def foot_point(offset=(0.0, 0.0)):
    return [offset[0], -HEIGHT * DRAUGHT * FOOT, offset[1] - 0.1]


def main(name, lofts, spread, seed, out):
    count = build(name, lofts, spread, seed)
    print("%s: %d triangles" % (name, count))
    save(out)


