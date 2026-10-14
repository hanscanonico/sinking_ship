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
- the outfits (OUTFITS): the body dressed three ways — a jersey, a jacket and a
  greatcoat — each a mesh of its own on the rig, its pieces of clothing laid over
  it and what each point is written into its UVs for the clothes shader;
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
from mathutils.bvhtree import BVHTree

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
## and z. The head stays inside the hats gen_hats.py builds round it.
TRUNK_NODES = [
    ("hips", (0.0, 0.92, -0.015), (0.158, 0.13)),
    ("waist", (0.0, 1.04, 0.0), (0.136, 0.116)),
    ("belly", (0.0, 1.13, 0.004), (0.146, 0.118)),
    ("ribs", (0.0, 1.21, 0.008), (0.194, 0.158)),
    ("chest", (0.0, 1.295, 0.014), (0.234, 0.182)),
    ("yoke", (0.0, 1.43, -0.015), (0.178, 0.172)),
    ("neck_base", (0.0, 1.51, -0.025), (0.124, 0.098)),
    ("neck", (0.0, 1.548, -0.024), (0.064, 0.066)),
    ("chin", (0.0, 1.598, 0.024), (0.082, 0.092)),
    ("jaw", (0.0, 1.636, 0.012), (0.095, 0.106)),
    ("cheek", (0.0, 1.692, 0.006), (0.098, 0.116)),
    ("brow", (0.0, 1.752, -0.008), (0.1, 0.12)),
    ("crown", (0.0, 1.826, -0.014), (0.07, 0.082)),
]
## An arm, the shoulder out to the palm: (name, at, (deep, high), link), its
## half-widths along z and y; link is the trunk node it grows from.
ARM_NODES = [
    ("shoulder", (0.205, 1.432, -0.03), (0.12, 0.104), "yoke"),
    ("delt", (0.265, 1.434, -0.035), (0.11, 0.1), None),
    ("bicep", (0.345, 1.437, -0.04), (0.09, 0.09), None),
    ("elbow", (0.45, 1.44, -0.04), (0.066, 0.064), None),
    ("forearm", (0.545, 1.44, -0.04), (0.086, 0.078), None),
    ("wrist", (0.722, 1.44, -0.04), (0.056, 0.046), None),
    ("palm", (0.77, 1.438, -0.04), (0.07, 0.037), None),
    ("palm_end", (0.806, 1.437, -0.04), (0.068, 0.033), None),
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
    ((0.772, 1.427, 0.004), 0.021, 0.02),
    ((0.789, 1.423, 0.03), 0.0185, 0.0172),
    ((0.803, 1.42, 0.048), 0.0158, 0.015),
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
    ((0.088, 1.34, 0.12), (0.1, 0.08, 0.085), 0.044, 0.35),
    ((0.22, 1.44, -0.03), (0.09, 0.08, 0.1), 0.04, 0.5),
    ((0.1, 1.505, -0.04), (0.075, 0.045, 0.065), 0.02, 0.8),
    ((0.1, 1.33, -0.1), (0.085, 0.1, 0.05), 0.016, 1.0),
    ((0.065, 0.87, -0.1), (0.075, 0.075, 0.06), 0.02, 1.0),
    # A bicep and a tricep, a sailor's forearm, a calf.
    ((0.345, 1.44, 0.02), (0.075, 0.055, 0.055), 0.022, 0.6),
    ((0.33, 1.44, -0.1), (0.08, 0.05, 0.05), 0.012, 1.0),
    ((0.54, 1.445, -0.035), (0.09, 0.07, 0.08), 0.02, 0.7),
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


def build_base(rig):
    """The bare sailor, grown and skinned to `rig` by Blender's automatic weights, at
    most four bones a point, the fingers' and thumbs' bones left to their shells:
    a Kit of its points, in the model frame, its faces and its weights. The Blender
    object it is skinned on is removed again."""
    grown = _grow()
    base = bpy.data.objects.new("Base", grown)
    bpy.context.scene.collection.objects.link(base)
    bpy.ops.object.select_all(action="DESELECT")
    base.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for group in list(base.vertex_groups):
        if group.name.rsplit("_", 1)[0] in HAND_BONES:
            base.vertex_groups.remove(group)
    bpy.context.view_layer.objects.active = base
    # A wrist turned on its forearm twists the skin between them: shared over a
    # longer run, the twist leaves no crease for the outline to catch.
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    for name in WRIST_BONES:
        for side in ("_l", "_r"):
            base.vertex_groups.active_index = base.vertex_groups[name + side].index
            bpy.ops.object.vertex_group_smooth(group_select_mode="ACTIVE", factor=0.5, repeat=WRIST_SMOOTHING)
    bpy.ops.object.mode_set(mode="OBJECT")
    kit = Kit()
    names = {group.index: group.name for group in base.vertex_groups}
    for vert in grown.vertices:
        shares = {names[g.group]: g.weight for g in vert.groups if g.weight > 0.0}
        kit.add(TO_BLENDER.transposed() @ vert.co, BODY, shares)
    for polygon in grown.polygons:
        kit.faces.append(tuple(polygon.vertices))
    bpy.data.objects.remove(base)
    bpy.data.meshes.remove(grown)
    return kit


# ---------------------------------------------------------------------------
# The outfits. Every seat wears one of three (OUTFITS, in Brawler.Coat's order),
# each the sailor dressed here and exported as a mesh of its own on the rig: the
# body let out under the cloth (HANG), the coat's skirt hung from the hips, and the
# collars, cuffs, ribbing, lapels, pockets and buttons laid over it. What each point
# is — the body, painted from where it stands, or a piece of clothing in one colour
# — goes into its second UV for the clothes shader (brawler.gdshader's PART_), and
# the coat's colour stays the shader's, so the tint is the seat's.

OUTFITS = ("Jersey", "Jacket", "Greatcoat")
## The parts, as brawler.gdshader numbers them: the outfits' and the hats'
## (gen_hats.py). Neighbours in a face blend across it, so the cloth and its
## lining, which share the skirt's edges, are numbered side by side.
BODY, CLOTH, LINING, FACING, BRASS, LEATHER, INK, STRAW, HAIR = range(9)
## How wide each piece's outline is drawn, as a share of the body's: small pieces
## in full would drown in ink.
DETAIL_INK = 0.45
BUTTON_INK = 0.2
## How far each outfit lets the body out under the cloth, at most, in model units:
## over the trunk, hanging straight down from the chest between HANG_FROM and
## HANG_TO within HANG_WIDTH of the middle; and over the sleeves.
HANG = {"Jersey": 0.012, "Jacket": 0.022, "Greatcoat": 0.03}
SLEEVE = {"Jersey": 0.004, "Jacket": 0.004, "Greatcoat": 0.009}
HANG_FROM = 0.86
HANG_TO = 1.38
HANG_WIDTH = 0.22
## How many rounds of smoothing each outfit's cloth bridges the trunk's hollows
## with, over the trunk within DRAPE_WIDTH of the middle between DRAPE_FROM and
## DRAPE_TO.
DRAPE = {"Jersey": 3, "Jacket": 6, "Greatcoat": 8}
DRAPE_WIDTH = 0.24
DRAPE_FROM = 0.88
DRAPE_TO = 1.46
## A coat's skirt, hanging from the hips: rings from the waist down to its hem,
## opening at the front by as many radians either side of ahead as SKIRT_OPENINGS
## has from the waist to the hem — a jacket's tails are cut away. A ring stands
## wider and deeper and is held less by the hips than by the thighs the lower it
## hangs (the SKIRT_ rates, per unit of drop); past 1/SKIRT_SPLIT of the way round
## from the front it goes wholly with its own thigh. Brawler.SKIRT_HEMS holds the
## hems too, for the shadow the shader lays on the legs under them.
SKIRT_HEMS = {"Jacket": 0.78, "Greatcoat": 0.45}
SKIRT_OPENINGS = {"Jacket": (0.3, 0.8), "Greatcoat": (0.04, 0.14)}
SKIRT_RINGS = {"Jacket": 4, "Greatcoat": 6}
SKIRT_SEGMENTS = 18
SKIRT_WAIST_HEIGHT = 1.0
SKIRT_WAIST = (0.165, 0.137)
SKIRT_FLARE = (0.15, 0.15)
SKIRT_BACK = 0.02
SKIRT_LET_GO = 1.55
SKIRT_HELD = 0.12
SKIRT_SPLIT = 2.5
SKIRT_THICK = 0.012
## The painted front — shirt, tie, lapels, buttons — rides the spine alone, its
## share of each spine bone rising smoothly with height: automatic weights give the
## breastbone to the collarbones and upper arms, which a raised arm swings, and its
## rows to the spine bones in uneven shares, both of which would shear a narrow
## band into a zigzag. Within STEADY_ACROSS of the middle and between the first and
## last of STEADY_ROWS a point is weighted so, letting go over STEADY_FADE beyond.
## tools/art_lint.gd checks it with the same numbers.
STEADY_ACROSS = 0.09
STEADY_ROWS = (("spine_01", 1.1), ("spine_02", 1.27), ("chest", 1.42))
STEADY_FADE = 0.05


class Kit:
    """A mesh being put together in the model frame: its points, each with its part,
    its ink (how wide its outline is drawn) and its bones' shares; and its faces,
    each turned on the way to the side it faces."""

    def __init__(self):
        self.points = []
        self.parts = []
        self.inks = []
        self.weights = []
        self.faces = []

    def add(self, at, part, weights, ink=1.0):
        self.points.append(Vector(at))
        self.parts.append(part)
        self.inks.append(ink)
        self.weights.append(dict(weights))
        return len(self.points) - 1

    def face(self, corners, outward):
        """Adds the face over `corners`, wound to face `outward`."""
        a, b, c = (self.points[i] for i in corners[:3])
        if (b - a).cross(c - a).dot(outward) < 0.0:
            corners = tuple(reversed(corners))
        self.faces.append(tuple(corners))

    def extend(self, other, part=None):
        start = len(self.points)
        for at, own, ink, weights in zip(other.points, other.parts, other.inks, other.weights):
            self.add(at, own if part is None else part, weights, ink)
        for face in other.faces:
            self.faces.append(tuple(start + i for i in face))


class Surface:
    """What clothes are laid on: a Kit's faces as they stand, which a ray finds
    the cloth's place on, with its smoothed normal and its bones' shares there."""

    def __init__(self, kit):
        self.points = [p.copy() for p in kit.points]
        self.weights = kit.weights[:]
        self.triangles = []
        for face in kit.faces:
            for i in range(1, len(face) - 1):
                self.triangles.append((face[0], face[i], face[i + 1]))
        self.tree = BVHTree.FromPolygons(self.points, self.triangles, all_triangles=True)
        self.normals = [Vector((0.0, 0.0, 0.0)) for _ in self.points]
        for a, b, c in self.triangles:
            n = (self.points[b] - self.points[a]).cross(self.points[c] - self.points[a])
            for i in (a, b, c):
                self.normals[i] += n
        for n in self.normals:
            n.normalize()

    def cast(self, origin, way, facing):
        """Where a ray from `origin` along `way` meets the surface: the point, its
        normal turned toward `facing`, and the bones' shares there."""
        at, _, index, _ = self.tree.ray_cast(Vector(origin), Vector(way).normalized(), 3.0)
        if at is None:
            raise RuntimeError("gen_sailor: no surface from %s along %s" % (tuple(origin), tuple(way)))
        a, b, c = self.triangles[index]
        share = barycentric(at, self.points[a], self.points[b], self.points[c])
        normal = (self.normals[a] * share[0] + self.normals[b] * share[1] + self.normals[c] * share[2]).normalized()
        if normal.dot(Vector(facing)) < 0.0:
            normal = -normal
        weights = {}
        for i, s in zip((a, b, c), share):
            for bone, w in self.weights[i].items():
                weights[bone] = weights.get(bone, 0.0) + w * s
        return at, normal, _strongest(weights)


def barycentric(p, a, b, c):
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
    d20, d21 = v2.dot(v0), v2.dot(v1)
    den = d00 * d11 - d01 * d01
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    v, w = max(v, 0.0), max(w, 0.0)
    u = max(1.0 - v - w, 0.0)
    total = u + v + w
    return (u / total, v / total, w / total)


def _strongest(shares, most=4):
    """The `most` largest of `shares`, normalized."""
    kept = sorted(shares.items(), key=lambda item: (-item[1], item[0]))[:most]
    total = sum(w for _, w in kept)
    return {bone: w / total for bone, w in kept if w > 0.0}


def _smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def _let_out(kit, outfit):
    """Lets the body out under `outfit`'s cloth, in place: the cloth bridging the
    hollows between the muscles of the trunk (DRAPE rounds of smoothing that only
    ever push out), the trunk hanging straight from the chest, the sleeves a little
    fuller."""
    surface = Surface(kit)
    around = [set() for _ in kit.points]
    for face in kit.faces:
        for i, a in enumerate(face):
            around[a].add(face[i - 1])
            around[a].add(face[(i + 1) % len(face)])
    trunk = [
        index for index, point in enumerate(kit.points)
        if abs(point.x) < DRAPE_WIDTH and DRAPE_FROM < point.y < DRAPE_TO
    ]
    for _ in range(DRAPE[outfit]):
        moved = {}
        for index in trunk:
            middle = sum((kit.points[i] for i in around[index]), Vector()) / len(around[index])
            out = (middle - kit.points[index]).dot(surface.normals[index])
            if out > 0.0:
                moved[index] = kit.points[index] + surface.normals[index] * out
        for index, point in moved.items():
            kit.points[index] = point
    for index, point in enumerate(kit.points):
        if abs(point.x) <= HANG_WIDTH and HANG_FROM <= point.y <= HANG_TO:
            out = Vector((point.x, 0.0, point.z))
            if out.length > 0.0:
                lift = HANG[outfit] * math.sin(math.pi * (point.y - HANG_FROM) / (HANG_TO - HANG_FROM))
                kit.points[index] = point + out.normalized() * lift
        elif abs(point.x) > 0.24 and abs(point.x) < 0.7 and point.y > 1.25:
            # The sleeve, easing off toward the shoulder and the cuff.
            fade = _smoothstep(0.24, 0.3, abs(point.x)) * (1.0 - _smoothstep(0.64, 0.7, abs(point.x)))
            kit.points[index] = point + surface.normals[index] * SLEEVE[outfit] * fade


def _skirt(kit, outfit):
    """Adds `outfit`'s skirt: an open-fronted tube from the waist, cloth outside and
    lining inside, held by the hips and pulled along by the thighs below."""
    hem = SKIRT_HEMS[outfit]
    opening = SKIRT_OPENINGS[outfit]
    rings = SKIRT_RINGS[outfit]
    outer, inner = [], []
    for ring in range(rings):
        down = ring / (rings - 1)
        height = SKIRT_WAIST_HEIGHT + (hem - SKIRT_WAIST_HEIGHT) * down
        drop = SKIRT_WAIST_HEIGHT - height
        size = (SKIRT_WAIST[0] + SKIRT_FLARE[0] * drop, SKIRT_WAIST[1] + SKIRT_FLARE[1] * drop)
        gap = opening[0] + (opening[1] - opening[0]) * down
        held = max(1.0 - drop * SKIRT_LET_GO, SKIRT_HELD)
        out_row, in_row = [], []
        for step in range(SKIRT_SEGMENTS + 1):
            angle = gap + (2.0 * math.pi - 2.0 * gap) * step / SKIRT_SEGMENTS
            across, ahead = math.sin(angle), math.cos(angle)
            left = (1.0 - held) * (0.5 + 0.5 * max(-1.0, min(1.0, across * SKIRT_SPLIT)))
            weights = _strongest({"pelvis": held, "thigh_l": left, "thigh_r": 1.0 - held - left})
            back = -SKIRT_BACK * drop
            out_row.append(kit.add((across * size[0], height, ahead * size[1] + back), CLOTH, weights))
            in_row.append(kit.add(
                (across * (size[0] - SKIRT_THICK), height, ahead * (size[1] - SKIRT_THICK) + back), LINING, weights))
        outer.append(out_row)
        inner.append(in_row)
    for ring in range(rings - 1):
        for step in range(SKIRT_SEGMENTS):
            out = kit.points[outer[ring][step]] + kit.points[outer[ring + 1][step + 1]]
            out = Vector((out.x, 0.0, out.z))
            kit.face((outer[ring][step], outer[ring][step + 1], outer[ring + 1][step + 1], outer[ring + 1][step]), out)
            kit.face((inner[ring][step], inner[ring][step + 1], inner[ring + 1][step + 1], inner[ring + 1][step]), -out)
    for step in range(SKIRT_SEGMENTS):
        for ring, way in ((0, UP), (rings - 1, DOWN)):
            kit.face((outer[ring][step], outer[ring][step + 1], inner[ring][step + 1], inner[ring][step]), way)
    for ring in range(rings - 1):
        for step, toward in ((0, 1), (SKIRT_SEGMENTS, SKIRT_SEGMENTS - 1)):
            way = kit.points[outer[ring][step]] - kit.points[outer[ring][toward]]
            kit.face((outer[ring][step], outer[ring + 1][step], inner[ring + 1][step], inner[ring][step]), way)


def _panel(kit, surface, grid, part, behind=False, lift=0.003, thick=0.006, ink=DETAIL_INK):
    """Lays a piece of cloth on `surface`, seen from ahead (or `behind`): `grid`, rows
    of (x, y) points over it, cast onto the surface and stood `lift` off it, `thick`
    deep, its edges sunk into what it lies on."""
    way = Vector((0.0, 0.0, 1.0 if behind else -1.0))
    top, base = [], []
    for row in grid:
        top.append([])
        base.append([])
        for x, y in row:
            at, normal, weights = surface.cast(Vector((x, y, 0.0)) - way * 0.6, way, -way)
            top[-1].append(kit.add(at + normal * (lift + thick), part, weights, ink))
            base[-1].append(kit.add(at - normal * 0.004, part, weights, ink))
    rows, cols = len(grid), len(grid[0])
    for r in range(rows - 1):
        for c in range(cols - 1):
            kit.face((top[r][c], top[r][c + 1], top[r + 1][c + 1], top[r + 1][c]), -way)
    loop = [(0, c) for c in range(cols)] + [(r, cols - 1) for r in range(1, rows)]
    loop += [(rows - 1, c) for c in range(cols - 2, -1, -1)] + [(r, 0) for r in range(rows - 2, 0, -1)]
    middle = sum((kit.points[i] for row in top for i in row), Vector()) / (rows * cols)
    for i, (r, c) in enumerate(loop):
        r2, c2 = loop[(i + 1) % len(loop)]
        edge = (kit.points[top[r][c]] + kit.points[top[r2][c2]]) * 0.5
        kit.face((base[r][c], base[r2][c2], top[r2][c2], top[r][c]), edge - middle)


def _button(kit, surface, x, y, part=BRASS, behind=False, radius=0.0105, sides=8):
    """A domed button at (x, y) on `surface`, seen from ahead (or `behind`)."""
    way = Vector((0.0, 0.0, 1.0 if behind else -1.0))
    at, normal, weights = surface.cast(Vector((x, y, 0.0)) - way * 0.6, way, -way)
    _stud(kit, at, normal, weights, part, radius, sides)


def _stud(kit, at, normal, weights, part=BRASS, radius=0.0105, sides=8, ref=UP):
    """A domed button at `at` on a surface facing `normal`."""
    side = normal.cross(ref).normalized()
    up = side.cross(normal).normalized()
    sunk, rim = [], []
    for step in range(sides):
        angle = 2.0 * math.pi * step / sides
        out = side * math.cos(angle) + up * math.sin(angle)
        sunk.append(kit.add(at + out * radius - normal * 0.003, part, weights, BUTTON_INK))
        rim.append(kit.add(at + out * radius * 0.85 + normal * 0.006, part, weights, BUTTON_INK))
    apex = kit.add(at + normal * 0.009, part, weights, BUTTON_INK)
    for step in range(sides):
        following = (step + 1) % sides
        out = (kit.points[rim[step]] + kit.points[rim[following]]) * 0.5 - at
        kit.face((sunk[step], sunk[following], rim[following], rim[step]), out)
        kit.face((rim[step], rim[following], apex), normal)


def _band(kit, surface, centre, axis, stations, part, segments=16, ribs=0.0, ink=1.0):
    """A band round a limb or the trunk: rings cast out from the line through
    `centre` along `axis`, one at each of `stations` — (how far along the axis, how
    far off the surface) — the first and last sunk into it. Every other point of a
    ring stands `ribs` further out, as knitted ribbing does."""
    axis = Vector(axis).normalized()
    across = Vector((0.0, 1.0, 0.0)) if abs(axis.y) < 0.9 else Vector((0.0, 0.0, 1.0))
    u = (across - axis * axis.dot(across)).normalized()
    v = axis.cross(u)
    rings = []
    for along, lift in stations:
        ring = []
        for step in range(segments):
            angle = 2.0 * math.pi * step / segments
            out = u * math.cos(angle) + v * math.sin(angle)
            at, normal, weights = surface.cast(Vector(centre) + axis * along, out, out)
            off = lift + (ribs if lift > 0.0 and step % 2 else 0.0)
            ring.append(kit.add(at + normal * off, part, weights, ink))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for step in range(segments):
            following = (step + 1) % segments
            out = kit.points[rings[r][step]] + kit.points[rings[r][following]] - Vector(centre) * 2.0
            out -= axis * axis.dot(out)
            kit.face((rings[r][step], rings[r][following], rings[r + 1][following], rings[r + 1][step]), out)


def _cuffs(kit, surface, stations, part, ribs=0.0, segments=14):
    """A band round each wrist, `stations` along the forearm out from the elbow."""
    for flip in (1.0, -1.0):
        _band(kit, surface, (0.0, 1.44, -0.04), (flip, 0.0, 0.0), stations, part, segments, ribs)


def _lapels(kit, surface, opens, rate, top, widest, notch, rows=7):
    """A coat's lapels, rolled back either side of the opening it parts on (opening
    from `opens` high at `rate`): up its edge to `top`, `widest` across at the
    notch, at `notch` high, where the collar takes over."""
    for flip in (1.0, -1.0):
        grid = []
        for r in range(rows):
            y = opens + (top - opens) * r / (rows - 1)
            edge = max(y - opens, 0.0) * rate
            if y < notch:
                width = widest * _smoothstep(opens, notch, y) ** 0.6
            else:
                width = widest * 0.4 * (1.0 - (y - notch) / (top - notch)) + 0.014
            grid.append([(flip * (edge - 0.004), y), (flip * (edge + width), y)])
        _panel(kit, surface, grid, CLOTH, lift=0.001, thick=0.005)


def _fan(kit, surface, stations, part, opening=0.0, segments=20, ink=1.0):
    """A band round the base of the neck, cast out and down from inside it (NECK):
    one ring at each of `stations` — (how many degrees above where the neck meets
    the shoulders its ray points, how far off the body it stands) — the first and
    last sunk into it. Round the whole neck, or round the back of it, `opening`
    degrees short of ahead either side, its ends sunk too."""
    whole = opening <= 0.0
    count = segments if whole else segments + 1
    rings = [[] for _ in stations]
    for step in range(count):
        if whole:
            angle = 2.0 * math.pi * step / segments
        else:
            angle = math.radians(opening) + (2.0 * math.pi - 2.0 * math.radians(opening)) * step / segments
        level = Vector((math.sin(angle), 0.0, math.cos(angle)))
        foot = _neck_foot(surface, level)
        for ring, (above, lift) in zip(rings, stations):
            down = math.radians(foot - above)
            way = level * math.cos(down) + DOWN * math.sin(down)
            at, normal, weights = surface.cast(NECK, way, way)
            off = lift
            if not whole and step in (0, segments):
                off = -0.004
            ring.append(kit.add(at + normal * off, part, weights, ink))
    for r in range(len(rings) - 1):
        for step in range(segments):
            following = (step + 1) % count
            out = kit.points[rings[r][step]] + kit.points[rings[r][following]] - NECK * 2.0
            out.y = 0.0
            kit.face((rings[r][step], rings[r][following], rings[r + 1][following], rings[r + 1][step]), out)


def _neck_foot(surface, level):
    """How many degrees down from NECK, out along `level`, the neck meets the
    shoulders or the chest: the last ray down to meet the neck before one passes
    through the trapezius to the arm, or the body falls away more steeply — and no
    further down than NECK_FOOT, so a collar rounds the neck rather than dipping
    to the breastbone."""
    last = None
    for down in range(5, NECK_FOOT + 1):
        way = level * math.cos(math.radians(down)) + DOWN * math.sin(math.radians(down))
        at = surface.cast(NECK, way, way)[0]
        reach = Vector((at.x - NECK.x, 0.0, at.z - NECK.z)).length
        if last is not None and (reach > NECK_REACH or reach - last > 0.012):
            return down - 1
        last = reach
    return NECK_FOOT


## Where a collar's rays start: inside the neck, over its base; and how far out
## from there the neck reaches, at most.
NECK = Vector((0.0, 1.58, -0.022))
NECK_REACH = 0.12
NECK_FOOT = 36


def _pocket(kit, surface, x, y, width, height, part=CLOTH, slant=0.0):
    """A pocket flap: `width` by `height`, its top edge centred at (x, y), tipped
    `slant` down toward the middle."""
    grid = []
    for r in range(2):
        row = []
        for c in range(3):
            across = x + width * (c / 2.0 - 0.5)
            row.append((across, y - height * r - slant * (across - x)))
        grid.append(row)
    _panel(kit, surface, grid, part, thick=0.005)


def _jersey(kit, surface):
    """A fisherman's jersey: a rolled collar, ribbed cuffs and a ribbed welt over the
    belt, its buckle showing under it."""
    _fan(kit, surface, [(0.0, -0.004), (3.0, 0.016), (8.0, 0.024), (13.0, 0.018), (17.0, -0.004)], FACING, ink=0.7)
    _band(kit, surface, (0.0, 0.0, -0.01), (0.0, 1.0, 0.0),
          [(0.925, -0.004), (0.935, 0.008), (0.975, 0.008), (0.99, -0.004)], FACING, segments=28, ribs=0.004, ink=0.6)
    _cuffs(kit, surface, [(0.66, -0.004), (0.67, 0.007), (0.715, 0.007), (0.725, -0.004)], FACING, ribs=0.003)
    _panel(kit, surface, [[(-0.022, 0.93), (0.022, 0.93)], [(-0.022, 0.9), (0.022, 0.9)]], BRASS, thick=0.006,
           ink=BUTTON_INK)


def _jacket(kit, surface):
    """A single-breasted reefer jacket: lapels and a collar, three brass buttons,
    a breast pocket, flapped hip pockets, and cuffs over the shirt's."""
    _lapels(kit, surface, 1.2, 0.26, 1.44, 0.075, 1.4)
    _fan(kit, surface, [(0.0, -0.004), (2.0, 0.012), (11.0, 0.012), (13.0, -0.004)], CLOTH, opening=50.0,
         segments=14, ink=DETAIL_INK)
    for y in (1.18, 1.08, 0.98):
        _button(kit, surface, 0.0, y)
    _pocket(kit, surface, 0.11, 1.335, 0.07, 0.012, FACING)
    for flip in (1.0, -1.0):
        _pocket(kit, surface, flip * 0.1, 0.95, 0.085, 0.032, slant=flip * 0.08)
    _cuffs(kit, surface, [(0.665, -0.004), (0.675, 0.006), (0.705, 0.006), (0.712, -0.004)], FACING)


def _greatcoat(kit, surface):
    """A double-breasted greatcoat to the calf: broad lapels under a high collar, two
    rows of brass buttons, flapped pockets, turned-back cuffs and a half-belt behind."""
    _lapels(kit, surface, 1.28, 0.3, 1.45, 0.1, 1.41)
    _fan(kit, surface, [(0.0, -0.004), (2.0, 0.016), (15.0, 0.016), (18.0, -0.004)], CLOTH, opening=48.0,
         segments=14, ink=DETAIL_INK)
    for y in (1.26, 1.16, 1.06, 0.95):
        for x in (-0.065, 0.065):
            _button(kit, surface, x, y)
    for flip in (1.0, -1.0):
        _pocket(kit, surface, flip * 0.115, 0.88, 0.085, 0.035)
    _cuffs(kit, surface, [(0.62, -0.004), (0.63, 0.009), (0.69, 0.009), (0.7, -0.004)], FACING)
    belt = [[(x, 1.05) for x in (-0.11, -0.04, 0.04, 0.11)], [(x, 1.0) for x in (-0.11, -0.04, 0.04, 0.11)]]
    _panel(kit, surface, belt, CLOTH, behind=True, thick=0.006)
    for x in (-0.085, 0.085):
        _button(kit, surface, x, 1.025, behind=True)


DRESS = {"Jersey": _jersey, "Jacket": _jacket, "Greatcoat": _greatcoat}


def _steady(kit):
    """Weights the front of `kit` on the spine as STEADY_ROWS has it, in place."""
    heights = [h for _, h in STEADY_ROWS]
    low, high = heights[0], heights[-1]
    for index, point in enumerate(kit.points):
        steady = (
            (1.0 - _smoothstep(STEADY_ACROSS, STEADY_ACROSS + STEADY_FADE, abs(point.x)))
            * _smoothstep(low - STEADY_FADE, low, point.y)
            * (1.0 - _smoothstep(high, high + STEADY_FADE, point.y))
            * _smoothstep(0.0, STEADY_FADE, point.z)
        )
        if steady <= 0.0:
            continue
        shares = {bone: w * (1.0 - steady) for bone, w in kit.weights[index].items()}
        for row, (bone, height) in enumerate(STEADY_ROWS):
            share = 1.0
            if row > 0:
                below = heights[row - 1]
                share = min(share, (point.y - below) / (height - below))
            if row < len(STEADY_ROWS) - 1:
                above = heights[row + 1]
                share = min(share, (point.y - above) / (height - above))
            shares[bone] = shares.get(bone, 0.0) + max(0.0, min(1.0, share)) * steady
        kit.weights[index] = _strongest(shares)


def _hands():
    """The fingers and thumbs of both hands as a Kit."""
    verts, faces, weights = _hand_shells()
    kit = Kit()
    for at, share in zip(verts, weights):
        kit.add(at, BODY, share)
    kit.faces = [tuple(face) for face in faces]
    return kit


def build_outfit(name, base, hands, rig, material):
    """`name`'s outfit, dressed on a copy of the bare sailor `base` with `hands`,
    as a mesh object skinned to `rig`."""
    kit = Kit()
    kit.extend(base)
    _let_out(kit, name)
    if name in SKIRT_HEMS:
        _skirt(kit, name)
    DRESS[name](kit, Surface(kit))
    kit.extend(hands)
    _steady(kit)
    return _skinned(name, kit, rig, material)


def _skinned(name, kit, rig, material):
    """`kit` as a mesh object named `name`, skinned to `rig`: triangulated, smooth,
    its rest places and parts in its UVs and its ink in its colours."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([TO_BLENDER @ p for p in kit.points], [], kit.faces)
    shape = bmesh.new()
    shape.from_mesh(mesh)
    bmesh.ops.triangulate(shape, faces=shape.faces[:], quad_method="BEAUTY")
    shape.to_mesh(mesh)
    shape.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    # Where each point stands at rest, for the clothes shader: (x, y) in the first
    # UV, (z, part) in the second. glTF's v runs down, so each is written as 1 - v.
    rest = mesh.uv_layers.new(name="rest")
    depth = mesh.uv_layers.new(name="depth")
    for loop in mesh.loops:
        at = kit.points[loop.vertex_index]
        rest.data[loop.index].uv = (at.x, 1.0 - at.y)
        depth.data[loop.index].uv = (at.z, 1.0 - kit.parts[loop.vertex_index])
    ink = mesh.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
    for index, share in enumerate(kit.inks):
        ink.data[index].color = (1.0, 1.0, 1.0, share)
    mesh.color_attributes.active_color = ink
    mesh.materials.append(material)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(body)
    groups = {}
    for index, shares in enumerate(kit.weights):
        for bone, weight in _strongest(shares).items():
            if bone not in groups:
                groups[bone] = body.vertex_groups.new(name=bone)
            groups[bone].add([index], weight, "REPLACE")
    body.parent = rig
    modifier = body.modifiers.new("Rig", "ARMATURE")
    modifier.object = rig
    return body


# ---------------------------------------------------------------------------
# The first-person arms. A seat sees its own arms all the time, so each outfit's are
# modelled again on their own (NAME + "Arms"), finer than a body drawn eight times
# over can afford: the sleeve from above the elbow, hanging fuller than the arm as
# cloth does, and its cuff — a jersey's ribbed one, a reefer jacket's with three
# buttons, a greatcoat's deep turned-back one with two — a coat's shirt cuff under
# it, each with the open mouth the wrist comes out of; a hand with the heel of its
# palm and the ball of its thumb; and fingers and a thumb with knuckles standing
# proud on the back, creases across their joints and flat nails. Every point sits
# where the arm's does at rest, so the clothes shader paints sleeve, cuff and skin as
# it paints the body, in the seat's colour. FirstPersonArms draws them in place of
# the whole body.

## Points round a sleeve, a cuff, the hand (and a shirt's cuff round it), and a
## finger or thumb.
SLEEVE_SIDES = 16
CUFF_SIDES = 20
HAND_SIDES = 18
DIGIT_SIDES = 10
## The arm's line at rest, out along +x: the upper arm's and forearm's bones.
ARM_LINE = Vector((0.0, 1.44, -0.04))
## Where the sleeve's rings stand along the arm, from above the elbow out to the cuff.
SLEEVE_RINGS = (0.3, 0.36, 0.41, 0.45, 0.49, 0.535, 0.58, 0.625, 0.66)
## Each outfit's sleeve: how much fuller than the bare arm it hangs, and how far
## clear of the wrist at its narrowest; its cuff, from `cuff` out to `end` along the
## arm and standing `proud` of the sleeve, its ribs, and the buttons on it; and
## whether a shirt's cuff shows under it.
ARM_SLEEVES = {
    "Jersey": {"full": 0.006, "clear": 0.004, "cuff": 0.68, "end": 0.744, "proud": 0.004, "ribs": 0.0025,
               "buttons": 0, "shirt": False},
    "Jacket": {"full": 0.007, "clear": 0.011, "cuff": 0.662, "end": 0.714, "proud": 0.003, "ribs": 0.0,
               "buttons": 3, "shirt": True},
    "Greatcoat": {"full": 0.013, "clear": 0.016, "cuff": 0.612, "end": 0.704, "proud": 0.007, "ribs": 0.0,
                  "buttons": 2, "shirt": True},
}
## The elbow's span, where the sleeve goes over from the upper arm to the forearm
## and bridges the hollow of the elbow; and the wrist's, the forearm to the hand.
ELBOW_SPAN = (0.4, 0.53)
WRIST_SPAN = (0.715, 0.77)
## A cuff's cloth at its mouth, and how far in its lining shows.
CUFF_THICK = 0.004
CUFF_LINING = 0.02
## Buttons on a cuff: how far round from the back of the hand toward the little
## finger they sit, in degrees, how far apart along it, and how big.
CUFF_BUTTON_ROUND = -75.0
CUFF_BUTTON_APART = 0.014
CUFF_BUTTON = 0.0052
## A shirt's cuff: how far it stands off the wrist, and its mouth (short of where
## the shader paints skin).
SHIRT_CLEAR = 0.0055
SHIRT_END = 0.742
## The hand, wrist to knuckles: its rings — x along the arm, the half-width across,
## and the half-heights to its back (up at rest) and to its palm — round PALM_Y over
## the arm's line, squarish (HAND_ROUND, a superellipse's power), closed at HAND_TIP.
HAND_RINGS = [
    (0.7, 0.054, 0.036, 0.038),
    (0.725, 0.055, 0.036, 0.038),
    (0.745, 0.056, 0.035, 0.037),
    (0.762, 0.059, 0.031, 0.036),
    (0.779, 0.06, 0.027, 0.033),
    (0.794, 0.059, 0.022, 0.028),
    (0.804, 0.055, 0.017, 0.022),
]
HAND_TIP = 0.811
HAND_ROUND = 2.6
## The heel of the hand and the ball of the thumb, pressed out of the palm, as BULGES.
HAND_BULGES = [
    ((0.772, 1.405, -0.005), (0.03, 0.02, 0.025), 0.007, 0.8),
    ((0.765, 1.41, -0.075), (0.025, 0.02, 0.018), 0.004, 0.8),
]
## A finger, as FINGER_STATIONS but finer: x along the palm's middle line (scaled
## past the knuckle by the finger's length), its rise, its half-widths across and
## through, how much its ring creases — the knuckle standing proud on the back, a
## fold across the palm's side — how flat its back is (a nail), and its bones' shares.
KNUCKLE_X = 0.817
DIGIT_STATIONS = [
    (0.792, 0.0, 0.0125, 0.0125, 0.0, 0.0, {"hand": 1.0}),
    (0.806, 0.002, 0.014, 0.015, 0.0, 0.0, {"hand": 0.75, "fingers": 0.25}),
    (0.817, 0.006, 0.015, 0.0172, 0.3, 0.0, {"hand": 0.5, "fingers": 0.5}),
    (0.84, 0.0, 0.013, 0.0128, 0.0, 0.0, {"fingers": 1.0}),
    (0.86, 0.0, 0.0138, 0.0136, 0.12, 0.0, {"fingers": 0.5, "fingertips": 0.5}),
    (0.877, -0.001, 0.0123, 0.0117, 0.0, 0.0, {"fingertips": 1.0}),
    (0.887, -0.001, 0.0124, 0.0118, 0.1, 0.0, {"fingertips": 1.0}),
    (0.898, -0.002, 0.0118, 0.0108, 0.0, 0.3, {"fingertips": 1.0}),
    (0.906, -0.003, 0.0098, 0.009, 0.0, 0.3, {"fingertips": 1.0}),
    (0.911, -0.003, 0.006, 0.0056, 0.0, 0.0, {"fingertips": 1.0}),
]
DIGIT_TIP = (0.913, -0.003)
## The thumb, as THUMB_STATIONS but finer: each ring's point, half-widths, crease,
## flatness and shares; then its tip.
THUMB_RINGS = [
    ((0.758, 1.43, -0.026), 0.02, 0.019, 0.0, 0.0, {"hand": 1.0}),
    ((0.772, 1.427, 0.004), 0.021, 0.02, 0.0, 0.0, {"hand": 0.6, "thumb": 0.4}),
    ((0.781, 1.425, 0.017), 0.0195, 0.0185, 0.0, 0.0, {"thumb": 0.8, "thumbtip": 0.2}),
    ((0.789, 1.423, 0.03), 0.0188, 0.0178, 0.12, 0.0, {"thumb": 0.5, "thumbtip": 0.5}),
    ((0.797, 1.4215, 0.04), 0.017, 0.016, 0.0, 0.0, {"thumbtip": 1.0}),
    ((0.804, 1.42, 0.049), 0.0155, 0.0142, 0.0, 0.3, {"thumbtip": 1.0}),
    ((0.809, 1.419, 0.057), 0.011, 0.0102, 0.0, 0.2, {"thumbtip": 1.0}),
]
THUMB_TIP = (0.812, 1.419, 0.063)
THUMB_UP = Vector((0.0, 1.0, -0.6)).normalized()


def _ring(centre, along, up, across, back, palm, sides, power=2.0, crease=0.0, flat=0.0, ribs=0.0):
    """The points round a ring at `centre` square to `along`: `across` wide either
    side, `back` high toward `up` and `palm` the other way, a superellipse of
    `power`; creased (the back standing proud, the palm folding in), its back
    flattened by `flat`, and every other point stood `ribs` further out."""
    along = Vector(along).normalized()
    up = (Vector(up) - along * along.dot(Vector(up))).normalized()
    side = along.cross(up)
    points = []
    for step in range(sides):
        angle = 2.0 * math.pi * step / sides
        c, s = math.cos(angle), math.sin(angle)
        c = math.copysign(abs(c) ** (2.0 / power), c)
        s = math.copysign(abs(s) ** (2.0 / power), s)
        high = c * (back * (1.0 + 0.5 * crease) if c > 0.0 else palm * (1.0 - crease))
        if flat > 0.0:
            high = min(high, back * (1.0 - flat))
        out = up * high + side * (s * across)
        if ribs > 0.0 and step % 2:
            out += out.normalized() * ribs
        points.append(Vector(centre) + out)
    return points


def _loft(kit, rings, start=None, end=None):
    """Adds a tube through `rings` — each (points round it, its centre, part, ink,
    shares, facing) — to `kit`. The band up to a ring faces out from the centre
    before it, unless that ring's `facing` says otherwise: "in", toward it, or a
    way. `start` and `end`, each a (point, shares) or None, close the tube's ends in
    a point; None leaves an end open."""
    ids = [[kit.add(p, part, shares, ink) for p in points] for points, _, part, ink, shares, _ in rings]
    sides = len(ids[0])
    for r in range(len(rings) - 1):
        facing = rings[r + 1][5]
        for i in range(sides):
            j = (i + 1) % sides
            out = kit.points[ids[r][i]] + kit.points[ids[r][j]] - rings[r][1] * 2.0
            if facing == "in":
                out = -out
            elif facing is not None:
                out = Vector(facing)
            kit.face((ids[r][i], ids[r][j], ids[r + 1][j], ids[r + 1][i]), out)
    for which, cap in ((0, start), (len(rings) - 1, end)):
        if cap is None:
            continue
        at, shares = cap
        _, centre, part, ink, _, _ = rings[which]
        apex = kit.add(at, part, shares, ink)
        for i in range(sides):
            kit.face((ids[which][i], ids[which][(i + 1) % sides], apex), Vector(at) - centre)
    return ids


def _shares(blend, first, second, x):
    """`first` giving way to `second` across the span `blend` along the arm, at `x`."""
    t = _smoothstep(blend[0], blend[1], x)
    return {bone: share for bone, share in ((first, 1.0 - t), (second, t)) if share > 0.0}


def _sided(shares):
    return {bone + "_l": share for bone, share in shares.items()}


def _hand_ring(x, sides):
    """The hand's ring at `x` along the arm, as HAND_RINGS lays it: its points and
    its centre."""
    following = next((n for n, ring in enumerate(HAND_RINGS) if ring[0] >= x), len(HAND_RINGS) - 1)
    following = max(following, 1)
    (x0, *low), (x1, *high) = HAND_RINGS[following - 1], HAND_RINGS[following]
    t = max(0.0, min(1.0, (x - x0) / (x1 - x0)))
    across, back, palm = (a + (b - a) * t for a, b in zip(low, high))
    centre = Vector((x, PALM_Y, ARM_LINE.z))
    return _ring(centre, Vector((1.0, 0.0, 0.0)), UP, across, back, palm, sides, HAND_ROUND), centre


def _grown(points, centre, lift, x):
    """`points` round `centre`, each `lift` further out from it, moved along the arm
    to `x`."""
    shift = Vector((x - centre.x, 0.0, 0.0))
    return [p + (p - centre).normalized() * lift + shift for p in points], centre + shift


def _sleeve_reach(surface, outfit, x, sides):
    """How far out from the arm's line a sleeve of `outfit` stands at `x`, at each of
    `sides` points round from the back of the hand: the bare arm let out, bridging
    the elbow's hollow, and clear of the wrist."""
    spec = ARM_SLEEVES[outfit]
    wrist, centre = _hand_ring(0.745, sides)

    def bare(at):
        found = []
        for step in range(sides):
            angle = 2.0 * math.pi * step / sides
            way = UP * math.cos(angle) + AHEAD * math.sin(angle)
            origin = Vector((at, ARM_LINE.y, ARM_LINE.z))
            found.append((surface.cast(origin, way, way)[0] - origin).length)
        return found

    reach = bare(x)
    if ELBOW_SPAN[0] < x < ELBOW_SPAN[1]:
        t = (x - ELBOW_SPAN[0]) / (ELBOW_SPAN[1] - ELBOW_SPAN[0])
        bridge = [a + (b - a) * t for a, b in zip(bare(ELBOW_SPAN[0]), bare(ELBOW_SPAN[1]))]
        reach = [max(r, b) for r, b in zip(reach, bridge)]
    least = [(p - centre).length + spec["clear"] for p in wrist]
    return [max(r + spec["full"], m) for r, m in zip(reach, least)]


def _round(x, reach, lift=0.0):
    """Points `reach` (each plus `lift`) out from the arm's line at `x`, round from
    the back of the hand, and the centre they ring."""
    centre = Vector((x, ARM_LINE.y, ARM_LINE.z))
    points = []
    for step, r in enumerate(reach):
        angle = 2.0 * math.pi * step / len(reach)
        points.append(centre + (UP * math.cos(angle) + AHEAD * math.sin(angle)) * (r + lift))
    return points, centre


def _arm_sleeve(kit, surface, outfit):
    """A left sleeve of `outfit`: the cloth from above the elbow, its cuff and the
    cuff's mouth, the buttons on it, and a shirt's cuff under it."""
    spec = ARM_SLEEVES[outfit]
    forearm = _sided({"lowerarm": 1.0})
    rings = []
    stations = [x for x in SLEEVE_RINGS if x < spec["cuff"] - 0.012] + [spec["cuff"] + 0.006]
    for x in stations:
        points, centre = _round(x, _sleeve_reach(surface, outfit, x, SLEEVE_SIDES))
        rings.append((points, centre, BODY, 1.0, _sided(_shares(ELBOW_SPAN, "upperarm", "lowerarm", x)), None))
    _loft(kit, rings)
    # The cuff: sunk into the sleeve at its foot, standing proud of it to the mouth,
    # rounding over its lip into the lining.
    cuff, end, proud, ribs = spec["cuff"], spec["end"], spec["proud"], spec["ribs"]
    rings = []
    for x, lift, facing in ((cuff, -0.003, None), (cuff + 0.003, proud, None), (end - 0.004, proud, None),
                            (end, proud - 0.0015, None)):
        reach = _sleeve_reach(surface, outfit, x, CUFF_SIDES)
        reach = [r + (ribs if lift > 0.0 and step % 2 else 0.0) for step, r in enumerate(reach)]
        points, centre = _round(x, reach, lift)
        rings.append((points, centre, FACING, DETAIL_INK, forearm, facing))
    mouth = _sleeve_reach(surface, outfit, end, CUFF_SIDES)
    for x, lift, facing in ((end, proud - CUFF_THICK, Vector((1.0, 0.0, 0.0))),
                            (end - CUFF_LINING, proud - CUFF_THICK, "in")):
        points, centre = _round(x, mouth, lift)
        rings.append((points, centre, FACING, 0.0, forearm, facing))
    _loft(kit, rings)
    index = round(CUFF_BUTTON_ROUND / 360.0 * CUFF_SIDES) % CUFF_SIDES
    angle = 2.0 * math.pi * index / CUFF_SIDES
    way = UP * math.cos(angle) + AHEAD * math.sin(angle)
    for number in range(spec["buttons"]):
        x = end - 0.012 - number * CUFF_BUTTON_APART
        reach = _sleeve_reach(surface, outfit, x, CUFF_SIDES)[index] + proud
        at = Vector((x, ARM_LINE.y, ARM_LINE.z)) + way * reach
        _stud(kit, at, way, forearm, radius=CUFF_BUTTON, ref=Vector((1.0, 0.0, 0.0)))
    if spec["shirt"]:
        wrist, centre = _hand_ring(0.745, HAND_SIDES)
        rings = []
        for x, lift, ink, facing in ((end - 0.03, SHIRT_CLEAR, DETAIL_INK, None),
                                     (SHIRT_END - 0.005, SHIRT_CLEAR, DETAIL_INK, None),
                                     (SHIRT_END, SHIRT_CLEAR - 0.0012, DETAIL_INK, None),
                                     (SHIRT_END, SHIRT_CLEAR - 0.003, 0.0, Vector((1.0, 0.0, 0.0))),
                                     (SHIRT_END - 0.012, SHIRT_CLEAR - 0.003, 0.0, "in")):
            points, at = _grown(wrist, centre, lift, x)
            rings.append((points, at, BODY, ink, forearm, facing))
        _loft(kit, rings)


def _arm_hand(kit):
    """A left hand: the wrist out of the cuff, the palm with its heel and the ball of
    its thumb, four fingers and a thumb."""
    rings = []
    for x, *_ in HAND_RINGS:
        points, centre = _hand_ring(x, HAND_SIDES)
        for point in points:
            normal = Vector((0.0, point.y - centre.y, point.z - centre.z)).normalized()
            for at, radii, push, soft in HAND_BULGES:
                d = sum(((point[i] - at[i]) / radii[i]) ** 2 for i in range(3))
                if d < 1.0:
                    point += normal * push * min((1.0 - d) / soft, 1.0) ** 2
        rings.append((points, centre, BODY, 1.0, _sided(_shares(WRIST_SPAN, "lowerarm", "hand", x)), None))
    _loft(kit, rings, end=(Vector((HAND_TIP, PALM_Y - 0.003, ARM_LINE.z)), _sided({"hand": 1.0})))
    for offset, length in FINGERS:
        rings = []
        for x, rise, across, through, crease, flat, shares in DIGIT_STATIONS:
            if x > KNUCKLE_X:
                x = KNUCKLE_X + (x - KNUCKLE_X) * length
            spread = offset * (1.0 + 0.6 * max(x - KNUCKLE_X, 0.0))
            centre = Vector((x, PALM_Y + rise, -0.04 + spread))
            rings.append([centre, across, through, crease, flat, shares])
        tip_x = KNUCKLE_X + (DIGIT_TIP[0] - KNUCKLE_X) * length
        tip = Vector((tip_x, PALM_Y + DIGIT_TIP[1], -0.04 + offset * (1.0 + 0.6 * (tip_x - KNUCKLE_X))))
        _digit(kit, rings, tip, UP)
    thumb = [[Vector(at), across, through, crease, flat, shares]
             for at, across, through, crease, flat, shares in THUMB_RINGS]
    _digit(kit, thumb, Vector(THUMB_TIP), THUMB_UP)


def _digit(kit, stations, tip, up):
    """A finger or thumb through `stations` — (centre, across, through, crease,
    flat, shares) — to `tip`, its back toward `up`."""
    centres = [s[0] for s in stations] + [tip]
    rings = []
    for number, (centre, across, through, crease, flat, shares) in enumerate(stations):
        along = centres[number + 1] - centres[max(number - 1, 0)]
        points = _ring(centre, along, up, across, through, through, DIGIT_SIDES, crease=crease, flat=flat)
        rings.append((points, centre, BODY, 1.0, _sided(shares), None))
    _loft(kit, rings, start=(centres[0], _sided(stations[0][5])), end=(tip, _sided(stations[-1][5])))


def _mirrored_arms(left):
    """`left`, a left arm, with the right's mirror of it."""
    kit = Kit()
    kit.extend(left)
    start = len(kit.points)
    for at, part, ink, weights in zip(left.points, left.parts, left.inks, left.weights):
        kit.add(MIRROR @ at, part, {bone[:-2] + "_r": share for bone, share in weights.items()}, ink)
    for face in left.faces:
        kit.faces.append(tuple(start + i for i in reversed(face)))
    return kit


def build_arms(name, base, rig, material):
    """`name`'s first-person arms, NAME + "Arms": both sleeves and hands, as a mesh
    object skinned to `rig`, laid over the bare sailor `base`."""
    left = Kit()
    _arm_sleeve(left, Surface(base), name)
    _arm_hand(left)
    return _skinned(name + "Arms", _mirrored_arms(left), rig, material)


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
THUMB_FOLDED = Vector((0.95, -0.24, 0.04))
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
    """Struck in the chest: thrown back, arms flung up and out, fists still closed."""
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
    _fists(pose)
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
        export_texcoords=True,
        export_vertex_color="ACTIVE",
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
    rig = build_rig()
    base = build_base(rig)
    hands = _hands()
    material = bpy.data.materials.new("sailor")
    material.diffuse_color = (0.84, 0.37, 0.0, 1.0)
    bodies = [build_outfit(name, base, hands, rig, material) for name in OUTFITS]
    bodies += [build_arms(name, base, rig, material) for name in OUTFITS]
    make_clips(rig)
    for body in bodies:
        print("gen_sailor: %s %d triangles" % (body.name, len(body.data.polygons)))
    print("gen_sailor: %d bones" % len(rig.data.bones))
    print("gen_sailor: walk %.3f, run %.3f model units/s" % (
        stride_speed(WALK, 40), stride_speed(RUN, 28)))
    if argv:
        bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    if len(argv) > 1:
        export(argv[1])


if __name__ == "__main__":
    main()
