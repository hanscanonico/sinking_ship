"""A ship's layout authored in Blender (#125): authoring/NAME/NAME.blend, the data the
sim reads (ShipLayout, D6) as Blender objects. Blender authors the data only; the hull
the game draws stays generated from it. authoring/README.md says how a ship is authored.

Blender runs it headless, two ways:

    blender --background --factory-startup --python-exit-code 1 \
        --python tools/ship_blend.py -- build PIECES.json NAME.blend
    blender --background --factory-startup NAME.blend --python-exit-code 1 \
        --python tools/ship_blend.py -- export NAME.glb

build: `make ship-blend` — the pieces Godot laid a ship out as (ShipGltf.pieces, from
the scene ShipSceneDraw draws) built as objects, each with the custom property `ship`
and its fields, and saved. A box, a cylinder, a wedge or a section is a mesh in its
object's frame, a point or a folder an empty. A number before a name orders an object
among its siblings, as the glTF export lists them by name.

export: `make bake-blend`, `make bake-check` — the .blend written as the glTF binary
Godot reads it back from (ShipGltf.read): Godot's axes (+Y up), every object's custom
properties as its node's extras, no materials, nothing else.
"""

import json
import math
import sys

import bpy

# Godot's frame (+Y up, +Z toward the viewer) into Blender's (+Z up): (x, y, z) is
# (x, -z, y), the turn the glTF export turns back.
AXES = ((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0))
# A drawn cylinder's sides: a multiple of four, so it reaches its radius on x and z.
SIDES = 16
# How wide an empty is drawn.
EMPTY_SIZE = 0.3


def to_blender(point):
    x, y, z = point
    return (x, -z, y)


def matrix_of(piece):
    """The piece's place as a Blender matrix: its Godot basis and origin, turned."""
    from mathutils import Matrix

    columns = piece["basis"]
    godot = Matrix(
        (
            (columns[0], columns[3], columns[6], piece["origin"][0]),
            (columns[1], columns[4], columns[7], piece["origin"][1]),
            (columns[2], columns[5], columns[8], piece["origin"][2]),
            (0.0, 0.0, 0.0, 1.0),
        )
    )
    turn = Matrix(AXES).to_4x4()
    return turn @ godot @ turn.inverted()


def box(size):
    """A box's corners and faces about its centre; a box flat on an axis is one face."""
    half = [value * 0.5 for value in size]
    flat = [axis for axis in range(3) if half[axis] == 0.0]
    if flat:
        a, b = [axis for axis in range(3) if axis != flat[0]]
        corners = []
        for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            corner = [0.0, 0.0, 0.0]
            corner[a] = u * half[a]
            corner[b] = v * half[b]
            corners.append(tuple(corner))
        return corners, [(0, 1, 2, 3)]
    x, y, z = half
    corners = [(sx * x, sy * y, sz * z) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    faces = [
        (0, 1, 3, 2),
        (4, 6, 7, 5),
        (0, 4, 5, 1),
        (2, 3, 7, 6),
        (0, 2, 6, 4),
        (1, 5, 7, 3),
    ]
    return corners, faces


def cylinder(radius, height):
    """An upright cylinder about its centre, its first corner on +x."""
    corners = []
    for y in (-height * 0.5, height * 0.5):
        for side in range(SIDES):
            turn = 2.0 * math.pi * side / SIDES
            x = radius * round_unit(math.cos(turn))
            corners.append((x, y, radius * round_unit(math.sin(turn))))
    faces = [tuple(range(SIDES - 1, -1, -1)), tuple(range(SIDES, 2 * SIDES))]
    for side in range(SIDES):
        after = (side + 1) % SIDES
        faces.append((side, after, SIDES + after, SIDES + side))
    return corners, faces


def round_unit(value):
    """A cosine or sine, its quarter turns exact."""
    for exact in (-1.0, 0.0, 1.0):
        if abs(value - exact) < 1e-12:
            return exact
    return value


def wedge(size, apex):
    """A wedge as Godot's PrismMesh draws one: its top edge at `apex` along its x."""
    x, y, z = [value * 0.5 for value in size]
    top = -x + apex * 2.0 * x
    corners = [
        (-x, -y, -z),
        (x, -y, -z),
        (x, -y, z),
        (-x, -y, z),
        (top, y, -z),
        (top, y, z),
    ]
    return corners, [(0, 3, 2, 1), (0, 1, 4), (2, 3, 5), (1, 2, 5, 4), (3, 0, 4, 5)]


def section(outline, depth):
    """A hull section: its outline in local x and y, the face at z 0 wound as the outline
    runs, extruded to -depth."""
    count = len(outline) // 2
    corners = [(outline[2 * i], outline[2 * i + 1], 0.0) for i in range(count)]
    corners += [(outline[2 * i], outline[2 * i + 1], -depth) for i in range(count)]
    faces = [tuple(range(count)), tuple(range(2 * count - 1, count - 1, -1))]
    for i in range(count):
        after = (i + 1) % count
        faces.append((after, i, count + i, count + after))
    return corners, faces


def shape_of(piece):
    shape = piece["shape"]
    if shape == "box":
        return box(piece["size"])
    if shape == "cylinder":
        return cylinder(piece["radius"], piece["height"])
    if shape == "wedge":
        return wedge(piece["size"], piece["apex"])
    if shape == "section":
        return section(piece["outline"], piece["depth"])
    return None


def material_of(kind, colour, materials):
    if kind not in materials:
        material = bpy.data.materials.new("ship_" + kind)
        material.diffuse_color = colour
        principled = next(
            (node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None
        )
        if principled is not None:
            principled.inputs["Base Color"].default_value = colour
            principled.inputs["Alpha"].default_value = colour[3]
        if colour[3] < 1.0:
            material.surface_render_method = "BLENDED"
        materials[kind] = material
    return materials[kind]


def build(pieces_path, out):
    with open(pieces_path) as file:
        pieces = json.load(file)
    for item in list(bpy.data.objects):
        bpy.data.objects.remove(item)
    collection = bpy.context.scene.collection
    made = []
    materials = {}
    hidden = []
    order = {}
    for piece in pieces:
        parent = piece["parent"]
        rank = order.get(parent, 0)
        order[parent] = rank + 1
        name = piece["name"] if parent == -1 else "%04d %s" % (rank, piece["name"])
        shape = shape_of(piece)
        kind = piece["meta"].get("ship", "")
        if shape is None:
            item = bpy.data.objects.new(name, None)
            item.empty_display_type = "PLAIN_AXES" if piece["shape"] == "marker" else "CUBE"
            item.empty_display_size = EMPTY_SIZE if piece["shape"] == "marker" else 0.1
        else:
            mesh = bpy.data.meshes.new(name)
            corners, faces = shape
            mesh.from_pydata([to_blender(corner) for corner in corners], [], faces)
            mesh.update()
            if "colour" in piece:
                mesh.materials.append(material_of(kind, piece["colour"], materials))
            item = bpy.data.objects.new(name, mesh)
        if item.name != name:
            sys.exit("ship_blend: two objects are named %s" % name)
        collection.objects.link(item)
        if parent != -1:
            item.parent = made[parent]
        item.matrix_basis = matrix_of(piece)
        for key, value in piece["meta"].items():
            item[key] = value
        if not piece["visible"]:
            hidden.append(item)
        made.append(item)
    for item in hidden:
        item.hide_set(True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
    print("ship_blend: %d objects -> %s" % (len(made), out))


def export(out):
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_normals=False,
        export_texcoords=False,
        export_tangents=False,
        export_materials="NONE",
        export_animations=False,
        export_skins=False,
        export_morph=False,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
        use_visible=False,
    )
    print("ship_blend: %s -> %s" % (bpy.data.filepath, out))


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if len(args) == 3 and args[0] == "build":
        build(args[1], args[2])
    elif len(args) == 2 and args[0] == "export":
        export(args[1])
    else:
        sys.exit("ship_blend: build PIECES.json OUT.blend, or export OUT.glb, after --")


main()
