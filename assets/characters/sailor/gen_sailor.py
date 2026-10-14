"""`make sailor`: builds the brawlers' sailor in Blender, headless, from nothing.

    blender --background --factory-startup --python-exit-code 1 \
        --python assets/characters/sailor/gen_sailor.py -- sailor.blend sailor.glb

It makes, from the numbers below and nothing else:
- the rig: an armature of our own bones (BONES), standing at rest with its arms out
  along x, its palms down and its thumbs ahead;
- the body: one closed surface grown over a stick figure (Blender's skin modifier,
  then one round of subdivision), pressed into a brawler's build (BULGES) and
  skinned to the rig with Blender's automatic weights, at most four bones a point;
- the fingers and thumbs: closed shells of their own set into the palms (FINGERS,
  THUMB_STATIONS), weighted by hand to the finger and thumb bones;
- the clips the game plays (CLIPS), keyed every frame from poses written in code;
- the .blend, saved, and the .glb Godot loads, exported from it.

Every number is in the game's model frame and units, as Brawler and its shader read
them: +y up, +z ahead (the way the face looks), +x the body's left; the soles at 0
and the crown at 1.83. The export turns Blender's axes into Godot's: Godot (x, y, z)
is Blender (x, -z, y). assets/characters/sailor/README.md says how the sailor is
drawn and what the game expects of it.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 30
## Godot's model frame into Blender's, for a point or a direction.
TO_BLENDER = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))
## Mirrors the left of the body onto its right.
MIRROR = Matrix(((-1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)))
AHEAD = Vector((0.0, 0.0, 1.0))
UP = Vector((0.0, 1.0, 0.0))
DOWN = Vector((0.0, -1.0, 0.0))

# ---------------------------------------------------------------------------
# The rig. Each bone: its parent, its head and tail in the model frame, and the
# way its local z faces at rest (its roll). The left side is listed; the right is
# its mirror, `_l` turned `_r`.

TRUNK = [
    ("root", None, (0.0, 0.0, 0.0), (0.0, 0.0, -0.2), UP),
    ("pelvis", "root", (0.0, 0.92, -0.02), (0.0, 1.05, -0.02), AHEAD),
    ("spine_01", "pelvis", (0.0, 1.05, -0.02), (0.0, 1.18, -0.02), AHEAD),
    ("spine_02", "spine_01", (0.0, 1.18, -0.02), (0.0, 1.32, -0.025), AHEAD),
    ("chest", "spine_02", (0.0, 1.32, -0.025), (0.0, 1.49, -0.025), AHEAD),
    ("neck", "chest", (0.0, 1.49, -0.025), (0.0, 1.57, -0.005), AHEAD),
    ("head", "neck", (0.0, 1.57, -0.005), (0.0, 1.83, -0.005), AHEAD),
]
SIDE = [
    ("clavicle", "chest", (0.03, 1.455, 0.0), (0.17, 1.44, -0.04), AHEAD),
    ("upperarm", "clavicle", (0.17, 1.44, -0.04), (0.455, 1.44, -0.04), AHEAD),
    ("lowerarm", "upperarm", (0.455, 1.44, -0.04), (0.735, 1.44, -0.04), AHEAD),
    ("hand", "lowerarm", (0.735, 1.44, -0.04), (0.815, 1.435, -0.04), AHEAD),
    ("fingers", "hand", (0.815, 1.435, -0.04), (0.86, 1.432, -0.04), AHEAD),
    ("fingertips", "fingers", (0.86, 1.432, -0.04), (0.905, 1.43, -0.04), AHEAD),
    ("thumb", "hand", (0.75, 1.425, -0.005), (0.785, 1.42, 0.025), UP),
    ("thumbtip", "thumb", (0.785, 1.42, 0.025), (0.81, 1.418, 0.05), UP),
    ("thigh", "pelvis", (0.09, 0.92, -0.01), (0.09, 0.52, 0.0), AHEAD),
    ("calf", "thigh", (0.09, 0.52, 0.0), (0.09, 0.1, -0.03), AHEAD),
    ("foot", "calf", (0.09, 0.1, -0.03), (0.09, 0.035, 0.09), UP),
    ("toe", "foot", (0.09, 0.035, 0.09), (0.09, 0.03, 0.155), UP),
]


def _mirror_name(name):
    return name[:-2] + "_r" if name.endswith("_l") else name


def bones():
    """Every bone, parents first: (name, parent, head, tail, roll), the model frame."""
    found = [(n, p, Vector(h), Vector(t), z) for n, p, h, t, z in TRUNK]
    for suffix, flip in (("_l", False), ("_r", True)):
        for name, parent, head, tail, roll in SIDE:
            head = Vector(head)
            tail = Vector(tail)
            if flip:
                head = MIRROR @ head
                tail = MIRROR @ tail
            side_parent = parent + suffix if parent not in [t[0] for t in TRUNK] else parent
            found.append((name + suffix, side_parent, head, tail, roll))
    return found


# ---------------------------------------------------------------------------
# The body: a stick figure, each node a point in the model frame and the
# half-widths of the body round it, each limb a run of nodes from the trunk out.
# The skin modifier grows a closed surface over it and one round of subdivision
# smooths it; the fingers and thumbs are closed shells of their own, set into the
# palms (HANDS). Proportions are a brawler's: a small head on a thick neck, broad
# shoulders and a deep chest over a narrower waist, arms with a bicep and a
# forearm to them.

## The trunk, hips to crown: (name, at, (across, deep)), its half-widths along x
## and z. The head stays inside the hats BrawlerHat builds round it.
TRUNK_NODES = [
    ("hips", (0.0, 0.92, -0.015), (0.152, 0.125)),
    ("waist", (0.0, 1.04, 0.0), (0.128, 0.11)),
    ("belly", (0.0, 1.13, 0.004), (0.136, 0.11)),
    ("ribs", (0.0, 1.21, 0.008), (0.18, 0.145)),
    ("chest", (0.0, 1.295, 0.012), (0.215, 0.165)),
    ("yoke", (0.0, 1.43, -0.015), (0.165, 0.165)),
    ("neck_base", (0.0, 1.51, -0.025), (0.118, 0.094)),
    ("neck", (0.0, 1.546, -0.026), (0.058, 0.062)),
    ("chin", (0.0, 1.588, 0.024), (0.078, 0.09)),
    ("jaw", (0.0, 1.628, 0.012), (0.09, 0.104)),
    ("cheek", (0.0, 1.69, 0.006), (0.096, 0.116)),
    ("brow", (0.0, 1.752, -0.008), (0.1, 0.12)),
    ("crown", (0.0, 1.826, -0.014), (0.07, 0.082)),
]
## An arm, the shoulder out to the palm: (name, at, (deep, high), link), its
## half-widths along z and y; link is the trunk node it grows from.
ARM_NODES = [
    ("shoulder", (0.205, 1.432, -0.03), (0.11, 0.1), "yoke"),
    ("delt", (0.265, 1.434, -0.035), (0.1, 0.095), None),
    ("bicep", (0.345, 1.437, -0.04), (0.082, 0.084), None),
    ("elbow", (0.45, 1.44, -0.04), (0.058, 0.058), None),
    ("forearm", (0.545, 1.44, -0.04), (0.072, 0.066), None),
    ("wrist", (0.722, 1.44, -0.04), (0.048, 0.037), None),
    ("palm", (0.77, 1.438, -0.04), (0.068, 0.032), None),
    ("palm_end", (0.806, 1.437, -0.04), (0.066, 0.029), None),
]
## A leg, the hip down to the heel: (name, at, (across, deep), link).
LEG_NODES = [
    ("hip", (0.09, 0.82, -0.01), (0.09, 0.1), "hips"),
    ("thigh", (0.092, 0.68, 0.0), (0.086, 0.094), None),
    ("knee", (0.092, 0.51, 0.004), (0.062, 0.068), None),
    ("calf", (0.091, 0.37, -0.016), (0.068, 0.076), None),
    ("ankle", (0.09, 0.14, -0.025), (0.048, 0.052), None),
    ("heel", (0.09, 0.05, -0.04), (0.056, 0.056), None),
]
## A boot, the ankle out to the toe cap: (name, at, radius, link).
FOOT_NODES = [
    ("instep", (0.09, 0.062, 0.06), 0.06, "ankle"),
    ("toe", (0.09, 0.048, 0.165), 0.054, None),
]
## The fingers of a left hand, set side by side into its palm (thumb side first):
## each its offset across the palm (along z) and its length as a share of the
## middle finger's. Each runs from inside the palm through its knuckle, its middle
## joint and its tip, a tube of FINGER_SIDES faces round; the right hand is the
## mirror.
FINGERS = [(0.0435, 0.95), (0.0145, 1.0), (-0.0145, 0.95), (-0.0435, 0.82)]
FINGER_SIDES = 8
## Along a finger, from the palm's middle line (x, the height over the palm's
## middle y and the half-widths across and through): inside the palm, the
## knuckle, the middle joint, the tip, its rounding and its end. The knuckle and the
## joint sit at the fingers' and fingertips' bones' heads, and are shared by them.
PALM_Y = 1.437
FINGER_STATIONS = [
    (0.79, 0.001, 0.0128, 0.0128),
    (0.817, 0.003, 0.0148, 0.0172),
    (0.86, -0.001, 0.014, 0.0146),
    (0.895, -0.002, 0.0126, 0.0126),
    (0.906, -0.003, 0.0098, 0.0098),
    (0.912, -0.003, 0.0, 0.0),
]
## The thumb of a left hand: each station's point and half-widths, from the heel
## of the palm out to the tip.
THUMB_STATIONS = [
    ((0.758, 1.43, -0.026), 0.02, 0.019),
    ((0.772, 1.427, 0.004), 0.0195, 0.0185),
    ((0.789, 1.423, 0.03), 0.0165, 0.0155),
    ((0.803, 1.42, 0.048), 0.0142, 0.0136),
    ((0.809, 1.419, 0.057), 0.011, 0.0105),
    ((0.812, 1.419, 0.063), 0.0, 0.0),
]
## Each station's bones and their shares: a finger's and the thumb's.
FINGER_WEIGHTS = [
    {"hand": 1.0},
    {"hand": 0.5, "fingers": 0.5},
    {"fingers": 0.5, "fingertips": 0.5},
    {"fingertips": 1.0},
    {"fingertips": 1.0},
    {"fingertips": 1.0},
]
THUMB_WEIGHTS = [
    {"hand": 1.0},
    {"hand": 0.6, "thumb": 0.4},
    {"thumb": 0.5, "thumbtip": 0.5},
    {"thumbtip": 1.0},
    {"thumbtip": 1.0},
    {"thumbtip": 1.0},
]
## Muscle and bone pressed into the grown body: each a centre in the model frame,
## its radii, how far it pushes the skin out along its normal at the centre, and
## how soft its edge is (1 easing out all the way from the centre, less holding
## its full push further out and falling off sharply, as a muscle's edge does). One
## off the middle is matched on the other side.
BULGES = [
    # The chest, the shoulders' caps, the trapezius, the shoulder blades, the seat.
    ((0.085, 1.34, 0.11), (0.095, 0.075, 0.08), 0.034, 0.35),
    ((0.22, 1.44, -0.03), (0.085, 0.08, 0.095), 0.034, 0.5),
    ((0.1, 1.505, -0.04), (0.075, 0.045, 0.065), 0.02, 0.8),
    ((0.1, 1.33, -0.1), (0.085, 0.1, 0.05), 0.016, 1.0),
    ((0.065, 0.87, -0.1), (0.075, 0.075, 0.06), 0.02, 1.0),
    # A bicep and a tricep, a sailor's forearm, a calf.
    ((0.345, 1.44, 0.015), (0.075, 0.05, 0.05), 0.018, 0.6),
    ((0.33, 1.44, -0.1), (0.08, 0.05, 0.05), 0.012, 1.0),
    ((0.53, 1.445, -0.035), (0.07, 0.06, 0.07), 0.014, 0.7),
    ((0.091, 0.4, -0.085), (0.06, 0.1, 0.05), 0.016, 1.0),
    # The head: a chin, a brow ridge, a nose, ears, the back of the skull.
    ((0.0, 1.588, 0.095), (0.045, 0.032, 0.045), 0.016, 0.8),
    ((0.0, 1.726, 0.1), (0.06, 0.018, 0.035), 0.006, 1.0),
    ((0.0, 1.665, 0.115), (0.012, 0.025, 0.025), 0.013, 1.0),
    ((0.095, 1.68, -0.01), (0.022, 0.034, 0.028), 0.024, 1.0),
    ((0.0, 1.72, -0.1), (0.085, 0.07, 0.05), 0.012, 1.0),
]
## The bones whose weights are smoothed across the wrist, and how many rounds.
WRIST_BONES = ("lowerarm", "hand")
WRIST_SMOOTHING = 3
## The bones the grown body leaves to the finger and thumb shells.
HAND_BONES = ("fingers", "fingertips", "thumb", "thumbtip")
## The soles: the grown feet stand SOLE_GAP off the deck; every point under SOLE is
## let down so the lowest stands on it.
SOLE = 0.06
SOLE_GAP = 0.0
## The crown: the body is stretched over the head to stand this tall.
CROWN = 1.83


def _skin_graph():
    """The stick figure, in Blender's axes, as a bmesh with skin radii."""
    mesh = bmesh.new()
    skin = mesh.verts.layers.skin.verify()
    index = {}
    trunk = [t[0] for t in TRUNK_NODES]

    def add(name, at, radius, link):
        vert = mesh.verts.new(TO_BLENDER @ Vector(at))
        vert[skin].radius = radius
        index[name] = vert
        if link is not None:
            mesh.edges.new((index[link], vert))

    last = None
    for name, at, radius in TRUNK_NODES:
        add(name, at, radius, last)
        last = name
    for suffix, flip in (("_l", 1.0), ("_r", -1.0)):
        for nodes in (ARM_NODES, LEG_NODES, FOOT_NODES):
            previous = None
            for name, at, radius, link in nodes:
                at = (at[0] * flip, at[1], at[2])
                radius = radius if isinstance(radius, tuple) else (radius, radius)
                if link is None:
                    link = previous
                elif link not in trunk:
                    link = link + suffix
                add(name + suffix, at, radius, link)
                previous = name + suffix
    index["hips"][skin].use_root = True
    return mesh


def _bulge(points, normals):
    """Presses BULGES into the grown body, in place."""
    for (x, y, z), radii, push, soft in BULGES:
        for centre in {(x, y, z), (-x, y, z)}:
            for point, normal in zip(points, normals):
                d = sum(((point[i] - centre[i]) / radii[i]) ** 2 for i in range(3))
                if d < 1.0:
                    point += normal * push * min((1.0 - d) / soft, 1.0) ** 2


def _shape(points):
    """Sets the grown body on the deck and stretches it to the crown, in place."""
    for point in points:
        if point.y < SOLE:
            point.y = max((point.y - SOLE_GAP) * SOLE / (SOLE - SOLE_GAP), 0.0)
    top = max(point.y for point in points)
    print("gen_sailor: grown crown %.3f" % top)
    for point in points:
        if point.y > 1.6:
            point.y = 1.6 + (point.y - 1.6) * (CROWN - 1.6) / (top - 1.6)


def _grow():
    """The grown body's mesh, in the model frame: skin, subdivided, shaped."""
    graph = _skin_graph()
    data = bpy.data.meshes.new("SailorGraph")
    graph.to_mesh(data)
    graph.free()
    graph_object = bpy.data.objects.new("SailorGraph", data)
    bpy.context.scene.collection.objects.link(graph_object)
    skin = graph_object.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.5
    subdivide = graph_object.modifiers.new("Subdivide", "SUBSURF")
    subdivide.levels = 1
    subdivide.render_levels = 1
    depsgraph = bpy.context.evaluated_depsgraph_get()
    grown = bpy.data.meshes.new_from_object(graph_object.evaluated_get(depsgraph))
    bpy.data.objects.remove(graph_object)
    bpy.data.meshes.remove(data)
    body = bmesh.new()
    body.from_mesh(grown)
    body.normal_update()
    normals = [TO_BLENDER.transposed() @ vert.normal for vert in body.verts]
    for vert in body.verts:
        vert.co = TO_BLENDER.transposed() @ vert.co
    _bulge([vert.co for vert in body.verts], normals)
    _shape([vert.co for vert in body.verts])
    for vert in body.verts:
        vert.co = TO_BLENDER @ vert.co
    bmesh.ops.triangulate(body, faces=body.faces[:], quad_method="BEAUTY")
    body.to_mesh(grown)
    body.free()
    return grown


def _tube(verts, faces, weights, stations, ahead_up):
    """Adds a closed tube over `stations` — (point, across, through, weights), the
    last a point alone, its tip — to verts, faces and weights. Its rings face
    `ahead_up`'s way through (the back of the hand)."""
    first = len(verts)
    rings = stations[:-1]
    for number, (at, across, through, share) in enumerate(rings):
        following = stations[min(number + 1, len(stations) - 1)][0]
        before = stations[max(number - 1, 0)][0]
        along = (following - before).normalized()
        up = (ahead_up - along * along.dot(ahead_up)).normalized()
        side = along.cross(up)
        for step in range(FINGER_SIDES):
            angle = 2.0 * math.pi * step / FINGER_SIDES
            verts.append(at + up * (math.cos(angle) * through) + side * (math.sin(angle) * across))
            weights.append(share)
    sides = FINGER_SIDES
    for ring in range(len(rings) - 1):
        for step in range(sides):
            a = first + ring * sides + step
            b = first + ring * sides + (step + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    base = len(verts)
    verts.append(stations[0][0])
    weights.append(stations[0][3])
    tip = len(verts)
    verts.append(stations[-1][0])
    weights.append(stations[-1][3])
    last = first + (len(rings) - 1) * sides
    for step in range(sides):
        faces.append((first + (step + 1) % sides, first + step, base))
        faces.append((last + step, last + (step + 1) % sides, tip))


def _hand_shells():
    """The fingers and thumbs, both hands: (points in the model frame, faces as
    quads and triangles, each point's {bone: share})."""
    verts, faces, weights = [], [], []
    for suffix, flip in (("_l", False), ("_r", True)):
        first_face = len(faces)
        start = len(verts)
        for offset, length in FINGERS:
            stations = []
            for (x, rise, across, through), share in zip(FINGER_STATIONS, FINGER_WEIGHTS):
                x = FINGER_STATIONS[1][0] + (x - FINGER_STATIONS[1][0]) * (length if x > FINGER_STATIONS[1][0] else 1.0)
                spread = offset * (1.0 + 0.6 * max(x - FINGER_STATIONS[1][0], 0.0))
                at = Vector((x, PALM_Y + rise, -0.04 + spread))
                stations.append((at, across, through, share))
            _tube(verts, faces, weights, stations, UP)
        thumb = [(Vector(at), across, through, share)
                 for (at, across, through), share in zip(THUMB_STATIONS, THUMB_WEIGHTS)]
        _tube(verts, faces, weights, thumb, Vector((0.0, 1.0, -0.6)).normalized())
        for index in range(start, len(verts)):
            weights[index] = {bone + suffix: share for bone, share in weights[index].items()}
            if flip:
                verts[index] = MIRROR @ verts[index]
        if flip:
            for number in range(first_face, len(faces)):
                faces[number] = tuple(reversed(faces[number]))
    return verts, faces, weights


def build_body():
    """The sailor's body: a mesh object in Blender's axes, not yet skinned, and
    its finger and thumb shells, apart, with their weights."""
    grown = _grow()
    grown.name = "Sailor"
    for polygon in grown.polygons:
        polygon.use_smooth = True
    material = bpy.data.materials.new("sailor")
    material.diffuse_color = (0.84, 0.37, 0.0, 1.0)
    grown.materials.append(material)
    sailor = bpy.data.objects.new("Sailor", grown)
    bpy.context.scene.collection.objects.link(sailor)
    verts, faces, weights = _hand_shells()
    shells = bpy.data.meshes.new("Hands")
    shells.from_pydata([TO_BLENDER @ v for v in verts], [], faces)
    shells.materials.append(material)
    bmesh_shells = bmesh.new()
    bmesh_shells.from_mesh(shells)
    bmesh.ops.triangulate(bmesh_shells, faces=bmesh_shells.faces[:], quad_method="BEAUTY")
    bmesh_shells.to_mesh(shells)
    bmesh_shells.free()
    for polygon in shells.polygons:
        polygon.use_smooth = True
    hands = bpy.data.objects.new("Hands", shells)
    bpy.context.scene.collection.objects.link(hands)
    for index, share in enumerate(weights):
        for bone, weight in share.items():
            group = hands.vertex_groups.get(bone) or hands.vertex_groups.new(name=bone)
            group.add([index], weight, "REPLACE")
    return sailor, hands


def build_rig():
    """The armature, Rig, at rest: BONES in Blender's axes, every one but root deforming."""
    data = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail, roll in bones():
        bone = data.edit_bones.new(name)
        bone.head = TO_BLENDER @ head
        bone.tail = TO_BLENDER @ tail
        bone.align_roll(TO_BLENDER @ roll)
        if parent is not None:
            bone.parent = data.edit_bones[parent]
        bone.use_connect = False
        bone.use_deform = name != "root"
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin_body(sailor, hands, rig):
    """Binds the body to the rig — automatic weights, at most four bones a point, the
    fingers' and thumbs' bones left to their shells — and sets the shells into it."""
    bpy.ops.object.select_all(action="DESELECT")
    sailor.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for group in list(sailor.vertex_groups):
        if group.name.rsplit("_", 1)[0] in HAND_BONES:
            sailor.vertex_groups.remove(group)
    bpy.context.view_layer.objects.active = sailor
    # A wrist turned on its forearm twists the skin between them: shared over a
    # longer run, the twist leaves no crease for the outline to catch.
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    for name in WRIST_BONES:
        for side in ("_l", "_r"):
            sailor.vertex_groups.active_index = sailor.vertex_groups[name + side].index
            bpy.ops.object.vertex_group_smooth(group_select_mode="ACTIVE", factor=0.5, repeat=WRIST_SMOOTHING)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.select_all(action="DESELECT")
    hands.select_set(True)
    sailor.select_set(True)
    bpy.context.view_layer.objects.active = sailor
    bpy.ops.object.join()


# ---------------------------------------------------------------------------
# The clips. A pose is written in the model frame as each bone's turn from rest
# (a rotation of the whole bone about its head, in the model's axes), and the
# pelvis' shift; the right side is written as if it were the left and mirrored.


def turn(axis, degrees):
    return Matrix.Rotation(math.radians(degrees), 3, Vector(axis))


def euler(pitch, yaw, roll):
    """As Godot's Quaternion.from_euler, in degrees: yaw, then pitch, then roll."""
    return turn((0, 1, 0), yaw) @ turn((1, 0, 0), pitch) @ turn((0, 0, 1), roll)


def frame(way, ref):
    """A rotation whose y runs along `way` and whose z faces as near `ref` as it can."""
    y = Vector(way).normalized()
    z = Vector(ref) - y * y.dot(Vector(ref))
    z.normalize()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed()


def aimed(rest_way, rest_ref, way, ref):
    """The turn taking a bone along `rest_way` (its thumb, knee or face toward
    `rest_ref`) to lie along `way` with it toward `ref`."""
    return frame(way, ref) @ frame(rest_way, rest_ref).transposed()


def mirrored(rotation):
    return MIRROR @ rotation @ MIRROR


REST = {name: (head, tail) for name, _, head, tail, _ in bones()}
## The leg: thigh and calf lengths, the rest hip, knee, ankle, ball and heel.
HIP = REST["thigh_l"][0]
KNEE = REST["calf_l"][0]
ANKLE = REST["foot_l"][0]
BALL = REST["toe_l"][0]
HEEL = Vector((0.09, 0.0, -0.07))
THIGH = (KNEE - HIP).length
CALF = (ANKLE - KNEE).length


def arm(swing=0.0, out=8.0, bend=12.0, twist=0.0, wrist=0.0, hand_out=0.0):
    """A left arm, chest-relative: swung `swing` degrees ahead, `out` from the side,
    the elbow bent `bend` ahead, the forearm turned `twist` (thumb toward the body),
    the hand bent `wrist` back and `hand_out` outward. Returns the upper arm's,
    forearm's and hand's (way, thumb) pairs."""
    side = Vector((math.sin(math.radians(out)), -math.cos(math.radians(out)), 0.0))
    upper = turn((1, 0, 0), -swing)
    lower = turn((1, 0, 0), -(swing + bend))
    roll = turn(lower @ side, twist)
    upper_way = upper @ side
    lower_way = lower @ side
    thumb = roll @ (lower @ AHEAD)
    hand_turn = turn(lower_way.cross(thumb), -wrist) @ turn(thumb, -hand_out)
    return (
        (upper_way, upper @ AHEAD),
        (lower_way, thumb),
        (hand_turn @ lower_way, hand_turn @ thumb),
    )


def arm_to(upper_way, lower_way, thumb, hand_way=None, hand_thumb=None):
    """A left arm laid along explicit ways, chest-relative."""
    hand_way = lower_way if hand_way is None else hand_way
    hand_thumb = thumb if hand_thumb is None else hand_thumb
    return ((Vector(upper_way), Vector(thumb)), (Vector(lower_way), Vector(thumb)),
            (Vector(hand_way), Vector(hand_thumb)))


ARM_REST = ((Vector((1, 0, 0)), AHEAD),) * 3


class Pose:
    """One frame: the pelvis' shift, the trunk's turns (pitch, yaw, roll degrees,
    each from rest in the model), per side an arm (as arm() gives), the fingers'
    and thumb's curl, and a foot (ankle shift from rest, foot pitch, or None
    for straight legs)."""

    def __init__(self):
        self.hips = Vector((0.0, 0.0, 0.0))
        self.trunk = {name: (0.0, 0.0, 0.0) for name, *_ in TRUNK if name != "root"}
        self.arms = {"_l": arm(), "_r": arm()}
        self.curl = {"_l": (25.0, 20.0, 10.0), "_r": (25.0, 20.0, 10.0)}
        self.feet = {"_l": (Vector((0.0, 0.0, 0.0)), 0.0), "_r": (Vector((0.0, 0.0, 0.0)), 0.0)}
        self.toes = {"_l": None, "_r": None}
        self.shrug = {"_l": 0.0, "_r": 0.0}


def _leg(hip, ankle, pole):
    """The thigh's and calf's turns from rest for a left leg reaching from `hip` to
    `ankle`, the knee bending toward `pole`."""
    reach = ankle - hip
    length = min(max(reach.length, abs(THIGH - CALF) + 0.01), (THIGH + CALF) * 0.9995)
    along = reach.normalized()
    bend = (pole - along * along.dot(pole)).normalized()
    cos_hip = (THIGH * THIGH + length * length - CALF * CALF) / (2.0 * THIGH * length)
    angle = math.acos(max(-1.0, min(1.0, cos_hip)))
    knee = hip + (along * math.cos(angle) + bend * math.sin(angle)) * THIGH
    end = hip + along * length
    rest_thigh = (KNEE - HIP).normalized()
    rest_calf = (ANKLE - KNEE).normalized()
    return (
        aimed(rest_thigh, AHEAD, knee - hip, pole),
        aimed(rest_calf, AHEAD, end - knee, pole),
    )


def turns(pose):
    """Every bone's turn from rest, in the model frame, for `pose`."""
    found = {"root": Matrix.Identity(3)}
    for name, *_ in TRUNK[1:]:
        found[name] = euler(*pose.trunk[name])
    chest = found["chest"]
    pelvis = found["pelvis"]
    pelvis_at = REST["pelvis"][0] + pose.hips
    for side in ("_l", "_r"):
        flip = side == "_r"

        def put(name, rotation):
            found[name + side] = mirrored(rotation) if flip else rotation

        def local(rotation):
            return mirrored(rotation) if flip else rotation

        found["clavicle" + side] = chest @ local(turn((0, 0, 1), pose.shrug[side]))
        names = ("upperarm", "lowerarm", "hand")
        for name, (way, thumb), (rest_way, rest_thumb) in zip(names, pose.arms[side], ARM_REST):
            found[name + side] = chest @ local(aimed(rest_way, rest_thumb, way, thumb))
        knuckle, tip, thumb_curl = pose.curl[side]
        hand = found["hand" + side]
        found["fingers" + side] = hand @ local(turn((0, 0, 1), -knuckle))
        found["fingertips" + side] = found["fingers" + side] @ local(turn((0, 0, 1), -tip))
        if thumb_curl > 0.0:
            fold = min(thumb_curl / THUMB_FIST, 1.0)
            thumb = _folded(THUMB_REST, THUMB_FOLDED, fold)
            tip = _folded(THUMBTIP_REST, THUMBTIP_FOLDED, fold)
            found["thumb" + side] = hand @ local(thumb)
            found["thumbtip" + side] = hand @ local(tip)
        else:
            found["thumb" + side] = hand @ local(turn((1, 0, 0), thumb_curl))
            found["thumbtip" + side] = found["thumb" + side] @ local(turn((0, 1, 0), -thumb_curl))
        # The leg, solved as the left: the hip where the pelvis carries it.
        hip = pelvis_at + pelvis @ ((MIRROR @ HIP if flip else HIP) - REST["pelvis"][0])
        shift, pitch = pose.feet[side]
        ankle = _ankle(shift, pitch)
        if flip:
            hip = MIRROR @ hip
        yaw = pose.trunk["pelvis"][1] * (-1.0 if flip else 1.0)
        pole = turn((0, 1, 0), yaw * 0.5) @ Vector((0.08, 0.0, 1.0)).normalized()
        thigh, calf = _leg(hip, ankle, pole)
        put("thigh", thigh)
        put("calf", calf)
        foot = turn((0, 1, 0), yaw * 0.5) @ turn((1, 0, 0), pitch)
        put("foot", foot)
        # A heel lifted off the deck leaves the toes flat on it.
        toe = pose.toes[side]
        if toe is None:
            toe = -pitch if pitch > 0.0 else 0.0
        put("toe", foot @ turn((1, 0, 0), toe))
    return found


## A thumb folds into a fist: at THUMB_FIST of curl, its bones lie along these
## ways in the hand's rest frame — forward and down along the curled index finger's
## side, the tip turned in under it — each swung there from rest without a twist.
THUMB_FIST = 55.0
THUMB_REST = Vector(REST["thumb_l"][1]) - Vector(REST["thumb_l"][0])
THUMBTIP_REST = Vector(REST["thumbtip_l"][1]) - Vector(REST["thumbtip_l"][0])
THUMB_FOLDED = Vector((0.95, -0.1, 0.28))
THUMBTIP_FOLDED = Vector((0.6, -0.45, -0.66))


def _folded(rest, folded, fold):
    """The turn swinging a thumb bone at rest `fold` of the way to `folded`."""
    whole = rest.rotation_difference(folded)
    return Quaternion().slerp(whole, fold).to_matrix()


def _ankle(shift, pitch):
    """The left ankle shifted by `shift` from rest, its foot pitched `pitch` degrees
    toes down about the ball (or, toes up, about the heel) where it stands."""
    if pitch > 0.0:
        pivot = BALL
    else:
        pivot = HEEL
    return pivot + shift + turn((1, 0, 0), pitch) @ (ANKLE - pivot)


def key(rig, pose, frame_number):
    """Keys every bone of `rig` at `frame_number` to `pose`."""
    rotations = turns(pose)
    for bone in rig.pose.bones:
        rest = bone.bone.matrix_local.to_3x3()
        mine = TO_BLENDER @ rotations[bone.name] @ TO_BLENDER.transposed()
        parent = bone.parent.name if bone.parent else None
        above = Matrix.Identity(3) if parent is None else (
            TO_BLENDER @ rotations[parent] @ TO_BLENDER.transposed())
        local = rest.transposed() @ above.transposed() @ mine @ rest
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = local.to_quaternion()
        bone.keyframe_insert("rotation_quaternion", frame=frame_number)
        if bone.name == "pelvis":
            bone.location = rest.transposed() @ (TO_BLENDER @ pose.hips)
            bone.keyframe_insert("location", frame=frame_number)


def _wave(phase, at=0.0):
    return math.cos(2.0 * math.pi * (phase - at))


def _ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def _stride(phase, duty, reach, lift, strike, push):
    """A left foot through one stride at `phase` (0 as its heel strikes): planted for
    `duty` of it, sliding back from `reach` ahead to `reach` behind, then swung
    through, `lift` high. Returns its shift from rest and its pitch: `strike` toes
    up as it lands, `push` heel up as it leaves."""
    if phase < duty:
        through = phase / duty
        along = reach - 2.0 * reach * through
        pitch = strike * (1.0 - _ease(through / 0.18)) + push * _ease((through - 0.6) / 0.4)
        return Vector((0.0, 0.0, along)), pitch
    through = (phase - duty) / (1.0 - duty)
    along = -reach + 2.0 * reach * _ease(through)
    height = lift * math.sin(math.pi * min(through * 1.15, 1.0))
    pitch = push * (1.0 - _ease(through / 0.5)) + strike * _ease((through - 0.6) / 0.4)
    return Vector((0.0, height, along)), pitch


def idle(t, length):
    phase = t / length
    breath = math.sin(2.0 * math.pi * phase)
    pose = Pose()
    pose.hips = Vector((0.0, -0.012 + 0.003 * breath, 0.0))
    pose.trunk["pelvis"] = (0.0, 0.0, 1.0 * math.sin(2.0 * math.pi * phase))
    pose.trunk["spine_02"] = (-1.0 * breath, 0.0, 0.0)
    pose.trunk["chest"] = (-2.0 * breath, 0.0, -0.6 * math.sin(2.0 * math.pi * phase))
    pose.trunk["head"] = (2.0, 4.0 * math.sin(2.0 * math.pi * phase), 0.0)
    for side in ("_l", "_r"):
        pose.arms[side] = arm(swing=2.0, out=13.0 + 1.0 * breath, bend=16.0, twist=10.0)
        pose.curl[side] = (80.0, 80.0, 40.0)
    pose.feet["_l"] = (Vector((0.065, 0.0, 0.02)), 0.0)
    pose.feet["_r"] = (Vector((0.065, 0.0, -0.03)), 0.0)
    return pose


WALK = {"duty": 0.55, "reach": 0.33, "lift": 0.07, "strike": -14.0, "push": 24.0}
RUN = {"duty": 0.25, "reach": 0.36, "lift": 0.2, "strike": -6.0, "push": 30.0}


def walk(t, length):
    phase = t / length
    pose = Pose()
    # Lowest as both feet are down, highest over the planted one.
    pose.hips = Vector((0.0, -0.045 + 0.02 * _wave(2.0 * phase, 0.55), 0.0))
    swing = _wave(phase)
    pose.trunk["pelvis"] = (3.0, -7.0 * swing, 2.0 * _wave(2.0 * phase, 0.3))
    pose.trunk["spine_01"] = (3.0, -3.0 * swing, 1.0 * _wave(2.0 * phase, 0.3))
    pose.trunk["spine_02"] = (3.0, 1.0 * swing, 0.0)
    pose.trunk["chest"] = (3.0, 5.0 * swing, 0.0)
    pose.trunk["neck"] = (0.0, 2.0 * swing, 0.0)
    pose.trunk["head"] = (2.0, 0.0, 0.0)
    pose.arms["_l"] = arm(swing=-20.0 * swing, out=11.0, bend=18.0 + 10.0 * max(-swing, 0.0), twist=12.0)
    pose.arms["_r"] = arm(swing=20.0 * swing, out=11.0, bend=18.0 + 10.0 * max(swing, 0.0), twist=12.0)
    for side in ("_l", "_r"):
        pose.curl[side] = (75.0, 75.0, 35.0)
    pose.feet["_l"] = _stride(phase % 1.0, **WALK)
    pose.feet["_r"] = _stride((phase + 0.5) % 1.0, **WALK)
    return pose


def run(t, length):
    phase = t / length
    pose = Pose()
    # Lowest over the planted foot, highest in flight.
    pose.hips = Vector((0.0, -0.075 + 0.03 * _wave(2.0 * phase, 0.75), 0.04))
    swing = _wave(phase)
    pose.trunk["pelvis"] = (8.0, -10.0 * swing, 0.0)
    pose.trunk["spine_01"] = (10.0, -4.0 * swing, 0.0)
    pose.trunk["spine_02"] = (12.0, 3.0 * swing, 0.0)
    pose.trunk["chest"] = (13.0, 9.0 * swing, 0.0)
    pose.trunk["neck"] = (4.0, 4.0 * swing, 0.0)
    pose.trunk["head"] = (-2.0, 0.0, 0.0)
    pose.arms["_l"] = arm(swing=-38.0 * swing + 8.0, out=10.0, bend=85.0, twist=30.0)
    pose.arms["_r"] = arm(swing=38.0 * swing + 8.0, out=10.0, bend=85.0, twist=30.0)
    for side in ("_l", "_r"):
        pose.curl[side] = (70.0, 70.0, 30.0)
    pose.feet["_l"] = _stride(phase % 1.0, **RUN)
    pose.feet["_r"] = _stride((phase + 0.5) % 1.0, **RUN)
    return pose


def _fists(pose):
    for side in ("_l", "_r"):
        pose.curl[side] = (100.0, 115.0, 55.0)


def windup(t, length):
    """Drawing back into a coil, fists closed: BrawlerPose lays the coil itself over
    it, so this is the fists, the weight and a little life."""
    through = _ease(t / (length * 0.6))
    pose = Pose()
    pose.hips = Vector((0.0, -0.06 * through, -0.03 * through))
    pose.trunk["pelvis"] = (0.0, -10.0 * through, 0.0)
    pose.trunk["spine_02"] = (4.0 * through, -16.0 * through, 0.0)
    pose.trunk["chest"] = (6.0 * through, -24.0 * through, 0.0)
    pose.trunk["head"] = (2.0, 0.0, 0.0)
    pose.arms["_l"] = arm(swing=30.0 + 15.0 * through, out=18.0, bend=100.0 + 20.0 * through, twist=60.0)
    pose.arms["_r"] = arm(swing=10.0 + 10.0 * through, out=22.0, bend=110.0 + 20.0 * through, twist=60.0)
    _fists(pose)
    pose.feet["_l"] = (Vector((0.02, 0.0, 0.12 * through)), 0.0)
    pose.feet["_r"] = (Vector((-0.02, 0.0, -0.16 * through)), 8.0 * through)
    return pose


def shove(t, length):
    """Both arms thrust out, palms ahead and fingers up, pushing again and again."""
    phase = t / length
    beat = 0.5 - 0.5 * _wave(2.0 * phase)
    pose = Pose()
    pose.hips = Vector((0.0, -0.08, 0.06 + 0.05 * beat))
    pose.trunk["pelvis"] = (10.0, 0.0, 0.0)
    pose.trunk["spine_01"] = (14.0 + 4.0 * beat, 0.0, 0.0)
    pose.trunk["spine_02"] = (18.0 + 4.0 * beat, 0.0, 0.0)
    pose.trunk["chest"] = (20.0 + 6.0 * beat, 0.0, 0.0)
    pose.trunk["neck"] = (6.0, 0.0, 0.0)
    pose.trunk["head"] = (-4.0, 0.0, 0.0)
    for side in ("_l", "_r"):
        reach = 60.0 + 25.0 * beat
        pose.arms[side] = arm_to(
            turn((1, 0, 0), -reach) @ Vector((0.18, -1.0, 0.0)),
            turn((1, 0, 0), -(reach + 25.0 * (1.0 - beat))) @ Vector((-0.1, -1.0, 0.0)),
            Vector((-1.0, 0.0, 0.0)),
            Vector((0.0, 1.0, 0.35)),
            Vector((-1.0, 0.0, 0.0)),
        )
        pose.curl[side] = (-8.0, -4.0, -10.0)
    pose.feet["_l"] = (Vector((0.03, 0.0, 0.26)), 0.0)
    pose.feet["_r"] = (Vector((-0.03, 0.0, -0.3)), 28.0)
    return pose


def stagger(t, length):
    """Struck in the chest: thrown back, arms flung up and out, hands open."""
    through = _ease(t / (length * 0.5))
    pose = Pose()
    pose.hips = Vector((0.0, -0.04 * through, -0.06 * through))
    pose.trunk["pelvis"] = (-6.0 * through, 0.0, 0.0)
    pose.trunk["spine_01"] = (-12.0 * through, 0.0, 3.0 * through)
    pose.trunk["spine_02"] = (-18.0 * through, 4.0 * through, 5.0 * through)
    pose.trunk["chest"] = (-24.0 * through, 6.0 * through, 7.0 * through)
    pose.trunk["neck"] = (-12.0 * through, 0.0, 0.0)
    pose.trunk["head"] = (-20.0 * through, 6.0 * through, 6.0 * through)
    pose.arms["_l"] = arm(swing=30.0 * through, out=8.0 + 50.0 * through, bend=14.0 + 30.0 * through, twist=10.0, wrist=30.0 * through)
    pose.arms["_r"] = arm(swing=20.0 * through, out=8.0 + 60.0 * through, bend=14.0 + 40.0 * through, twist=10.0, wrist=30.0 * through)
    for side in ("_l", "_r"):
        pose.curl[side] = (10.0, 5.0, -5.0)
    pose.feet["_l"] = (Vector((0.03, 0.0, 0.06 * through)), 0.0)
    pose.feet["_r"] = (Vector((-0.03, 0.0, -0.22 * through)), 20.0 * through)
    return pose


def fall(t, length):
    """Airborne, falling: knees drawn up, arms out to the sides and flailing."""
    phase = t / length
    flail = math.sin(2.0 * math.pi * phase * 2.0)
    pose = Pose()
    pose.hips = Vector((0.0, 0.0, 0.0))
    pose.trunk["pelvis"] = (-6.0, 0.0, 0.0)
    pose.trunk["spine_01"] = (-4.0, 0.0, 0.0)
    pose.trunk["spine_02"] = (-2.0, 0.0, 2.0 * flail)
    pose.trunk["chest"] = (0.0, 0.0, 3.0 * flail)
    pose.trunk["head"] = (6.0, 0.0, 0.0)
    pose.arms["_l"] = arm(swing=-15.0 + 10.0 * flail, out=72.0 + 10.0 * flail, bend=40.0, twist=-40.0)
    pose.arms["_r"] = arm(swing=-15.0 - 10.0 * flail, out=72.0 - 10.0 * flail, bend=40.0, twist=-40.0)
    for side in ("_l", "_r"):
        pose.curl[side] = (15.0, 10.0, 0.0)
    pose.feet["_l"] = (Vector((0.02, 0.24 + 0.04 * flail, 0.16)), -20.0)
    pose.feet["_r"] = (Vector((-0.02, 0.14 - 0.04 * flail, -0.06)), 10.0)
    return pose


def jump(t, length):
    """Springing up: the body straightening off the deck, the arms swinging up,
    then the knees tucking as it rises."""
    rise = _ease(t / 0.22)
    tuck = _ease((t - 0.18) / 0.35)
    pose = Pose()
    pose.trunk["pelvis"] = (6.0 * (1.0 - rise), 0.0, 0.0)
    pose.trunk["spine_02"] = (8.0 * (1.0 - rise) - 4.0 * tuck, 0.0, 0.0)
    pose.trunk["chest"] = (10.0 * (1.0 - rise) - 6.0 * tuck, 0.0, 0.0)
    pose.trunk["head"] = (-6.0 * rise, 0.0, 0.0)
    for side in ("_l", "_r"):
        pose.arms[side] = arm(swing=-30.0 + 140.0 * rise - 40.0 * tuck, out=15.0 + 20.0 * tuck, bend=20.0 + 30.0 * tuck, twist=20.0)
        pose.curl[side] = (30.0, 25.0, 10.0)
    pose.hips = Vector((0.0, -0.1 * (1.0 - rise), 0.0))
    pose.feet["_l"] = (Vector((0.02, 0.22 * tuck, 0.1 * tuck)), 30.0 * (1.0 - tuck) * rise)
    pose.feet["_r"] = (Vector((-0.02, 0.14 * tuck, -0.04 * tuck)), 30.0 * (1.0 - tuck) * rise)
    return pose


def brace(t, length):
    """Dug in low and wide behind raised fists, rocking a little."""
    phase = t / length
    rock = math.sin(2.0 * math.pi * phase)
    pose = Pose()
    pose.hips = Vector((0.0, -0.16 + 0.01 * rock, -0.02))
    pose.trunk["pelvis"] = (10.0, 0.0, 0.0)
    pose.trunk["spine_01"] = (12.0, 0.0, 0.0)
    pose.trunk["spine_02"] = (14.0 + 1.0 * rock, 0.0, 0.0)
    pose.trunk["chest"] = (16.0 + 2.0 * rock, 0.0, 0.0)
    pose.trunk["neck"] = (4.0, 0.0, 0.0)
    pose.trunk["head"] = (-12.0, 0.0, 0.0)
    for side in ("_l", "_r"):
        pose.arms[side] = arm(swing=45.0, out=25.0, bend=105.0, twist=70.0)
    _fists(pose)
    pose.feet["_l"] = (Vector((0.12, 0.0, 0.1)), 0.0)
    pose.feet["_r"] = (Vector((0.12, 0.0, -0.1)), 0.0)
    return pose


def climb(t, length):
    """Hauling up a ladder: hand over hand above the head, the knees stepping up
    in turn, the body close to the rungs."""
    phase = t / length
    pose = Pose()
    pose.hips = Vector((0.0, -0.08, -0.02))
    pose.trunk["pelvis"] = (8.0, 0.0, 0.0)
    pose.trunk["spine_02"] = (6.0, 0.0, 0.0)
    pose.trunk["chest"] = (4.0, 0.0, 0.0)
    pose.trunk["head"] = (-18.0, 0.0, 0.0)
    for side, at in (("_l", 0.0), ("_r", 0.5)):
        up = 0.5 + 0.5 * _wave(phase, at)
        pose.arms[side] = arm(swing=95.0 + 60.0 * up, out=12.0, bend=70.0 - 50.0 * up, twist=40.0)
        pose.curl[side] = (60.0 + 30.0 * (1.0 - up), 60.0, 30.0)
        step = 0.5 + 0.5 * _wave(phase, at + 0.5)
        pose.feet[side] = (Vector((0.0, 0.05 + 0.3 * step, 0.12 + 0.08 * step)), -10.0 * step)
    return pose


def swim(t, length):
    """A crawl, as the chest sees it — the game leans the body into the sea — and a
    flutter kick."""
    phase = t / length
    pose = Pose()
    pose.trunk["pelvis"] = (0.0, -6.0 * _wave(phase), 0.0)
    pose.trunk["chest"] = (0.0, 10.0 * _wave(phase), -6.0 * _wave(phase))
    pose.trunk["head"] = (-10.0, 0.0, 0.0)
    for side, at in (("_l", 0.0), ("_r", 0.5)):
        stroke = (phase - at) % 1.0
        # Out ahead overhead, pulled down and back under the body, then recovered.
        if stroke < 0.55:
            through = stroke / 0.55
            swing = 170.0 - 190.0 * _ease(through)
            bend = 20.0 + 50.0 * math.sin(math.pi * through)
        else:
            through = (stroke - 0.55) / 0.45
            swing = -20.0 + 190.0 * _ease(through)
            bend = 70.0 - 50.0 * through
        pose.arms[side] = arm(swing=swing, out=18.0, bend=bend, twist=40.0)
        pose.curl[side] = (10.0, 10.0, 0.0)
        kick = math.sin(2.0 * math.pi * (phase * 2.0 + at))
        pose.feet[side] = (Vector((0.0, 0.06, -0.06 + 0.12 * kick)), 35.0)
    return pose


## Each clip: the game's name, its maker, its length in frames, and whether it loops
## (exported as NAME-loop, which Godot's import loops and names NAME).
CLIPS = [
    ("idle", idle, 75, True),
    ("walk", walk, 40, True),
    ("run", run, 28, True),
    ("windup", windup, 26, False),
    ("shove", shove, 80, True),
    ("stagger", stagger, 10, False),
    ("fall", fall, 75, True),
    ("jump", jump, 24, False),
    ("brace", brace, 88, True),
    ("climb", climb, 60, True),
    ("swim", swim, 40, True),
]


def stride_speed(gait, frames):
    """How fast a planted foot of `gait` slides back, model units a second."""
    return 2.0 * gait["reach"] / (gait["duty"] * frames / FPS)


def make_clips(rig):
    rig.animation_data_create()
    for name, maker, frames, loops in CLIPS:
        action = bpy.data.actions.new(name + ("-loop" if loops else ""))
        action.use_fake_user = True
        rig.animation_data.action = action
        for frame_number in range(frames + 1):
            key(rig, maker(frame_number / FPS, frames / FPS), frame_number)
        action.use_frame_range = True
        action.frame_range = (0, frames)
        action.use_cyclic = loops
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)


def export(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_normals=True,
        export_texcoords=False,
        export_tangents=False,
        export_materials="EXPORT",
        export_skins=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=False,
        export_def_bones=False,
        export_morph=False,
        export_cameras=False,
        export_lights=False,
        export_extras=False,
    )


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    sailor, hands = build_body()
    rig = build_rig()
    skin_body(sailor, hands, rig)
    make_clips(rig)
    print("gen_sailor: body %d triangles, %d bones" % (len(sailor.data.polygons), len(rig.data.bones)))
    print("gen_sailor: walk %.3f, run %.3f model units/s" % (
        stride_speed(WALK, 40), stride_speed(RUN, 28)))
    if argv:
        bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    if len(argv) > 1:
        export(argv[1])


if __name__ == "__main__":
    main()
