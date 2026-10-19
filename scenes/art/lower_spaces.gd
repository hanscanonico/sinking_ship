class_name LowerSpaces
extends RefCounted
## The spaces fitted into a ship's old voids (#148), RoomDressing's: bare tanks and
## passages framed down their hull sides (Kind.TANK) — her double bottom, her wing
## passages; her shaft tunnel, the propeller shaft running aft in it on its plummer
## blocks between guards (Kind.SHAFT); her steering gear, the steering engine against
## its after wall, the quadrant on her rudder's head over it (Kind.STEERING); her chain
## locker, its cables hanging down the faces of the bins they are stowed in from where
## their spurling pipes come through the deck (Kind.LOCKER). Her stores are holds
## (CargoHold).
## Between a step over the floor and a body's height nothing here stands more than
## FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m) anything
## may, and so may anything inside a BOX blocker's footprint: the shaft, the steering
## engine and the chain bins are the layout's own blockers (D6), each drawn to its
## faces as art-lint holds it, and what stands on one stands within a step over its
## top, under the reach of a body the check sets up there.

## A frame down a hull side: how far apart along it, how wide and how deep out of it.
const FRAME_SPACING := 0.6
const FRAME := Vector2(0.08, 0.06)
## The shaft: its radius, its top the blocker's; a plummer block every
## PLUMMER_SPACING along it, PLUMMER long; a coupling's flange every
## COUPLING_SPACING; the guards either side, their lips over the shaft LIP wide.
const SHAFT_RADIUS := 0.16
const PLUMMER_SPACING := 2.4
const PLUMMER := 0.35
const COUPLING_SPACING := 4.0
const LIP := 0.08
## The steering gear: the rudder's head, its radius, this far in from the engine's
## after face and this tall over its top; the quadrant on it, its radius, its arms
## either side of fore and aft; a handwheel on the engine's forward face.
const STOCK_RADIUS := 0.11
const STOCK_IN := 0.3
const STOCK_HEAD := 0.3
const QUADRANT := 0.45
const QUADRANT_ARC := PI / 4.0
const QUADRANT_SEGMENTS := 8
const HANDWHEEL := 0.15
## The chain locker's cables: a link's length and its wire's thickness, flat on its bin's
## face or turned out from it, no further than a wall fitting's depth; where along the
## bin each hangs, as shares of it, and how high over the floor it ends.
const LINK := 0.1
const LINK_WIRE := 0.02
const CABLES: Array[float] = [0.3, 0.7]
const CABLE_FOOT := 0.4

var _space: ShipSpace
var _layout: ShipLayout


func _init(space: ShipSpace) -> void:
	_space = space
	_layout = space.layout


## [param room]'s own, by its [param kind]: frames down its hull sides, then what it is
## for.
func build(mesh: ShipMesh, room: ShipRoom, kind: RoomDressing.Kind) -> void:
	_frames(mesh, room)
	match kind:
		RoomDressing.Kind.SHAFT:
			for shaft: ShipBlocker in _space.furniture(room):
				_shaft(mesh, shaft)
		RoomDressing.Kind.STEERING:
			for engine: ShipBlocker in _space.machinery(room):
				_steering(mesh, engine)
		RoomDressing.Kind.LOCKER:
			for bin: ShipBlocker in _space.machinery(room):
				_chain_bin(mesh, room, bin)


## Frames down every wall of [param room] its hull side stands beyond, floor to the deck
## over it, flat on the wall; none under a hatch in that deck.
func _frames(mesh: ShipMesh, room: ShipRoom) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if not wall.outdoors_beyond():
			continue
		var along := wall.from + FRAME_SPACING * 0.5
		while along < wall.to - FRAME.x:
			var foot := wall.at(along, 0.0)
			var over := _space.roof(room, foot.x, foot.z)
			if over != -1:
				var deck := _layout.platforms[over].height
				if _space.hatch_over(room, foot.x, foot.z) >= deck:
					var frame := wall.rect(
						along - FRAME.x * 0.5, along + FRAME.x * 0.5, 0.0, FRAME.y
					)
					RoomDressing.block(mesh, frame, room.floor_height, deck - ShipArt.PLANK, _rib())
			along += FRAME_SPACING


## The shaft standing over [param blocker]'s footprint along her, its top the
## blocker's: on its plummer blocks between two guards, their lips over it.
func _shaft(mesh: ShipMesh, blocker: ShipBlocker) -> void:
	var area := blocker.area
	var z := area.get_center().y
	var axis := blocker.top - SHAFT_RADIUS
	var aft := Vector3(area.position.x, axis, z)
	var fore := Vector3(area.end.x, axis, z)
	RoomDressing.pipe(mesh, aft, fore, SHAFT_RADIUS, ShipPaints.bright_steel)
	var along := area.position.x + COUPLING_SPACING * 0.5
	while along < area.end.x:
		RoomDressing.flange(mesh, Vector3(along, axis, z), Vector3.RIGHT, SHAFT_RADIUS)
		along += COUPLING_SPACING
	along = area.position.x + PLUMMER_SPACING * 0.5
	while along < area.end.x - PLUMMER * 0.5:
		var half := SHAFT_RADIUS + 0.04
		var block := Rect2(along - PLUMMER * 0.5, z - half, PLUMMER, half * 2.0)
		RoomDressing.block(mesh, block, blocker.bottom, axis, ShipPaints.machine, ShipMesh.RIM_ALL)
		along += PLUMMER_SPACING
	for side: float in [area.position.y, area.end.y]:
		var inward := 1.0 if side == area.position.y else -1.0
		var plate := Rect2(area.position.x, minf(side, side + inward * 0.01), area.size.x, 0.01)
		RoomDressing.block(mesh, plate, blocker.bottom + 0.15, blocker.top, ShipPaints.steel)
		var lip := Rect2(area.position.x, minf(side, side + inward * LIP), area.size.x, LIP)
		RoomDressing.block(mesh, lip, blocker.top - 0.01, blocker.top, ShipPaints.steel)


## The steering engine over [param blocker]'s footprint, cased to its faces with a
## handwheel on its forward face, and on it her rudder's head and the quadrant keyed to
## it, swinging over the casing.
func _steering(mesh: ShipMesh, blocker: ShipBlocker) -> void:
	var area := blocker.area
	var top := blocker.top
	RoomDressing.block(mesh, area, blocker.bottom, top, ShipPaints.engine, ShipMesh.RIM_ALL)
	var face := Vector3(area.end.x + 0.01, blocker.bottom + 1.0, area.get_center().y)
	RoomDressing.wheel(mesh, face, Vector3.RIGHT, HANDWHEEL)
	var stock := Vector2(area.position.x + STOCK_IN, area.get_center().y)
	mesh.cylinder(stock, STOCK_RADIUS, top, top + STOCK_HEAD, 10, ShipPaints.machine)
	var head := top + STOCK_HEAD * 0.5
	var fan := PackedVector3Array([Vector3(stock.x, head, stock.y)])
	for index in QUADRANT_SEGMENTS + 1:
		var turn := lerpf(-QUADRANT_ARC, QUADRANT_ARC, float(index) / QUADRANT_SEGMENTS)
		fan.append(Vector3(stock.x + cos(turn) * QUADRANT, head, stock.y + sin(turn) * QUADRANT))
	for normal: Vector3 in [Vector3.UP, Vector3.DOWN]:
		var ring := fan.duplicate()
		if normal == Vector3.DOWN:
			ring.reverse()
		mesh.polygon(ring, normal, ShipPaints.machine, head - 0.05, head)


## A bin the cable is stowed in over [param blocker]'s footprint in [param room],
## plated to its faces, its cables hanging down its face onto the stairs from where they
## come through the deck over it into their spurling pipes.
func _chain_bin(mesh: ShipMesh, room: ShipRoom, blocker: ShipBlocker) -> void:
	var area := blocker.area
	RoomDressing.block(mesh, area, blocker.bottom, blocker.top, ShipPaints.steel, ShipMesh.RIM_ALL)
	var middle := room.area.get_center()
	var inboard := area.end.y if area.get_center().y < middle.y else area.position.y
	var out := Vector3.BACK if inboard == area.end.y else Vector3.FORWARD
	var top := blocker.top - ShipArt.PLANK - LINK
	for share: float in CABLES:
		var x := lerpf(area.position.x, area.end.x, share)
		var link := 0
		var y := top
		while y > blocker.bottom + CABLE_FOOT:
			var turned := link % 2 == 1
			var off := LINK * (1.0 if turned else 0.5) + LINK_WIRE
			var normal := Vector3.RIGHT if turned else out
			var centre := Vector3(x, y, inboard) + out * off
			RoomDressing.ring(mesh, centre, normal, LINK * 0.5 - LINK_WIRE, LINK * 0.5, _cable(), 8)
			RoomDressing.ring(
				mesh, centre, -normal, LINK * 0.5 - LINK_WIRE, LINK * 0.5, _cable(), 8
			)
			y -= LINK * 0.8
			link += 1


static func _rib() -> ShipMesh.Paint:
	return ShipPaints.hold_frame


static func _cable() -> ShipMesh.Paint:
	return ShipPaints.dark
