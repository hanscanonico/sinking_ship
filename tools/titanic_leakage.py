"""Leakage through the Titanic's non-watertight boundaries (#513).

Her cells take each of her spaces whole, so a cabin's partitions inside a cell already
pass water freely; what stops water between two cells is either a watertight wall
(ShipWall), a deck, or a boundary that is neither: a hatch trunk's casing, the end wall
two of her deckhouses share, a door drawn shut in one of them. None of those is
watertight. Each such face leaks through a LEAK opening the size of the face, its area
water passes through worked out here from the physical gaps in it, never fitted to how
her night goes (the night's bands are checks on the model, not inputs to it).

Each size below has its source, or is marked est. with its reasoning.
"""

import math

# A shut door's clearance at its jambs and head: 1/8 in (3.2 mm), NFPA 80 (Standard for
# Fire Doors and Other Opening Protectives), the modern trade limit for a swinging door in
# its frame. Her 1912 joinery est. at the same clearance; the gap at its sill est. the same,
# a ship's door shutting onto a raised sill rather than over a floor (NFPA 80's 3/4 in is
# for a door with no sill). As the plate's two hinged doors in the firemen's passage
# (gen_titanic.py) already weep: a 3 mm gap round the door.
DOOR_GAP = 0.0032

# A riveted steel casing's seams, not caulked: est. 0.1 mm open along every seam. Watertight
# work was caulked (its plate edges upset onto the plate under them so the faying surfaces
# bear hard); a casing that is not watertight is riveted only, its faying surfaces drawn
# together by the rivets but held apart between them by the paint between them (red lead,
# est. a coat of about 0.05 mm on each surface). Water passing a 0.1 mm slot through a lap
# runs slower than the orifice law the stepper gives it, so this is the upper end.
SEAM_GAP = 0.0001

# Her plating's breadth between seams: est. 6 ft (1.83 m), the breadth of a strake of hers
# as commonly given for her shell; a casing's vertical seams stand one plate's breadth apart.
PLATE_BREADTH = 6.0 * 0.3048


def door_gaps(width, height):
    """The area, in m², through which a shut ordinary door width by height passes water:
    its two jambs, its head and its sill, each DOOR_GAP open."""
    return DOOR_GAP * 2.0 * (width + height)


def seam_length(width, height, joints):
    """The metres of seam in a face width by height of riveted plating: a vertical seam
    every PLATE_BREADTH along it, and along its width a seam at each of its joints, where
    it meets a deck (its foot, its head and every deck it passes through)."""
    return height * math.ceil(width / PLATE_BREADTH - 1e-9) + width * joints


def casing_seams(width, height, joints):
    """The area, in m², through which a riveted casing face width by height passes water."""
    return SEAM_GAP * seam_length(width, height, joints)
