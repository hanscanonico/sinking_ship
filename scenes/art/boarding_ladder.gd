class_name BoardingLadder
extends RefCounted
## A boarding ladder, dressed (SH5, SH14b): two steel stiles and teak rungs, their line
## OUT outboard of where the ladder hangs at each height (ShipLayout.ladder_at) — down
## her side, on her shell, following her flare and her bilge, or straight down from its
## deck's edge where her side stands plumb there — from its deck, the top rung flush
## with it, the rest RUNG_SPACING apart, down to BELOW under her
## waterline at rest. Godot owns its form: every point of it is read from her data.

## How far outboard of where it hangs its rungs' line stands, clear of her plating and
## the toe rail; how far under her waterline at rest it reaches.
const OUT := 0.12
const BELOW := 0.4
const RUNG_SPACING := 0.3
const RUNG := 0.04
const STILE := 0.06
## How far apart up it its stiles may bend to follow her side, and how near straight
## (one less the cosine between two runs) a stile runs on as one.
const BEND := 0.25
const STRAIGHT := 1e-6


## Draws [param ladder] of [param layout] into [param mesh].
static func draw(mesh: ShipMesh, layout: ShipLayout, ladder: ShipLadder) -> void:
	var bottom := -layout.freeboard - BELOW
	var heights := PackedFloat64Array()
	var height := layout.platforms[ladder.platform].height
	var rung := height - RUNG * 0.5
	while height > bottom + BEND * 0.5:
		heights.append(height)
		height -= BEND
	heights.append(bottom)
	var lines: Array[PackedVector2Array] = []
	for at: float in heights:
		lines.append(line(layout, ladder, at))
	for end in 2:
		var top := 0
		for index in range(1, heights.size()):
			var last := index == heights.size() - 1
			if last or not _in_line(lines, heights, end, top, index, index + 1):
				_stile(mesh, lines[top][end], heights[top], lines[index][end], heights[index])
				top = index
	while rung > bottom:
		var across := line(layout, ladder, rung)
		_rung(mesh, across[0], across[1], rung)
		rung -= RUNG_SPACING


## Where [param ladder]'s rungs' line stands at [param height], x/z: OUT outboard of
## where it hangs there.
static func line(layout: ShipLayout, ladder: ShipLadder, height: float) -> PackedVector2Array:
	var out := layout.ladder_outward(ladder) * OUT
	var hangs := layout.ladder_at(ladder, height)
	return PackedVector2Array([hangs[0] + out, hangs[1] + out])


## The height of the middle of [param ladder]'s lowest rung, the last of draw()'s over
## BELOW under her waterline.
static func lowest_rung(layout: ShipLayout, ladder: ShipLadder) -> float:
	var bottom := -layout.freeboard - BELOW
	var rung := layout.platforms[ladder.platform].height - RUNG * 0.5
	while rung - RUNG_SPACING > bottom:
		rung -= RUNG_SPACING
	return rung


## Whether the stile at [param end] of [param lines], at [param heights], runs on
## straight from its point [param top] through [param through] to [param next].
static func _in_line(
	lines: Array[PackedVector2Array],
	heights: PackedFloat64Array,
	end: int,
	top: int,
	through: int,
	next: int
) -> bool:
	var a := Vector3(lines[top][end].x, heights[top], lines[top][end].y)
	var b := Vector3(lines[through][end].x, heights[through], lines[through][end].y)
	var c := Vector3(lines[next][end].x, heights[next], lines[next][end].y)
	return (b - a).normalized().dot((c - a).normalized()) > 1.0 - STRAIGHT


## A stile from [param top] (x/z) at [param top_height] down to [param foot] at
## [param foot_height]: an upright box where it hangs plumb, a beam where her side
## slopes.
static func _stile(
	mesh: ShipMesh, top: Vector2, top_height: float, foot: Vector2, foot_height: float
) -> void:
	if top.is_equal_approx(foot):
		var stile := Rect2(top - Vector2.ONE * STILE * 0.5, Vector2.ONE * STILE)
		mesh.box(stile, foot_height, top_height, ShipPaints.steel)
		return
	mesh.beam(
		Vector3(foot.x, foot_height, foot.y),
		Vector3(top.x, top_height, top.y),
		Vector2(STILE, STILE),
		ShipPaints.steel
	)


## A teak rung from [param from] to [param to] (x/z) centred at [param height], its
## ends running past them by half its width: a box where it runs along an axis, a
## turned one where her side bends it askew.
static func _rung(mesh: ShipMesh, from: Vector2, to: Vector2, height: float) -> void:
	var span := to - from
	var along := span.normalized()
	var start := from - along * RUNG * 0.5
	var end := to + along * RUNG * 0.5
	if is_zero_approx(span.x) or is_zero_approx(span.y):
		var area := Rect2(start, Vector2.ZERO).expand(end)
		var grow := Vector2(absf(along.y), absf(along.x)) * RUNG * 0.5
		area = area.grow_individual(grow.x, grow.y, grow.x, grow.y)
		mesh.box(area, height - RUNG * 0.5, height + RUNG * 0.5, ShipPaints.teak)
		return
	var middle := (start + end) * 0.5
	mesh.turned_box(
		Transform3D(Basis(Vector3.UP, -span.angle()), Vector3(middle.x, height, middle.y)),
		Vector3(start.distance_to(end), RUNG, RUNG),
		ShipPaints.teak
	)
