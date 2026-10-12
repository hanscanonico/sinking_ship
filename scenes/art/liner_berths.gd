class_name LinerBerths
extends RefCounted
## A liner's berths (RoomDressing.Kind.BERTHS): third class's berths, the officers'
## and the crew's quarters. Still each a lower-deck cabin's dressing, numbered on with
## the other cabins (RoomDressing._cabin) — a later slice draws its own: tiers of
## berths along the walls, lockers, a table and benches.
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6).

var _space: ShipSpace
## RoomDressing's next lower-deck cabin: (mesh: ShipMesh, room: ShipRoom,
## glass: Array[Array]), numbered on from the last.
var _cabin: Callable


func _init(space: ShipSpace, cabin: Callable) -> void:
	_space = space
	_cabin = cabin


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	_cabin.call(mesh, room, glass)


## The lights [param room] is lit by; none keeps RoomDressing's pendants.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a block of berths lines its walls, floor, ceiling and beams with
## (RoomDressing.Part); empty keeps the ship's own.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	return paints
