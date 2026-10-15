"""What is fixed to a funnel (DeckWorks.funnel), for the build scripts of its whistle,
its waste pipe's head and its pipe clamps (assets/models/whistle_NN, waste_pipe_head_NN
and pipe_clamp_NN): one size of each for each size of funnel, made for a funnel NN
hundredths of a metre round (DeckWorks.FUNNEL_FITTINGS) at its scale
(FUNNEL_FITTING_SCALE), never one model scaled.

Each is shaped here at the scale of a small steamer's funnel and its points scaled
whole for a larger one, but what meets the funnel's own rim, which is the same size on
every funnel (DeckWorks.FUNNEL_RIM), is sized in metres.

- The whistle: a triple-chime whistle as the liners carried, three brass bells of three
  sizes on one chest, over a valve on its steam pipe with the lever its pull wire
  works, held to the funnel by an iron stay. Its origin is on the funnel's fore face
  where the steam pipe up it ends, x out of the face, y up, z athwartships.
- The waste pipe's head: a flanged joint where the pipe up the funnel's after face ends
  at its top, the pipe standing on over the rim to a flared bell mouth, black inside,
  and the stay that holds it to the rim. Its origin is on the pipe's axis at the
  funnel's top, the funnel toward +x.
- A pipe clamp: a strap round the pipe on a flat bar riveted to the funnel. Its origin
  is on the funnel's face at the clamp's middle, the pipe along +x.

The pipes' axes stand DeckWorks.FUNNEL_PIPE_OUT out from the face, DeckWorks.FUNNEL_PIPE
round, both times the scale.
"""

import math
import sys

from model_kit import Part, box, cap, fresh_scene, lathe, save, stud, torus, triangles, tube

# The pipes' axes out from the face and their radius, at scale 1.
OUT = 0.16
PIPE = 0.06
# The funnel's rim stands this far proud of its face and this deep under its top, in
# metres on every funnel.
RIM = (0.04, 0.12)
SIDES = 12
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])

# The whistle's chest: its axis over the origin, its radius and its half length
# athwartships; each bell across (z), its radius and its height over the origin.
CHEST = (0.16, 0.05, 0.2)
BELLS = ((-0.13, 0.05, 0.42), (0.0, 0.06, 0.55), (0.13, 0.07, 0.66))
# The waste pipe's mouth over the funnel's top, and its radius.
RISE = 0.5
MOUTH = 0.1


def _scaled(parts, scale):
    """Every point of [parts] scaled about the origin by [scale]."""
    for part in parts:
        part.points = [p * scale for p in part.points]


def _write(name, parts, collection):
    for part in parts:
        part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(sys.argv[sys.argv.index("--") + 1])


def _valve(brass):
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


def _chest(brass):
    """The chest athwart over the valve, each bell's neck rising from it."""
    tube(
        brass,
        [OUT, CHEST[0], -CHEST[2]],
        [OUT, CHEST[0], CHEST[2]],
        [(CHEST[1], 0.0, 1.0), (CHEST[1], 0.05, 0.0), (CHEST[1], 0.95, 0.0), (CHEST[1], 1.0, 1.0)],
        10,
        caps=(True, True),
    )


def _bell(brass, dark, z, radius, height):
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


def _lever(iron):
    """The lever off the valve the pull wire works, its wire running down from it."""
    box(iron, [OUT - 0.008, 0.072, 0.06], [OUT + 0.008, 0.088, 0.3], rim=0.006)
    tube(iron, [OUT, 0.072, 0.29], [OUT, -0.35, 0.29], [(0.004, 0.0, 0.0), (0.004, 1.0, 0.0)], 4, caps=(False, False))


def _whistle_stay(iron):
    """The iron stay from the funnel's face round the bells, and its plate."""
    high = 0.36
    box(iron, [-0.01, high - 0.1, -0.06], [0.012, high + 0.04, 0.06], rim=0.012)
    box(iron, [0.012, high - 0.02, -0.018], [OUT - 0.06, high + 0.02, 0.018], rim=0.01)
    box(iron, [OUT - 0.08, high - 0.02, -0.2], [OUT - 0.06, high + 0.02, 0.2], rim=0.01)
    for z in (-0.035, 0.035):
        stud(iron, [0.012, high - 0.07, z], [1.0, 0.0, 0.0], 0.01, 0.008)


def build_whistle(name, scale):
    """Writes the .blend named on the command line: the whistle at [scale]."""
    collection = fresh_scene()
    brass = Part("whistle", "brass")
    dark = Part("mouths", "dark")
    iron = Part("stay", "dark")
    _valve(brass)
    _chest(brass)
    for z, radius, height in BELLS:
        _bell(brass, dark, z, radius, height)
    _lever(iron)
    _whistle_stay(iron)
    parts = (brass, dark, iron)
    _scaled(parts, scale)
    _write(name, parts, collection)


def _waste_pipe(iron):
    """The joint's flange, the pipe on over it and its flared mouth, turned, and the
    bore's floor down it."""
    rows = [
        (PIPE - 0.003, -0.02, 0.0),
        (PIPE + 0.022, -0.02, 1.0),
        (PIPE + 0.022, 0.0, 1.0),
        (PIPE, 0.0, 0.0),
        (PIPE, RISE - 0.12, 0.0),
        (MOUTH - 0.015, RISE - 0.03, 0.0),
        (MOUTH, RISE - 0.012, 1.0),
        (MOUTH, RISE, 1.0),
        (MOUTH - 0.014, RISE, 1.0),
        (PIPE - 0.008, RISE - 0.1, 0.0),
    ]
    ring = lathe(iron, (0.0, 0.0, 0.0), UP, rows, SIDES, wound=True)
    cap(iron, ring[-1], [0.0, RISE - 0.1, 0.0], [0.0, 1.0, 0.0], 0.0)
    for k in range(4):
        angle = 2.0 * math.pi * (k + 0.5) / 4
        at = [(PIPE + 0.011) * math.cos(angle), 0.0, (PIPE + 0.011) * math.sin(angle)]
        stud(iron, at, [0.0, 1.0, 0.0], 0.008, 0.006)


def _waste_stay(iron, scale):
    """The stay from the pipe to the funnel's rim, and its clip on the rim: the rim's
    face and depth in metres whatever the scale, the stay as thick as the scale has
    it."""
    y = -RIM[1] * 0.5
    face = OUT * scale - RIM[0]
    clip = 0.012 * scale
    box(iron, [(PIPE - 0.004) * scale, y - 0.02, -0.012 * scale], [face - clip, y + 0.02, 0.012 * scale], rim=0.01)
    box(iron, [face - clip, y - 0.04, -0.04 * scale], [face, y + 0.04, 0.04 * scale], rim=0.01, skip=((0, 1),))


def build_waste_pipe_head(name, scale):
    """Writes the .blend named on the command line: the waste pipe's head at
    [scale]."""
    collection = fresh_scene()
    iron = Part("pipe", "dark")
    _waste_pipe(iron)
    _scaled((iron,), scale)
    _waste_stay(iron, scale)
    _write(name, (iron,), collection)


def build_pipe_clamp(name, scale):
    """Writes the .blend named on the command line: a pipe clamp at [scale]."""
    collection = fresh_scene()
    iron = Part("clamp", "dark")
    box(iron, [-0.01, -0.035, -0.045], [0.008, 0.035, 0.045], rim=0.01, skip=((0, -1),), plain=((1, -1), (1, 1)))
    box(iron, [0.008, -0.016, -0.01], [OUT - PIPE, 0.016, 0.01], rim=0.008, skip=((0, -1), (0, 1)))
    axes = ([1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0])
    torus(iron, [OUT, 0.0, 0.0], axes, PIPE + 0.006, (0.006, 0.018), 8, 3)
    for z in (-0.03, 0.03):
        stud(iron, [0.008, 0.0, z], [1.0, 0.0, 0.0], 0.008, 0.006)
    _scaled((iron,), scale)
    _write(name, (iron,), collection)
