"""`make preview`'s second half: the .glb tools/art_preview.gd writes — a ship's dressed
art, vertex-coloured — rendered to a PNG by Blender headless with Workbench, its studio
light on the paints' vertex colours. No game window, no window lock: the visual check
that works while none can be opened.

Points are Godot ship space, as `make capture` takes them: x toward her bow, y up, z to
starboard. EYE is the eye itself, not a seat's feet (capture's FROM= stands the eye
1.6 m over those).

    blender --background --factory-startup --python-exit-code 1 \
        --python tools/art_preview.py -- SHIP.glb OUT.png [--eye=x,y,z --at=x,y,z] \
        [--view=quarter] [--lens=35] [--res=1280x720]

Without --eye and --at the camera stands at VIEW (VIEWS below), as far off as frames all
of what the .glb holds; the eye, look-at point and lens it used are printed, in Godot
space, to move from. Runs on Blender 4.5 and 5.2: enums are read, never assumed, and the
render engine is set inside try/except, as tools/ship_blend.py and
assets/models/README.md say.
"""

import contextlib
import io
import os
import sys

import bpy
import numpy
from mathutils import Vector

# Per default view, the way from her middle out to the eye, in Godot space: a three-quarter
# view from fore and starboard above her, her starboard side, from overhead and her bow.
VIEWS = {
    "quarter": (1.0, 0.7, 1.2),
    "side": (0.0, 0.15, 1.0),
    "top": (0.0, 1.0, 0.02),
    "bow": (1.0, 0.35, 0.35),
}
# How much room a default view leaves round what it frames.
MARGIN = 1.08
# The camera's sensor width in millimetres, against which its lens is measured.
SENSOR = 36.0


def to_blender(point):
    x, y, z = point
    return Vector((x, -z, y))


def to_godot(point):
    return (point.x, point.z, -point.y)


def triple(text):
    values = [float(value) for value in text.split(",")]
    if len(values) != 3:
        raise ValueError("%s is not x,y,z" % text)
    return values


def options(args):
    found = {"view": "quarter", "lens": "35", "res": "1280x720"}
    paths = []
    for arg in args:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            found[key] = value
        else:
            paths.append(arg)
    if len(paths) != 2:
        sys.exit("art_preview: give the .glb and the .png, then any --eye= --at= --view= --lens= --res=")
    if ("eye" in found) != ("at" in found):
        sys.exit("art_preview: --eye and --at go together")
    if found["view"] not in VIEWS:
        sys.exit("art_preview: --view is one of %s" % ", ".join(VIEWS))
    return paths[0], paths[1], found


def enum_of(owner, prop):
    return [item.identifier for item in owner.bl_rna.properties[prop].enum_items]


def set_enum(owner, prop, wanted):
    """Sets [prop] to the first of [wanted] that this Blender has; says which."""
    known = enum_of(owner, prop)
    for value in wanted:
        if value in known:
            setattr(owner, prop, value)
            return value
    return getattr(owner, prop)


def use_workbench(scene):
    """Workbench, by whatever name this Blender gives it."""
    if "WORKBENCH" in scene.render.engine:
        return
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError as error:
        # The message lists the engines there are: take the one that is Workbench.
        names = [part.strip(" '()") for part in str(error).split("in (")[-1].split(",")]
        workbench = [name for name in names if "WORKBENCH" in name]
        if not workbench:
            sys.exit("art_preview: this Blender has no Workbench engine: %s" % error)
        scene.render.engine = workbench[0]


def corners(objects):
    """Every vertex of [objects], in Blender space: an N x 3 array."""
    found = []
    for item in objects:
        mesh = item.data
        flat = numpy.empty(len(mesh.vertices) * 3, dtype=numpy.float64)
        mesh.vertices.foreach_get("co", flat)
        local = flat.reshape(-1, 3)
        place = numpy.array(item.matrix_world)
        found.append(local @ place[:3, :3].T + place[:3, 3])
    return numpy.concatenate(found)


def framed(points, way, lens, width, height):
    """An eye and a look-at point that frame every one of [points] seen from [way]."""
    back = to_blender(way).normalized()
    up = Vector((0.0, 0.0, 1.0))
    right = up.cross(back)
    if right.length < 1e-6:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    upward = back.cross(right).normalized()
    # Her middle as seen from there: halfway across what she covers each way.
    sideways = points @ numpy.array(right)
    heights = points @ numpy.array(upward)
    depths = points @ numpy.array(back)
    middle = (
        right * float(sideways.min() + sideways.max()) / 2.0
        + upward * float(heights.min() + heights.max()) / 2.0
        + back * float(depths.min() + depths.max()) / 2.0
    )
    major = SENSOR / 2.0 / lens
    across = major if width >= height else major * width / height
    down = major * height / width if width >= height else major
    ahead = depths - middle.dot(back)
    reach = max(
        float((numpy.abs(sideways - middle.dot(right)) / across + ahead).max()),
        float((numpy.abs(heights - middle.dot(upward)) / down + ahead).max()),
    )
    return middle + back * reach * MARGIN, middle


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    glb, out, found = options(args)
    lens = float(found["lens"])
    width, height = (int(value) for value in found["res"].lower().split("x"))
    for item in list(bpy.data.objects):
        bpy.data.objects.remove(item, do_unlink=True)
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.import_scene.gltf(filepath=glb)
    meshes = [item for item in bpy.data.objects if item.type == "MESH"]
    if not meshes:
        sys.exit("art_preview: %s holds no meshes" % glb)
    for item in meshes:
        colours = item.data.color_attributes
        if len(colours) > 0 and colours.active_color is None:
            colours.active_color = colours[0]
    if "eye" in found:
        eye, at = to_blender(triple(found["eye"])), to_blender(triple(found["at"]))
    else:
        eye, at = framed(corners(meshes), VIEWS[found["view"]], lens, width, height)
    scene = bpy.context.scene
    camera = bpy.data.objects.new("eye", bpy.data.cameras.new("eye"))
    scene.collection.objects.link(camera)
    camera.data.lens = lens
    camera.data.sensor_width = SENSOR
    camera.data.clip_start = 0.05
    camera.data.clip_end = max(2000.0, (eye - at).length * 4.0)
    camera.location = eye
    camera.rotation_euler = (at - eye).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    use_workbench(scene)
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    shading = scene.display.shading
    set_enum(shading, "light", ["STUDIO"])
    set_enum(shading, "color_type", ["VERTEX"])
    shading.show_shadows = True
    shading.show_cavity = True
    set_enum(scene.view_settings, "view_transform", ["Standard"])
    set_enum(scene.render.image_settings, "file_format", ["PNG"])
    # Blender reads a relative path against its own, not the caller's, directory.
    out = os.path.abspath(out)
    scene.render.filepath = out
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.render.render(write_still=True)
    if not os.path.isfile(out):
        sys.exit("art_preview: Blender wrote no %s" % out)
    print(
        "art_preview: %s -> %s, EYE=%s AT=%s LENS=%g RES=%dx%d"
        % (
            glb,
            out,
            ",".join("%.1f" % value for value in to_godot(eye)),
            ",".join("%.1f" % value for value in to_godot(at)),
            lens,
            width,
            height,
        )
    )


main()
