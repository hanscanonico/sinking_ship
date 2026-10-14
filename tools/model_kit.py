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
