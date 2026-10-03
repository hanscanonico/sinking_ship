class_name Surfaces
extends RefCounted
## The only door to spatial questions about the ship (D6, D13): what is under a
## body, which railings it is pressing on, whether a path crosses one, and whether
## a point is wet. One-platform version (SH1) — no ramps, no landing between decks
## yet.

const NONE := -1


## A body's circle overlapping a railing span.
class RailContact:
	## Unit vector in the ship plane (x, z), from the railing toward its platform.
	var normal: Vector2
	## How far the circle reaches past the railing's line.
	var depth: float

	func _init(inward: Vector2, overlap: float) -> void:
		normal = inward
		depth = overlap


var _platforms: Array[ShipPlatform] = []
var _railings: Array[ShipRailing] = []
## Per railing, the unit normal pointing onto its platform.
var _rail_normals := PackedVector2Array()


func _init(layout: ShipLayout) -> void:
	_platforms = layout.platforms.duplicate()
	_railings = layout.railings.duplicate()
	for railing: ShipRailing in _railings:
		var normal := (railing.to - railing.from).normalized().orthogonal()
		var centre := _platforms[railing.platform].area.get_center()
		if (centre - railing.from).dot(normal) < 0.0:
			normal = -normal
		_rail_normals.append(normal)


## The platform whose area holds [param ship_point]'s x/z, or NONE.
func under(ship_point: Vector3) -> int:
	for index in _platforms.size():
		if _platforms[index].contains(ship_point.x, ship_point.z):
			return index
	return NONE


func height(surface: int) -> float:
	return _platforms[surface].height


## Every railing of [param surface] that a circle of [param radius] centred on
## [param ship_point] overlaps, in layout order. A railing holds only along its
## span: a centre level with a gap is touching nothing.
func rail_contacts(ship_point: Vector3, radius: float, surface: int) -> Array[RailContact]:
	var contacts: Array[RailContact] = []
	var point := Vector2(ship_point.x, ship_point.z)
	for index in _railings.size():
		var railing := _railings[index]
		if railing.platform != surface:
			continue
		var span := railing.to - railing.from
		var along := (point - railing.from).dot(span) / span.length_squared()
		if along < 0.0 or along > 1.0:
			continue
		var inside := (point - railing.from).dot(_rail_normals[index])
		if absf(inside) < radius:
			contacts.append(RailContact.new(_rail_normals[index], radius - inside))
	return contacts


## Whether the straight path from [param from_point] to [param to_point] (x/z)
## crosses a railing span.
func railed(from_point: Vector3, to_point: Vector3) -> bool:
	var start := Vector2(from_point.x, from_point.z)
	var end := Vector2(to_point.x, to_point.z)
	for railing: ShipRailing in _railings:
		if Geometry2D.segment_intersects_segment(start, end, railing.from, railing.to) != null:
			return true
	return false


## Flooded is geometry (D7): below the sea plane under the schedule's pose.
func wet(ship_point: Vector3, pose: ShipPose) -> bool:
	return pose.world_height(ship_point) < 0.0
