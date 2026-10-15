"""A sideboard flat on its wall (CabinDressing.SIDEBOARDS), for the sideboard_NN build
scripts (assets/models/sideboard_NN/sideboard_NN.py): one length each, NN hundredths
of a metre along its top, never one model scaled. A mahogany carcass on a dark
plinth, carved stiles between its cupboard doors, each door a raised and moulded
panel with a brass knob, a drawer over each door with its brass pull, a top proud of
the carcass and a brass gallery rail of spindles along its back between two turned
posts; on the steamer's saloon's, a decanter and a pair of glasses in front of the
rail.

In Godot's axes, metres: x along the wall (Wall.right), y up, z out from the wall's
face, its origin on the floor at the wall's face under its middle. Nothing of it
stands further out than its top's front, a wall fitting's depth.
"""

import math
import sys

from model_kit import Part, box, fresh_scene, lathe, panel, save, stud, sweep, triangles

BACK = (2, -1)
FLOOR = (1, -1)
TOP = (1, 1)
ENDS = ((0, -1), (0, 1))
X = [1.0, 0.0, 0.0]
Y = [0.0, 1.0, 0.0]
Z = [0.0, 0.0, 1.0]
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])
# The plinth's height and how far in its face stands from the carcass's; the top's
# thickness and how far the carcass's face stands in from its front; the drawers'
# height; how far the stiles stand proud; the gallery's posts' and spindles' radii.
PLINTH = 0.08
PLINTH_IN = 0.012
LID = 0.035
FACE_IN = 0.012
DRAWER = 0.13
STILE = 0.004
POST = 0.011
SPINDLE = 0.004


def build(name, width, height, depth, doors, gallery, top_paint, things=False):
    """sideboard_NN, its top [width] along its wall, [height] over the floor and
    [depth] out, [doors] cupboard doors under as many drawers, its gallery's posts' finials [gallery]
    over its top, its top painted [top_paint]; a decanter and two glasses on it when
    [things]. Written to the path after --."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    frame = Part("frame", "frame")
    teak = Part("teak", "teak")
    dark = Part("dark", "dark")
    brass = Part("brass", "brass")
    top = Part("top", top_paint)
    half = width * 0.5
    body = half - 0.015
    face = depth - FACE_IN
    under = height - LID
    # The plinth, the carcass over it and the top over that, proud of it.
    box(dark, [-body + 0.01, 0.0, 0.0], [body - 0.01, PLINTH, face - PLINTH_IN], inked=False, skip=(BACK, FLOOR, TOP))
    box(frame, [-body, PLINTH, 0.0], [body, under, face], skip=(BACK, FLOOR, TOP), plain=ENDS)
    box(top, [-half, under, 0.0], [half, height, depth], rim=0.01, skip=(BACK,), plain=ENDS + (FLOOR,))
    # The bays between the stiles: a drawer over a door in each.
    stile = 0.035
    bay = (body * 2.0 - stile * (doors + 1)) / doors
    drawer_top = under - 0.02
    drawer_low = drawer_top - DRAWER
    door_top = drawer_low - 0.02
    door_low = PLINTH + 0.03
    for k in range(doors):
        middle = -body + stile + bay * 0.5 + k * (bay + stile)
        drawer_mid = (drawer_top + drawer_low) * 0.5
        panel(teak, [middle, drawer_mid, face + 0.002], X, Y, (bay * 0.5, DRAWER * 0.5), 0.012)
        stud(brass, [middle, drawer_mid, face + 0.002], Z, 0.016, 0.008, 4, math.pi / 4.0)
        door_mid = (door_top + door_low) * 0.5
        door_half = (bay * 0.5, (door_top - door_low) * 0.5)
        panel(teak, [middle, door_mid, face + 0.002], X, Y, door_half, 0.015)
        moulding = (door_half[0] - 0.04, door_half[1] - 0.045)
        panel(frame, [middle, door_mid, face + 0.005], X, Y, moulding, 0.012, hollow=True)
        knob = middle + (door_half[0] - 0.035) * (1.0 if k < doors * 0.5 else -1.0)
        if doors == 1:
            knob = middle
        stud(brass, [knob, door_mid, face + 0.002], Z, 0.017, 0.009, 4, math.pi / 4.0)
    # The carved stiles, each a fluted strip proud of the carcass under a boss.
    for k in range(doors + 1):
        x = -body + stile * 0.5 + k * (bay + stile)
        panel(teak, [x, (door_low + drawer_top) * 0.5, face + STILE], X, Y, (stile * 0.3, (drawer_top - door_low) * 0.5), 0.004)
        stud(teak, [x, drawer_top + 0.003 - 0.012, face + STILE], Z, 0.014, 0.007, 4, math.pi / 4.0)
    # The gallery along the back of the top: a turned post at each end, a rail
    # between their heads and spindles under it.
    reach = half - 0.04
    rise = gallery - 0.022
    rail = height + rise
    back = 0.025
    for side in (-1.0, 1.0):
        x = side * reach
        lathe(brass, [x, height, back], UP, [(POST, 0.0, 0.0), (POST * 0.8, rise, 0.0), (POST * 1.3, rise + 0.012, 0.0), (0.0, gallery, 0.0)], 4, phase=math.pi / 4.0, wound=True)
    sweep(brass, [[-reach, rail - 0.004, back], [reach, rail - 0.004, back]], 0.005, 4, caps=False)
    spindles = max(2, int(round(width / 0.3)))
    for k in range(1, spindles):
        x = -reach + 2.0 * reach * k / spindles
        sweep(brass, [[x, height, back], [x, rail - 0.006, back]], SPINDLE, 3, caps=False)
    if things:
        glass = Part("glass", "mirror")
        decanter(glass, [-half * 0.4, height, depth * 0.55])
        for k in range(2):
            tumbler(glass, [half * (0.3 + 0.3 * k), height, depth * 0.55])
        glass.build(collection)
    for part in (frame, teak, dark, brass, top):
        part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)


def decanter(part, foot):
    """A cut-glass decanter on the top, its stopper in its neck."""
    profile = [(0.0, 0.0, 0.0), (0.042, 0.0, 1.0), (0.045, 0.09, 0.0), (0.016, 0.15, 0.0), (0.014, 0.18, 0.0), (0.022, 0.2, 1.0), (0.0, 0.21, 0.0)]
    lathe(part, foot, UP, profile, 6, phase=math.pi / 6.0, wound=True)


def tumbler(part, foot):
    """A glass on the top, open at its rim."""
    lathe(part, foot, UP, [(0.0, 0.0, 0.0), (0.02, 0.0, 1.0), (0.025, 0.08, 1.0)], 5, wound=True)
