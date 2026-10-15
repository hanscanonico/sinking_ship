"""Builds assets/models/stateroom_door/stateroom_door.blend: a first-class stateroom's
door on a corridor wall (LinerCorridor._stateroom_door) — a white-painted door of four
moulded panels, its brass number plate and knob, in a varnished architrave — in
Godot's axes, metres: x along the wall (Wall.right), y up, z out from the wall's face,
its origin on the floor at the wall's face under the door's middle. The door is
LinerCorridor.DOOR wide and tall and DOOR_DEPTH out, its architrave ARCHITRAVE round
it, its knob no more than DOOR_KNOB past its face.

    make model-sources MODEL=stateroom_door
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/stateroom_door/stateroom_door.py -- \
        assets/models/stateroom_door/stateroom_door.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import RIM_LOOP, Part, box, fresh_scene, lathe, panel, save, triangles  # noqa: E402

# LinerCorridor's DOOR, DOOR_DEPTH, ARCHITRAVE and DOOR_KNOB.
DOOR = (0.8, 2.0)
DEPTH = 0.02
ARCHITRAVE = 0.06
KNOB = 0.05
# How far the architrave stands off the wall.
TRIM = 0.012
# The panels: each (middle along, middle up, half width, half height).
PANELS = [(-0.19, 1.42, 0.14, 0.4), (0.19, 1.42, 0.14, 0.4), (-0.19, 0.5, 0.14, 0.3), (0.19, 0.5, 0.14, 0.3)]
# The number plate's middle's height and half size; the knob's height and along.
PLATE = (1.55, 0.06, 0.035)
HANDLE = (1.0, 0.3)

BACK = (2, -1)
FLOOR = (1, -1)
TOP = (1, 1)
X = [1.0, 0.0, 0.0]
Y = [0.0, 1.0, 0.0]
Z = [0.0, 0.0, 1.0]


def architrave(frame):
    """The jambs either side and the head over them: one frame flat on the wall, mitred
    at its corners and inked round its outside a loop in (the door's own rim inks its
    inside), its two outer sides drawn full height and its top, over the eye, left
    out."""
    half = DOOR[0] * 0.5
    outer = half + ARCHITRAVE
    top = DOOR[1] + ARCHITRAVE
    edge = [[-outer, 0.0], [-outer, top], [outer, top], [outer, 0.0]]
    loop = [[-outer + RIM_LOOP, 0.0], [-outer + RIM_LOOP, top - RIM_LOOP], [outer - RIM_LOOP, top - RIM_LOOP], [outer - RIM_LOOP, 0.0]]
    opening = [[-half, 0.0], [-half, DOOR[1]], [half, DOOR[1]], [half, 0.0]]
    for k in range(3):
        for a, b, ink in ((edge, loop, 1.0), (loop, opening, 0.0)):
            corners = [a[k] + [TRIM], a[k + 1] + [TRIM], b[k + 1] + [TRIM], b[k] + [TRIM]]
            frame.face([frame.point(c) for c in corners], [ink, ink, 0.0, 0.0], Z)
    for side in (-1.0, 1.0):
        x = side * outer
        corners = [[x, 0.0, 0.0], [x, top, 0.0], [x, top, TRIM], [x, 0.0, TRIM]]
        frame.face([frame.point(c) for c in corners], [0.0] * 4, [side, 0.0, 0.0])


def leaf(white):
    """The door, its face and its edges, and its four panels moulded on it, their
    middles the door's own face; its top over the eye left out."""
    half = DOOR[0] * 0.5
    box(white, [-half, 0.0, 0.0], [half, DOOR[1], DEPTH], skip=(BACK, FLOOR, TOP), plain=((0, -1), (0, 1)))
    for x, y, w, h in PANELS:
        panel(white, [x, y, DEPTH + 0.002], X, Y, (w, h), 0.02, hollow=True)


def furniture(brass):
    """The number plate and the knob on its rose."""
    panel(brass, [0.0, PLATE[0], DEPTH + 0.003], X, Y, (PLATE[1], PLATE[2]), 0.01)
    centre = [HANDLE[1], HANDLE[0], DEPTH]
    out = ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])
    profile = [(0.022, 0.0, 1.0), (0.006, 0.008, 0.0), (0.019, 0.032, 0.0), (0.0, KNOB, 0.0)]
    lathe(brass, centre, out, profile, 5, wound=True)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    frame = Part("frame", "frame")
    white = Part("white", "white")
    brass = Part("brass", "brass")
    architrave(frame)
    leaf(white)
    furniture(brass)
    for part in (frame, white, brass):
        part.build(collection)
    print("stateroom_door: %d triangles" % triangles(collection))
    save(out)


main()
