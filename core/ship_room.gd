class_name ShipRoom
extends Resource
## A named room in ship space (D6): an annotation over the platforms it stands on and
## the walls round it, read by the lint, the bots' walk graph, the HUD and the
## greybox. No rule reads it — the walls are blockers and stop bodies as blockers do,
## and the water inside is the sea plane (D7).


## A gap in a room's walls along one of its sides: a doorway, open, never closed.
class Door:
	## The gap's two ends in the ship's x/z plane, along the room's side.
	var from: Vector2
	var to: Vector2
	## Unit vector in the ship plane, out of the room.
	var outward: Vector2

	func _init(gap_from: Vector2, gap_to: Vector2, out_of_room: Vector2) -> void:
		from = gap_from
		to = gap_to
		outward = out_of_room

	func width() -> float:
		return from.distance_to(to)

	func middle() -> Vector2:
		return (from + to) * 0.5


@export var name: StringName
## The floor in the ship's x/z plane, out to the middle of its walls: position is its
## (x, z) minimum corner.
@export var area: Rect2
## The height of the deck it stands on.
@export var floor_height: float


## Whether feet at [param ship_point] stand in this room: inside its area, within
## [param step] of its floor.
func holds(ship_point: Vector3, step: float) -> bool:
	return (
		absf(ship_point.y - floor_height) <= step
		and ship_point.x >= area.position.x
		and ship_point.x <= area.end.x
		and ship_point.z >= area.position.y
		and ship_point.z <= area.end.y
	)


## Every gap in the walls along this room's four sides for a body [param body_height]
## tall standing on its floor — what stands where, [param surfaces] answers.
func doors(surfaces: Surfaces, body_height: float, step: float) -> Array[Door]:
	var found: Array[Door] = []
	var low := area.position
	var high := area.end
	var sides := [
		[Vector2(low.x, low.y), Vector2(high.x, low.y), Vector2.UP],
		[Vector2(high.x, low.y), Vector2(high.x, high.y), Vector2.RIGHT],
		[Vector2(high.x, high.y), Vector2(low.x, high.y), Vector2.DOWN],
		[Vector2(low.x, high.y), Vector2(low.x, low.y), Vector2.LEFT],
	]
	for side: Array in sides:
		var start: Vector2 = side[0]
		var end: Vector2 = side[1]
		var along := (end - start).normalized()
		var stretches := surfaces.clear_stretches(
			Vector3(start.x, floor_height, start.y),
			Vector3(end.x, floor_height, end.y),
			body_height,
			step
		)
		for stretch: Vector2 in stretches:
			found.append(Door.new(start + along * stretch.x, start + along * stretch.y, side[2]))
	return found
