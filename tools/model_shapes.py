"""Turned, boxed and swept shapes for the props' build scripts, on top of
tools/model_kit.py's Part: points in Godot space, each face wound out and inked per
corner (1 at a hard edge, 0 inside a face) as the kit's faces are.
"""

import math

from mathutils import Vector


def frame(axis):
    """Two unit vectors square to [axis] and to each other, (u, v, axis) right-handed."""
    a = Vector(axis).normalized()
    helper = Vector((0.0, 1.0, 0.0)) if abs(a.y) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = helper.cross(a).normalized()
    v = a.cross(u).normalized()
    return u, v


def lathe(part, centre, axis, profile, sides, phase=0.0):
    """A solid turned about [axis] through [centre]: [profile] a list of (radius,
    along the axis, ink), walked from the axis at its foot round the outside to the
    axis at its head (counter-clockwise with the radius to the right and the axis up),
    so each face's way out is known. A radius of 0 closes the turn there in a point."""
    c = Vector(centre)
    a = Vector(axis).normalized()
    u, v = frame(a)
    rows = []
    for radius, along, ink in profile:
        row = []
        for k in range(sides):
            t = 2.0 * math.pi * k / sides + phase
            radial = u * math.cos(t) + v * math.sin(t)
            row.append((c + a * along + radial * radius, radial, ink))
        rows.append(row)
    for j in range(len(profile) - 1):
        dr = profile[j + 1][0] - profile[j][0]
        dh = profile[j + 1][1] - profile[j][1]
        if abs(dr) < 1e-9 and abs(dh) < 1e-9:
            continue
        low = rows[j]
        high = rows[j + 1]
        for k in range(sides):
            n = (k + 1) % sides
            radial = (low[k][1] + low[n][1]) * 0.5
            outward = radial * dh - a * dr
            if profile[j][0] == 0.0:
                ids = [part.point(low[0][0]), part.point(high[k][0]), part.point(high[n][0])]
                inks = [low[0][2], high[k][2], high[n][2]]
            elif profile[j + 1][0] == 0.0:
                ids = [part.point(low[k][0]), part.point(low[n][0]), part.point(high[0][0])]
                inks = [low[k][2], low[n][2], high[0][2]]
            else:
                ids = [
                    part.point(low[k][0]),
                    part.point(low[n][0]),
                    part.point(high[n][0]),
                    part.point(high[k][0]),
                ]
                inks = [low[k][2], low[n][2], high[n][2], high[k][2]]
            part.face(ids, inks, outward)


def block(part, centre, axes, half, rim=None, skip=()):
    """A box round [centre] along the three [axes] (unit, square to each other) by
    [half] each way. With a [rim], each face is a frame of four trapezoids round its
    middle, inked at its edges and falling to 0 [rim] in; without, plain and uninked.
    [skip] names faces left off, as (axis index, sign)."""
    c = Vector(centre)
    ax = [Vector(a).normalized() * h for a, h in zip(axes, half)]
    for i in range(3):
        for sign in (-1.0, 1.0):
            if (i, sign) in skip:
                continue
            j, k = (i + 1) % 3, (i + 2) % 3
            middle = c + ax[i] * sign
            corners = [
                middle - ax[j] - ax[k],
                middle + ax[j] - ax[k],
                middle + ax[j] + ax[k],
                middle - ax[j] + ax[k],
            ]
            outward = ax[i] * sign
            if rim is None:
                part.face([part.point(p) for p in corners], [0.0] * 4, outward)
                continue
            sj = max(0.0, 1.0 - rim / half[j])
            sk = max(0.0, 1.0 - rim / half[k])
            inner = [
                middle - ax[j] * sj - ax[k] * sk,
                middle + ax[j] * sj - ax[k] * sk,
                middle + ax[j] * sj + ax[k] * sk,
                middle - ax[j] * sj + ax[k] * sk,
            ]
            outer_ids = [part.point(p) for p in corners]
            inner_ids = [part.point(p) for p in inner]
            part.face(inner_ids, [0.0] * 4, outward)
            for m in range(4):
                n = (m + 1) % 4
                part.face(
                    [outer_ids[m], outer_ids[n], inner_ids[n], inner_ids[m]],
                    [1.0, 1.0, 0.0, 0.0],
                    outward,
                )


def sweep(part, path, radius, sides, ink=0.0, caps=True):
    """A tube of [radius] along the polyline [path], [sides] round, each ring square
    to the path there; capped at both ends when [caps]."""
    points = [Vector(p) for p in path]
    rows = []
    centres = []
    previous_u = None
    for index, p in enumerate(points):
        if index == 0:
            tangent = points[1] - points[0]
        elif index == len(points) - 1:
            tangent = points[-1] - points[-2]
        else:
            tangent = (points[index + 1] - points[index - 1])
        tangent.normalize()
        if previous_u is None:
            u, v = frame(tangent)
        else:
            u = (previous_u - tangent * previous_u.dot(tangent)).normalized()
            v = tangent.cross(u).normalized()
        previous_u = u
        row = []
        for k in range(sides):
            t = 2.0 * math.pi * (k + 0.5) / sides
            row.append(p + (u * math.cos(t) + v * math.sin(t)) * radius)
        rows.append(row)
        centres.append(p)
    for j in range(len(rows) - 1):
        ids_low = [part.point(p) for p in rows[j]]
        ids_high = [part.point(p) for p in rows[j + 1]]
        for k in range(sides):
            n = (k + 1) % sides
            middle = (rows[j][k] + rows[j][n] + rows[j + 1][k] + rows[j + 1][n]) / 4.0
            axis_mid = (centres[j] + centres[j + 1]) / 2.0
            part.face(
                [ids_low[k], ids_low[n], ids_high[n], ids_high[k]], [ink] * 4, middle - axis_mid
            )
    if caps:
        for row, centre, toward in ((rows[0], points[0], points[0] - points[1]),
                                    (rows[-1], points[-1], points[-1] - points[-2])):
            part.face([part.point(p) for p in row], [ink] * sides, toward)


def stud(part, centre, normal, radius, height, sides=4, phase=0.0):
    """A rivet head or a nut: a low point of [sides] standing [height] off [centre]
    along [normal], its foot [radius] round; no base, it sits on a face."""
    c = Vector(centre)
    n = Vector(normal).normalized()
    u, v = frame(n)
    ring = []
    for k in range(sides):
        t = 2.0 * math.pi * k / sides + phase
        ring.append(part.point(c + (u * math.cos(t) + v * math.sin(t)) * radius))
    apex = part.point(c + n * height)
    for k in range(sides):
        part.face([ring[k], ring[(k + 1) % sides], apex], [0.0, 0.0, 0.0], n)
