"""Builds assets/models/whistle/whistle.blend: the steam whistle on a funnel's fore
face (DeckWorks.funnel) — a triple-chime whistle as the liners carried, three brass
bells of three sizes on one chest, over a valve on its steam pipe with the lever its
pull wire works, held to the funnel by an iron stay — in Godot's axes, metres: x out
of the funnel's face (fore), y up, z athwartships, its origin on the funnel's face
where the steam pipe up it ends, the pipe's axis DeckWorks.FUNNEL_PIPE_OUT out from
it. Its box is DeckWorks.WHISTLE_BOX.

    make model-sources MODEL=whistle
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/whistle/whistle.py -- assets/models/whistle/whistle.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, cap, fresh_scene, lathe, save, stud, triangles, tube  # noqa: E402

# The steam pipe's axis out from the face and its radius (DeckWorks.FUNNEL_PIPE).
OUT = 0.16
PIPE = 0.06
# The chest's axis over the origin, its radius and its half length athwartships.
CHEST = (0.16, 0.05, 0.2)
# Each bell: across (z), its radius and its height over the chest's axis.
BELLS = ((-0.13, 0.05, 0.42), (0.0, 0.06, 0.55), (0.13, 0.07, 0.66))
SIDES = 12
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def valve(brass):
    """The flange on the pipe's end and the valve's body over it, up to the chest."""
    rows = [
        (PIPE - 0.003, 0.0, 0.0),
        (PIPE + 0.018, 0.0, 1.0),
        (PIPE + 0.018, 0.024, 1.0),
        (0.05, 0.024, 0.0),
        (0.068, 0.06, 0.0),
        (0.066, 0.085, 0.0),
        (0.04, 0.11, 0.0),
        (0.036, CHEST[0], 0.0),
    ]
    lathe(brass, (OUT, 0.0, 0.0), UP, rows, SIDES, phase=0.26, wound=True)


def chest(brass):
    """The chest athwart over the valve, each bell's neck rising from it."""
    rows = tube(
        brass,
        [OUT, CHEST[0], -CHEST[2]],
        [OUT, CHEST[0], CHEST[2]],
        [(CHEST[1], 0.0, 1.0), (CHEST[1], 0.05, 0.0), (CHEST[1], 0.95, 0.0), (CHEST[1], 1.0, 1.0)],
        10,
        caps=(True, True),
    )
    return rows


def bell(brass, dark, z, radius, height):
    """A bell turned on its neck: the dark mouth its steam speaks from, its body and its
    domed top with the nut that holds it."""
    centre = (OUT, 0.0, z)
    mouth = CHEST[0] + CHEST[1] + 0.03
    lathe(
        dark,
        centre,
        UP,
        [(0.024, CHEST[0] + CHEST[1] - 0.01, 0.0), (0.024, mouth, 0.0), (radius - 0.008, mouth + 0.006, 0.0)],
        SIDES,
    )
    rows = [
        (radius - 0.008, mouth + 0.006, 0.0),
        (radius, mouth + 0.012, 1.0),
        (radius, mouth + 0.028, 0.0),
        (radius, height - 0.04, 0.0),
        (radius, height - 0.022, 1.0),
        (radius * 0.6, height - 0.004, 0.0),
        (0.016, height, 0.0),
        (0.016, height + 0.02, 1.0),
    ]
    ring = lathe(brass, centre, UP, rows, SIDES, wound=True)
    cap(brass, ring[-1], [OUT, height + 0.02, z], [0.0, 1.0, 0.0], 0.0)


def lever(iron):
    """The lever off the valve the pull wire works, its wire running down from it."""
    box(iron, [OUT - 0.008, 0.072, 0.06], [OUT + 0.008, 0.088, 0.3], rim=0.006)
    tube(iron, [OUT, 0.072, 0.29], [OUT, -0.35, 0.29], [(0.004, 0.0, 0.0), (0.004, 1.0, 0.0)], 4, caps=(False, False))


def stay(iron):
    """The iron stay from the funnel's face round the bells, and its plate."""
    high = 0.36
    box(iron, [-0.01, high - 0.1, -0.06], [0.012, high + 0.04, 0.06], rim=0.012)
    box(iron, [0.012, high - 0.02, -0.018], [OUT - 0.06, high + 0.02, 0.018], rim=0.01)
    box(iron, [OUT - 0.08, high - 0.02, -0.2], [OUT - 0.06, high + 0.02, 0.2], rim=0.01)
    for z in (-0.035, 0.035):
        stud(iron, [0.012, high - 0.07, z], [1.0, 0.0, 0.0], 0.01, 0.008)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass = Part("whistle", "brass")
    dark = Part("mouths", "dark")
    iron = Part("stay", "dark")
    valve(brass)
    chest(brass)
    for z, radius, height in BELLS:
        bell(brass, dark, z, radius, height)
    lever(iron)
    stay(iron)
    for part in (brass, dark, iron):
        part.build(collection)
    print("whistle: %d triangles" % triangles(collection))
    save(out)


main()
