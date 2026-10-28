#!/usr/bin/env python3
"""`make guard-check`: every traced deck beside this file holds together (#360).

For each deck file (one with a PLATE, or PARTS that have), through deck.py as
tools/gen_titanic.py reads it — a deck drawn in several views whole, its parts joined:
- it loads, every door on a wall (deck.py asserts that);
- no two rooms overlap, nor two solids, nor a room and a solid but for a solid standing
  wholly inside a room (a lift in its landing);
- every door is in a stretch of wall wider than a door a body passes;
- every stair goes from one deck or raised floor to another, both of them named;
- every room is reached from her open deck or a stair standing in it, through doors and
  open joins: a stair of its own deck's, or a flight another deck's file brings down or
  up to it.

Usage: python3 tools/titanic_plates/deck_check.py   (exits 1 and says why on a problem)
"""
import functools
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from titanic_plates import deck  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DECKS = ("boat", "a", "b", "c", "d", "e", "f", "g", "orlop", "tanktop", "forecastle", "poop")
# The narrowest stretch of wall a door stands in: a body's width and a hand.
DOOR_ROOM = 0.9
EPS = 1e-6


def inside(a, b):
    """Whether box a (x0, x1, z0, z1) lies wholly inside box b."""
    return b[0] - EPS <= a[0] and a[1] <= b[1] + EPS and b[2] - EPS <= a[2] and a[3] <= b[3] + EPS


def overlap(a, b):
    return a[0] < b[1] - EPS and b[0] < a[1] - EPS and a[2] < b[3] - EPS and b[2] < a[3] - EPS


def on_edge(x, z, box, slack=0.3):
    x0, x1, z0, z1 = box
    on_x = (abs(x - x0) < slack or abs(x - x1) < slack) and z0 - EPS <= z <= z1 + EPS
    on_z = (abs(z - z0) < slack or abs(z - z1) < slack) and x0 - EPS <= x <= x1 + EPS
    return on_x or on_z


# Each deck file read once: for its own check, and for the flights it brings to others.
load = functools.lru_cache(maxsize=None)(deck.load)


@functools.lru_cache(maxsize=None)
def flights():
    """Every deck file's stairs, each as (the deck it is the file of, the stair), read as
    tools/gen_titanic.py reads them: a deck drawn in several views whole, never one of
    its PARTS alone."""
    names = [os.path.splitext(f)[0] for f in sorted(os.listdir(HERE))
             if f.endswith(".py") and os.path.splitext(f)[0] not in ("__init__", "deck", "kit", "deck_check")]
    parts = {p for name in names for p in getattr(deck._module(name), "PARTS", [])}
    return tuple((name, stair) for name in names if name not in parts for stair in load(name).stairs)


def check(name):
    found = []
    traced = load(name)
    rooms = [r[1:5] for r in traced.rooms]
    solids = [s[1:5] for s in traced.solids]
    for i in range(len(rooms)):
        for j in range(i + 1, len(rooms)):
            if overlap(rooms[i], rooms[j]):
                found.append("rooms %s and %s overlap" % (traced.rooms[i][0], traced.rooms[j][0]))
    for i in range(len(solids)):
        for j in range(i + 1, len(solids)):
            if overlap(solids[i], solids[j]):
                found.append("solids %s and %s overlap" % (traced.solids[i][0], traced.solids[j][0]))
        for k, room in enumerate(rooms):
            if overlap(solids[i], room) and not inside(solids[i], room):
                found.append("solid %s cuts into room %s" % (traced.solids[i][0], traced.rooms[k][0]))
    for axis, at, a, b, _kind, doors in traced.walls:
        if doors and b - a < DOOR_ROOM:
            found.append("a door in %.2f m of wall at %s %.2f" % (b - a, "x" if axis == 0 else "z", at))
    floors = set(DECKS) | {r[0] for r in traced.raised}
    stair_boxes = []
    for stair_name, x0, x1, z0, z1, _rises, lower, upper in traced.stairs:
        stair_boxes.append((x0, x1, z0, z1))
        for end in (lower, upper):
            if end not in floors:
                found.append("stair %s goes to no deck or raised floor called %s" % (stair_name, end))
        if name not in (lower, upper) and lower not in floors - set(DECKS) and upper not in floors - set(DECKS):
            found.append("stair %s neither leaves nor reaches %s deck" % (stair_name, name))
    # Reach: each room joined to its neighbours through a door on their shared wall or an
    # open stretch of it; to the open deck through a door no other room shares; to
    # another deck through a stair standing in it, its own deck's or a flight another
    # deck's file brings to it (landing).
    reach = {"out"}
    links = {k: set() for k in range(len(rooms))}
    for x, z in traced.doors + traced._auto_doors(traced.walls):
        holders = [k for k, room in enumerate(rooms) if on_edge(x, z, room)]
        if len(holders) == 1:
            links[holders[0]].add("out")
        for p in holders:
            for q in holders:
                if p != q:
                    links[p].add(q)
    for ox0, ox1, oz0, oz1 in traced.open:
        mid = ((ox0 + ox1) * 0.5, (oz0 + oz1) * 0.5)
        holders = [k for k, room in enumerate(rooms) if on_edge(mid[0], mid[1], room, 0.1)]
        for p in holders:
            for q in holders:
                if p != q:
                    links[p].add(q)
    landing = [stair[1:5] for owner, stair in flights() if owner != name and name in stair[6:8]]
    for k, room in enumerate(rooms):
        if any(overlap(room, s) for s in stair_boxes + landing):
            links[k].add("out")
    changed = True
    while changed:
        changed = False
        for k in links:
            if k not in reach and (links[k] & reach):
                reach.add(k)
                changed = True
    for k in range(len(rooms)):
        if k not in reach:
            found.append("room %s at %s is reached from nowhere" % (traced.rooms[k][0], rooms[k]))
    return ["%s: %s" % (name, f) for f in found]


def main():
    problems = []
    names = [os.path.splitext(f)[0] for f in sorted(os.listdir(HERE))
             if f.endswith(".py") and os.path.splitext(f)[0] not in ("__init__", "deck", "kit", "deck_check")]
    # A deck drawn in several views is checked whole, never a part of it alone.
    parts = {p for name in names for p in getattr(deck._module(name), "PARTS", [])}
    for name in names:
        if name not in parts:
            problems += check(name)
    for problem in problems:
        print("deck-check: " + problem, file=sys.stderr)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
