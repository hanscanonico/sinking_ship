class_name LinerService
extends RefCounted
## A liner's rooms of service (RoomDressing.Kind.SERVICE): her galley and gymnasium,
## still dressed as a saloon (CabinDressing.saloon), and her offices — the purser's,
## the post office — still bare but for ShipFittings' berth, as the small cabins they
## were taken for. A later slice draws each its own: ranges and hot presses in the
## galley, the gymnasium's machines, counters and pigeonholes in an office.
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6).

var _space: ShipSpace
var _cabins: CabinDressing


func _init(space: ShipSpace, cabins: CabinDressing) -> void:
	_space = space
	_cabins = cabins


## Whether [param room], a room of service, is an office: what its name says.
static func office(room: ShipRoom) -> bool:
	return String(room.name).to_lower().contains("office")


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	if not office(room):
		_cabins.saloon(mesh, room, glass)


## The lights [param room] is lit by; none keeps RoomDressing's pendants.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a room of service lines its walls, floor, ceiling and beams with
## (RoomDressing.Part); empty keeps the ship's own.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	return paints
