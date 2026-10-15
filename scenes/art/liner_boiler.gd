class_name LinerBoiler
extends RefCounted
## A liner's boiler room (RoomDressing.Kind.BOILER), named so: each machinery box on
## its plates drawn as a double-ended Scotch boiler with its uptake over it into a
## casing under the deck, its furnace fronts (EngineRoom.front()) and their fires on its
## fore and after ends where a firing aisle opens before them; on the cross bunker's
## face forward a coal face round the bunker door, a shovel and a rake hung flat on it;
## an engine room's wall dressing (EngineRoom.walls()) and pendants over the aisles
## (EngineRoom.pendants()). A boiler room with no machinery is an engine room's.
## Between a step over the floor and a body's height, nothing it draws may stand more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM (1.85 m)
## anything may, and so may anything standing inside a BOX blocker's footprint —
## art-lint holds it to that, and no blocker is ever widened to hide a piece (D6).

## A boiler: its shell's height over the plates at most, the band round its top, how
## far in from the shell its uptake rises, and the share of the box's height where the
## uptakes' casing under the deck begins — under three quarters, where art-lint looks
## for the box's faces on its footprint.
const SHELL := 4.8
const BAND := 0.08
const UPTAKE_INSET := 0.6
const CASING := 0.7
## Furnace fronts on each end of a boiler, and the firing aisle before an end wider than
## this to hold them.
const FRONTS := 2
const AISLE_LEAST := 1.0
## The coal face on the bunker's: a panel of coal, its least and its most proud of the
## wall, how high it is heaped, and the bunker door's frame — its breadth and how far
## proud.
const LUMP := Vector2(0.55, 0.4)
const LUMP_LEAST := 0.01
const LUMP_MOST := 0.05
const HEAP := 2.6
const FRAME := 0.08
const FRAME_PROUD := 0.06
## A shovel's handle and blade and a rake's length, hung flat on the bunker's face, and
## how far proud the rake's head stands.
const HANDLE := 1.1
const BLADE := Vector2(0.26, 0.32)
const RAKE := 1.8
const TOOL_PROUD := 0.05
## How far from a wall's face a door's centre may stand and be a door through it: the
## door stands in the wall's middle, half its thickness back from its face (0.1 m on
## her), so a tolerance of exactly that loses a door to rounding.
const DOOR_IN_WALL := 0.25
const COAL := Color("161618")
const COAL_LIGHT := Color("26262a")

static var _coal := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, COAL)
static var _coal_light := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, COAL_LIGHT)

var _engine: EngineRoom
var _space: ShipSpace


func _init(engine: EngineRoom) -> void:
	_engine = engine
	_space = engine.space()


## [param room]'s furnishings, into [param mesh]; [param _glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, _glass: Array[Array]) -> void:
	var machines := _space.machinery(room)
	if machines.is_empty():
		_engine.build(mesh, room)
		return
	for box: ShipBlocker in machines:
		_boiler(mesh, box)
		for front: Array in _fronts(room, box, machines):
			EngineRoom.front(mesh, front[2], front[0], front[1])
	_engine.walls(mesh, room)
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.side == 1 and wall.length() >= 1.0:
			_coal_face(mesh, wall)


## The lights [param room] is lit by: pendants over its firing aisles
## (EngineRoom.pendants()) and a fire in the mouth of each furnace front; an engine
## room's when it has no machinery.
func lights(room: ShipRoom) -> Array[RoomDressing.Light]:
	var machines := _space.machinery(room)
	if machines.is_empty():
		return _engine.lights(room)
	var found := _engine.pendants(room)
	for box: ShipBlocker in machines:
		for front: Array in _fronts(room, box, machines):
			var foot: Vector3 = front[0]
			var fire := foot + Vector3.UP * EngineRoom.FURNACE_HEIGHT
			found.append(RoomDressing.Light.new(fire, ShipLamp.Kind.FIRE, front[1]))
	return found


## What a boiler room lines its walls, floor, ceiling and beams with
## (RoomDressing.Part): an engine room's riveted steel over checker plate.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = [ShipPaints.bulkhead, ShipPaints.checker_plate]
	paints.append_array([ShipPaints.steel_overhead, ShipPaints.steel_beam])
	return paints


## A boiler filling [param box]'s footprint: its shell from the plates up to SHELL, a
## bright band round its top, its uptake rising from it UPTAKE_INSET in, and the
## uptakes' casing from CASING of the box's height to its top, under the deck.
func _boiler(mesh: ShipMesh, box: ShipBlocker) -> void:
	var area := box.area
	var top := box.top - (ShipArt.PLANK if _space.deck_on(box) else 0.0)
	var shell := minf(top, box.bottom + SHELL)
	var casing := maxf(shell, lerpf(box.bottom, top, CASING))
	RoomDressing.block(mesh, area, box.bottom, shell, ShipPaints.engine, ShipMesh.RIM_ALL)
	var band := area.grow(0.015)
	var low := shell - BAND * 3.0
	RoomDressing.block(mesh, band, low, low + BAND, ShipPaints.bright_steel)
	if casing > shell:
		var uptake := area.grow(-UPTAKE_INSET)
		RoomDressing.block(mesh, uptake, shell, casing, ShipPaints.steel, ShipMesh.RIM_ALL)
	if top > casing:
		RoomDressing.block(mesh, area, casing, top, ShipPaints.steel, ShipMesh.RIM_ALL)
		RoomDressing.block(mesh, band, casing, casing + BAND, ShipPaints.bright_steel)


## The furnace fronts on [param box]'s fore and after ends, each [its foot on the plates
## at the end's face, the way out of it, its radius]: FRONTS side by side across an end
## with a firing aisle wider than AISLE_LEAST before it, clear to [param room]'s wall
## or the next of [param machines]; the largest front each has the breadth and the
## shell's height for (EngineRoom.front_for()).
func _fronts(room: ShipRoom, box: ShipBlocker, machines: Array[ShipBlocker]) -> Array[Array]:
	var found: Array[Array] = []
	var area := box.area
	var top := box.top - (ShipArt.PLANK if _space.deck_on(box) else 0.0)
	var shell := minf(top, box.bottom + SHELL) - box.bottom
	var breadth := area.size.y / FRONTS
	var radius := EngineRoom.front_for(minf(breadth - 0.2, shell - 0.3) * 0.5)
	if is_nan(radius):
		return found
	for way: float in [1.0, -1.0]:
		var face := area.end.x if way > 0.0 else area.position.x
		var aisle := room.area.end.x - face if way > 0.0 else face - room.area.position.x
		for other: ShipBlocker in machines:
			var beside := other.area.end.y <= area.position.y or other.area.position.y >= area.end.y
			if other == box or beside:
				continue
			var gap := other.area.position.x - face if way > 0.0 else face - other.area.end.x
			if gap >= 0.0:
				aisle = minf(aisle, gap)
		if aisle <= AISLE_LEAST:
			continue
		for index in FRONTS:
			var z := area.position.y + breadth * (index + 0.5)
			found.append([Vector3(face, box.bottom, z), Vector3(way, 0.0, 0.0), radius])
	return found


## The coal face on [param wall], the cross bunker's: panels of coal heaped up to HEAP,
## each a little proud of the next, round the frame of each door through it, and a
## shovel and a rake hung flat beside them — none more than LUMP_MOST proud but the
## door's frame and the rake's head, FRAME_PROUD and TOOL_PROUD.
func _coal_face(mesh: ShipMesh, wall: RoomDressing.Wall) -> void:
	var doors := _doors(wall)
	var columns := maxi(1, floori(wall.length() / LUMP.x))
	var rows := maxi(1, floori(HEAP / LUMP.y))
	var size := Vector2(wall.length() / columns, HEAP / rows)
	var half := size * 0.5 - Vector2.ONE * 0.01
	for column in columns:
		for row in rows:
			var along := wall.from + size.x * (column + 0.5)
			var up := size.y * (row + 0.5)
			if _in_a_door(doors, along, up, size * 0.5 + Vector2.ONE * FRAME):
				continue
			# Coal heaped proudest low down, each lump by turns proud or sunk.
			var heap := 1.0 - float(row) / rows
			var turn := float(posmod(column * 7 + row * 3, 5)) / 4.0
			var share := clampf(heap * 0.6 + turn * 0.4, 0.0, 1.0)
			var proud := lerpf(LUMP_LEAST, LUMP_MOST, share)
			var paint := _coal_light if (column + row) % 3 == 0 else _coal
			var centre := wall.at(along, up, proud)
			RoomDressing.panel(mesh, centre, wall.right, half, wall.normal, paint, 0)
	for door: Rect2 in doors:
		_door_frame(mesh, wall, door)
	var tools := wall.from + 0.6
	if not doors.is_empty():
		var past := doors[0].end.x + FRAME + 0.4
		tools = past if past + 0.6 < wall.to else doors[0].position.x - FRAME - 0.9
	_shovel(mesh, wall, tools)
	_rake(mesh, wall, tools + 0.45)


## Each door through [param wall] (ShipOpening), as the stretch along it and up from its
## floor it fills.
func _doors(wall: RoomDressing.Wall) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var structure := _space.layout.structure
	if structure == null:
		return found
	var middle := wall.at(wall.middle(), 0.0)
	for opening: ShipOpening in structure.openings:
		if opening.kind not in [ShipOpening.Kind.DOOR, ShipOpening.Kind.WATERTIGHT_DOOR]:
			continue
		var centre := opening.centre
		if absf((centre - middle).dot(wall.normal)) > DOOR_IN_WALL:
			continue
		var along := centre.dot(wall.right)
		var half := absf(Vector2(opening.size.x, opening.size.z).dot(Vector2.ONE)) * 0.5
		if along + half < wall.from or along - half > wall.to:
			continue
		var low := centre.y - opening.size.y * 0.5 - wall.floor
		if low < -0.1 or low > HEAP:
			continue
		found.append(Rect2(along - half, low, half * 2.0, opening.size.y))
	return found


## Whether a lump [param half] its size each way at [param along] [param up] reaches
## into any of [param doors].
static func _in_a_door(doors: Array[Rect2], along: float, up: float, half: Vector2) -> bool:
	for door: Rect2 in doors:
		if door.intersects(Rect2(Vector2(along, up) - half, half * 2.0)):
			return true
	return false


## The bunker door [param door] on [param wall]: a steel frame round it FRAME broad,
## its door shut in it under two hinges and a dog.
func _door_frame(mesh: ShipMesh, wall: RoomDressing.Wall, door: Rect2) -> void:
	var middle := door.get_center()
	var leaf := wall.at(middle.x, middle.y, 0.02)
	RoomDressing.panel(mesh, leaf, wall.right, door.size * 0.5, wall.normal, ShipPaints.boiler)
	var reach := door.size * 0.5 + Vector2.ONE * FRAME * 0.5
	var corners: Array[Vector2] = [
		Vector2(-reach.x, -reach.y),
		Vector2(reach.x, -reach.y),
		Vector2(reach.x, reach.y),
		Vector2(-reach.x, reach.y),
	]
	for index in corners.size():
		var a := middle + corners[index]
		var b := middle + corners[(index + 1) % corners.size()]
		var from := wall.at(a.x, a.y, FRAME_PROUD * 0.5)
		var to := wall.at(b.x, b.y, FRAME_PROUD * 0.5)
		mesh.beam(from, to, Vector2(FRAME, FRAME_PROUD), ShipPaints.steel, 0)
	var place := Basis(wall.right, Vector3.UP, wall.normal)
	for side: float in [-1.0, 1.0]:
		var hinge := wall.at(door.position.x + 0.06, middle.y + side * door.size.y * 0.3, 0.04)
		mesh.turned_box(
			Transform3D(place, hinge), Vector3(0.1, 0.08, 0.04), ShipPaints.bright_steel, 0
		)
	var dog := wall.at(door.end.x - 0.1, middle.y, 0.05)
	var lever := Vector3.UP * 0.1
	mesh.beam(dog - lever, dog + lever, Vector2(0.03, 0.03), ShipPaints.brass, 0)


## A coal shovel hung flat on [param wall] at [param along], its blade down.
func _shovel(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var foot := 0.25
	var blade := wall.at(along, foot + BLADE.y * 0.5, 0.015)
	RoomDressing.panel(mesh, blade, wall.right, BLADE * 0.5, wall.normal, ShipPaints.bright_steel)
	var from := wall.at(along, foot + BLADE.y, 0.02)
	var grip := wall.at(along, foot + BLADE.y + HANDLE, 0.02)
	mesh.beam(from, grip, Vector2(0.035, 0.035), ShipPaints.teak, 0)
	var across := wall.right * 0.08
	mesh.beam(grip - across, grip + across, Vector2(0.03, 0.03), ShipPaints.teak, 0)


## A fire rake hung flat on [param wall] at [param along], its head up.
func _rake(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var from := wall.at(along, 0.15, 0.02)
	var to := wall.at(along, 0.15 + RAKE, 0.02)
	mesh.beam(from, to, Vector2(0.03, 0.03), ShipPaints.steel, 0)
	var head := wall.at(along, 0.15 + RAKE, TOOL_PROUD * 0.5)
	var half := wall.right * 0.17
	mesh.beam(head - half, head + half, Vector2(0.05, TOOL_PROUD), ShipPaints.steel, 0)
