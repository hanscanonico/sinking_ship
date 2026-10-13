class_name LinerBoiler
extends RefCounted
## A liner's boiler room (RoomDressing.Kind.BOILER), named so: still an engine room's
## dressing (EngineRoom) — its machinery, the boilers in its forward bulkhead, their
## fires and steam pipes — and its riveted steel. A later slice draws its own: rows of
## double-ended Scotch boilers fore and aft, their furnace fronts facing the stokehold,
## coal on its plates, bunker doors in its bulkheads and ash hoists overhead.
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6).

var _engine: EngineRoom


func _init(engine: EngineRoom) -> void:
	_engine = engine


## [param room]'s furnishings, into [param mesh]; [param _glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, _glass: Array[Array]) -> void:
	_engine.build(mesh, room)


## The lights [param room] is lit by: an engine room's (EngineRoom.lights()).
func lights(room: ShipRoom) -> Array[RoomDressing.Light]:
	return _engine.lights(room)


## What a boiler room lines its walls, floor, ceiling and beams with
## (RoomDressing.Part): an engine room's riveted steel over checker plate.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = [ShipPaints.bulkhead, ShipPaints.checker_plate]
	paints.append_array([ShipPaints.steel_overhead, ShipPaints.steel_beam])
	return paints
