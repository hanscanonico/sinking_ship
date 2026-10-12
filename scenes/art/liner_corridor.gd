class_name LinerCorridor
extends RefCounted
## A liner's first-class corridors (RoomDressing.Kind.FIRST_CORRIDOR): her B, C and D
## deck corridors. Still a corridor's dressing — handrails, a lifebelt, fire buckets,
## RoomDressing's door signs over each doorway — and a later slice draws its own:
## panelled walls, a runner down the floor, cabin doors along it, wall lamps; the
## grand staircase's landings (Kind.STAIRCASE, LinerPublic's for now) come here then.
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6).

var _space: ShipSpace
## RoomDressing's corridor dressing: (mesh: ShipMesh, room: ShipRoom).
var _passage: Callable


func _init(space: ShipSpace, passage: Callable) -> void:
	_space = space
	_passage = passage


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, _glass: Array[Array]) -> void:
	_passage.call(mesh, room)


## The lights [param room] is lit by; none keeps RoomDressing's pendants.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a first-class corridor lines its walls, floor, ceiling and beams with
## (RoomDressing.Part); empty keeps the ship's own.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	return paints
