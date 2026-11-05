class_name Handrail
extends RefCounted
## A corridor's teak handrail on brass brackets along a wall (RoomDressing's passage), at
## a hand's height over the floor or over a stair beside it — straight between where a
## stair begins and ends — stopping short of the wall's top.

## How far out from the wall's face the rail runs, and how far beyond it stands the foot
## whose floor or stair it is held a hand's height over.
const OUT := 0.065
const FOOT := 0.1
## How far past a stair's end the rail stands down at the floor where the stair ends in a
## step (stops()).
const DROP := 0.01


## The rail along [param wall] in [param mesh], stop to stop (stops()).
static func build(mesh: ShipMesh, layout: ShipLayout, wall: RoomDressing.Wall) -> void:
	var top := wall.floor + 2.4
	var rail := PackedVector3Array()
	for along: float in stops(layout, wall):
		rail.append(_height(layout, wall, along))
	for index in rail.size() - 1:
		var from := rail[index]
		var to := rail[index + 1]
		if from.y > top and to.y > top:
			continue
		if to.y > top:
			to = from.lerp(to, (top - from.y) / (to.y - from.y))
		elif from.y > top:
			from = to.lerp(from, (top - to.y) / (from.y - to.y))
		var pieces := ceili(from.distance_to(to) / RoomDressing.PIECE)
		for piece in pieces:
			var start := from.lerp(to, float(piece) / pieces)
			var end := from.lerp(to, float(piece + 1) / pieces)
			mesh.beam(start, end, Vector2(0.045, 0.05), ShipPaints.teak, 0)
		var brackets := maxi(1, floori(from.distance_to(to)))
		for bracket in brackets + 1:
			var at := from.lerp(to, float(bracket) / brackets) - wall.normal * 0.045
			var box := Rect2(Vector2(at.x, at.z) - Vector2.ONE * 0.02, Vector2.ONE * 0.04)
			RoomDressing.block(mesh, box, at.y - 0.095, at.y - 0.025, ShipPaints.brass)


## Where along [param wall] its rail turns, in order: just short of either end, and where
## each stair of [param layout] beside it begins and ends — one the rail's foot (FOOT)
## meets along it, rising over the wall's floor, so one that lifts the rail (_height()) —
## and, where a stair ends in a step, DROP past that end, so the rail comes down there
## plumb. A stair anywhere else on the ship, or one only coming up to this floor, leaves
## the rail straight: no stop of its own.
static func stops(layout: ShipLayout, wall: RoomDressing.Wall) -> PackedFloat32Array:
	var result := PackedFloat32Array([wall.from + 0.1, wall.to - 0.1])
	var probe := wall.rect(wall.from, wall.to, OUT + FOOT, OUT + FOOT)
	for ramp: ShipRamp in layout.ramps:
		var top := maxf(ramp.start_height, ramp.end_height)
		if top <= wall.floor or not ramp.area.intersects(probe, true):
			continue
		var span := Vector2(ramp.area.position.x, ramp.area.end.x)
		if wall.side % 2 == 1:
			span = Vector2(ramp.area.position.y, ramp.area.end.y)
		for end in 2:
			var past := span[end] + (DROP if end == 1 else -DROP)
			for at: float in [span[end], past]:
				var step := at != past or _step(layout, wall, span[end], past)
				if step and at > wall.from + 0.1 and at < wall.to - 0.1 and not result.has(at):
					result.append(at)
	result.sort()
	return result


## Whether [param wall]'s rail steps between [param at] and [param past] along it.
static func _step(layout: ShipLayout, wall: RoomDressing.Wall, at: float, past: float) -> bool:
	return absf(_height(layout, wall, at).y - _height(layout, wall, past).y) > 0.05


## Where [param wall]'s rail runs at [param along] it: OUT from its face, a hand's height
## over the floor, or over a stair of [param layout] under its foot.
static func _height(layout: ShipLayout, wall: RoomDressing.Wall, along: float) -> Vector3:
	var at := wall.at(along, 0.0, OUT)
	var foot := Vector2(at.x, at.z) + Vector2(wall.normal.x, wall.normal.z) * FOOT
	var surface := wall.floor
	for ramp: ShipRamp in layout.ramps:
		if ramp.contains(foot.x, foot.y):
			surface = maxf(surface, ramp.height_at(foot.x, foot.y))
	return Vector3(at.x, surface + 0.92, at.z)
