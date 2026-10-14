"""`make models`: exports one Blender model of a ship's prop to its .glb, as
assets/models/README.md says a model is authored. Blender runs it headless:

    blender --background MODEL.blend --python-exit-code 1 \
        --python tools/export_model.py -- MODEL.glb

It refuses, naming the object, any mesh with no material or without the colour
attribute named `ink` (the rim's weight, ShipMesh.model), then writes the glTF
binary: Godot's axes (+Y up), modifiers applied, normals and the ink layer as the
vertex colour, materials by name only. No UVs, tangents, animation, cameras or lights.
A world mesh that is no ship's prop names the colour attribute it carries instead in
its scene's `colour_layer` (the iceberg's `ice`, tools/berg_kit.py).
"""

import sys

import bpy

INK = "ink"


def layer():
    return bpy.context.scene.get("colour_layer", INK)


def problems():
    found = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        if not mesh.materials or any(material is None for material in mesh.materials):
            found.append("%s has a face with no material" % obj.name)
        if mesh.color_attributes.get(layer()) is None:
            found.append("%s has no colour attribute named %s" % (obj.name, layer()))
    return found


def main():
    if "--" not in sys.argv or len(sys.argv) <= sys.argv.index("--") + 1:
        sys.exit("export_model: the .glb to write is required after --")
    out = sys.argv[sys.argv.index("--") + 1]
    found = problems()
    for problem in found:
        print("export_model: %s: %s" % (bpy.data.filepath, problem), file=sys.stderr)
    if found:
        sys.exit(1)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_normals=True,
        export_texcoords=False,
        export_tangents=False,
        export_vertex_color="NAME",
        export_vertex_color_name=layer(),
        export_all_vertex_colors=False,
        export_materials="EXPORT",
        export_animations=False,
        export_skins=False,
        export_morph=False,
        export_cameras=False,
        export_lights=False,
        export_extras=False,
    )
    print("export_model: %s -> %s" % (bpy.data.filepath, out))


main()
