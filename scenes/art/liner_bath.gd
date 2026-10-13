class_name LinerBath
extends RefCounted
## A liner's bath (RoomDressing.Kind.BATH): her Turkish bath and her swimming bath,
## named so. Still a saloon's dressing (CabinDressing.saloon) — a later slice draws its
## own: tiled walls and floor, the swimming bath's pool edge and steps, the Turkish
## bath's cooling room with its couches against the walls and its lamps in brass.
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6).

var _space: ShipSpace
var _cabins: CabinDressing


func _init(space: ShipSpace, cabins: CabinDressing) -> void:
	_space = space
	_cabins = cabins


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	_cabins.saloon(mesh, room, glass)


## The lights [param room] is lit by; none keeps RoomDressing's pendants.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a bath lines its walls, floor, ceiling and beams with
## (RoomDressing.Part); empty keeps the ship's own.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	return paints
