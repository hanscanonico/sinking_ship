class_name WalkPieces
extends RefCounted
## The pieces a room's floor falls into for a body (§7, #501, #505): a room is one zone of
## the walk graph only while a body could walk its floor from any of its ways — doorways and
## the ends of flights in it — to any other. Three flights side by side across a passage,
## a boiler block across a stokehold, an oil tank across a passage: each cuts its room in
## two, and a route through the room from one side to the other walks a bot into it for good.
## So a room's floor is read over BotFloorWay's squares, each one a body BotFloorWay.SNUG of
## its radius round could stand on — the squares a bot's way round by the floor is found
## over — and the squares that touch, eight ways and never across a corner, are its pieces.
## Each piece one of its ways lands in is a zone of its own: the room's own index for the
## piece its first way lands in, one after the rooms (first_zone on) for each other. A piece
## no way lands in is left the room's, as a body standing in it was before.
## A room read split over squares of CELL is read again over squares of FINE: a doorway's
## clear width has room for a body's middle that the coarse squares' middles can miss.
## Asked of Surfaces once, as the graph is built, before any crate or railing moves.

## The side of a square a room's floor is first read over: BotFloorWay's.
const CELL := BotFloorWay.CELL
## The side of a square a room the first read splits is read over again.
const FINE := BotFloorWay.CELL * 0.5
## How far from a point its piece is looked for, when no body could stand at it: a body
## against a wall stands nearer it than a square's middle a body could stand on.
const REACH := 0.75
## What a square a body stands on stands on (_stands): a floor, or a stair's end.
const ON_FLOOR := 1
const ON_STAIR := 2

var _layout: ShipLayout
var _surfaces: Surfaces
var _rules: BrawlRules
var _radius: float
var _lead: float
## The first zone after the rooms: the pieces' zones are numbered from it.
var _first := 0
## Per piece zone, from _first on, the room it is a piece of.
var _rooms := PackedInt32Array()
## Per room split, its grid: the room, the side of its squares, its origin and width and
## height in squares, and per square its zone or NONE; read through _grid_of.
var _grid_of := {}


## The pieces of every room of [param layout] whose ways land in more than one.
func _init(layout: ShipLayout, surfaces: Surfaces, rules: BrawlRules) -> void:
	_layout = layout
	_surfaces = surfaces
	_rules = rules
	_radius = rules.body_radius * BotFloorWay.SNUG
	_lead = rules.body_radius * 2.0
	_first = layout.rooms.size()
	var ends := _flight_ends()
	for room in layout.rooms.size():
		var ways := _ways(room, ends)
		if ways.size() < 2:
			continue
		var coarse := _read(room, CELL)
		if _landings(coarse, ways).size() < 2:
			continue
		var fine := _read(room, FINE)
		var landed := _landings(fine, ways)
		if landed.size() < 2:
			continue
		# The piece of the first way keeps the room; each other piece a way lands in is a
		# zone of its own, in the order its first way comes; the rest are the room's.
		var zone_of := {}
		for piece: int in landed:
			if zone_of.is_empty():
				zone_of[piece] = room
			else:
				zone_of[piece] = _first + _rooms.size()
				_rooms.append(room)
		var squares: PackedInt32Array = fine["pieces"]
		for index in squares.size():
			squares[index] = zone_of.get(squares[index], room) if squares[index] >= 0 else -1
		fine["pieces"] = squares
		_grid_of[room] = fine


## How many zones the pieces add after the rooms.
func extra() -> int:
	return _rooms.size()


## The room [param zone] is a piece of: itself for a room's own index.
func room_of(zone: int) -> int:
	if zone < _first:
		return zone
	return _rooms[zone - _first]


## The zone of the piece of [param room] a body at [param point] (x/z) stands in: the
## room's own where it is not split, or no square near the point is one a body stands on.
func zone(room: int, point: Vector2) -> int:
	if not _grid_of.has(room):
		return room
	var piece := _piece_at(_grid_of[room], point)
	return room if piece < 0 else piece


## The zone of the piece of [param room] a body walking in from [param from] (x/z), on its
## edge, the way [param inward] first stands in (_walked_in): the room's own where it is not
## split; -1 where it is and the body stands in none.
func zone_in(room: int, from: Vector2, inward: Vector2) -> int:
	if not _grid_of.has(room):
		return room
	return _walked_in(_grid_of[room], from, inward)


## Puts back into its room's own zone each piece of a split room that no route from
## [param start] (her main deck's zone) reaches along [param portals] (of
## [param zone_count] zones): a sealed pocket, held as part of its room as it was before
## the room was read in pieces — with a piece a route does reach, where the room's own is
## one no route reaches. A pocket a body cannot walk out of is the layout's to open
## (test_no_sealed_room), and until it is, a route through the room to it is the one it
## had. Each portal and ramp end ([param ramp_zones]) at a piece put back is moved to the
## room's own zone, and the piece's zone is left with none. True when any piece was.
func glue(portals: Array, ramp_zones: Array[PackedInt32Array], start: int, zone_count: int) -> bool:
	var glued := false
	while true:
		var reached := _reached(portals, start, zone_count)
		# Per piece put back, the room it goes back into.
		var back := {}
		# Per room still split, the pieces of it still apart from its own zone.
		var whole := {}
		for room: int in _grid_of:
			var apart := {}
			for zone: int in _grid_of[room]["pieces"]:
				if zone >= _first:
					apart[zone] = true
			whole[room] = apart.keys()
		for room: int in whole:
			var pieces: Array = whole[room]
			var kept := 0
			for zone: int in pieces:
				if reached[zone] == 0:
					back[zone] = room
				elif reached[room] == 0 and kept == 0:
					back[zone] = room
					kept += 1
		if back.is_empty():
			return glued
		glued = true
		for portal: WalkGraph.Portal in portals:
			portal.from_zone = back.get(portal.from_zone, portal.from_zone)
			portal.to_zone = back.get(portal.to_zone, portal.to_zone)
		for ramp in ramp_zones.size():
			var zones := ramp_zones[ramp]
			for end in zones.size():
				zones[end] = back.get(zones[end], zones[end])
			ramp_zones[ramp] = zones
		for room: int in whole:
			var grid: Dictionary = _grid_of[room]
			var squares: PackedInt32Array = grid["pieces"]
			var split := false
			for index in squares.size():
				squares[index] = back.get(squares[index], squares[index])
				split = split or squares[index] >= _first
			grid["pieces"] = squares
			if not split:
				_grid_of.erase(room)
	return glued


## Per zone of [param zone_count], 1 where a route from [param start] along
## [param portals] reaches it.
static func _reached(portals: Array, start: int, zone_count: int) -> PackedByteArray:
	var out: Array[PackedInt32Array] = []
	out.resize(zone_count)
	for portal: WalkGraph.Portal in portals:
		out[portal.from_zone].append(portal.to_zone)
	var reached := PackedByteArray()
	reached.resize(zone_count)
	reached[start] = 1
	var open := PackedInt32Array([start])
	while not open.is_empty():
		var zone := open[open.size() - 1]
		open.resize(open.size() - 1)
		for next: int in out[zone]:
			if reached[next] == 0:
				reached[next] = 1
				open.append(next)
	return reached


## The pieces of [param room] over squares [param side] across: the grid laid on the
## room's area, square for square on BotFloorWay's grid — from world multiples of the side —
## and per square its piece, or -1 where no body stands. A piece no square of which is on
## the room's floor, all of it on a stair, is none: a body standing on a stair is in the zone
## of the stair's end it is nearer (WalkGraph.zone_at), never in the room's (#561).
func _read(room: int, side: float) -> Dictionary:
	var area := _layout.rooms[room].area
	var height := _layout.rooms[room].floor_height
	var origin := (area.position / side).floor() * side
	var width := maxi(1, ceili((area.end.x - origin.x) / side))
	var depth := maxi(1, ceili((area.end.y - origin.y) / side))
	var pieces := PackedInt32Array()
	pieces.resize(width * depth)
	pieces.fill(-1)
	var stands := _stands_grid(origin, width, depth, side, height, area)
	var count := 0
	# Per piece, 1 where a square of it is on the room's floor.
	var floored := PackedByteArray()
	for first in width * depth:
		if stands[first] == 0 or pieces[first] >= 0:
			continue
		pieces[first] = count
		floored.append(0)
		var open := PackedInt32Array([first])
		while not open.is_empty():
			var at := open[open.size() - 1]
			open.resize(open.size() - 1)
			if stands[at] == ON_FLOOR:
				floored[count] = 1
			var x := at % width
			var z := at / width
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var nz := z + dz
					if dx == 0 and dz == 0 or nx < 0 or nz < 0 or nx >= width or nz >= depth:
						continue
					var next := nz * width + nx
					if stands[next] == 0 or pieces[next] >= 0:
						continue
					# Never across a corner: both squares it passes between stand too.
					if (
						dx != 0
						and dz != 0
						and (stands[z * width + nx] == 0 or stands[nz * width + x] == 0)
					):
						continue
					pieces[next] = count
					open.append(next)
		count += 1
	for index in pieces.size():
		if pieces[index] >= 0 and floored[pieces[index]] == 0:
			pieces[index] = -1
	return {"side": side, "origin": origin, "width": width, "depth": depth, "pieces": pieces}


## The pieces [param ways] land in over [param grid], each once, in the order of the first
## way to land in it: through a doorway, where a body walking in from its middle first stands
## (_walked_in); off a flight's end, the piece at the point a body's width on past it, or the
## nearest within REACH (_piece_at).
func _landings(grid: Dictionary, ways: Array[PackedVector2Array]) -> PackedInt32Array:
	var landed := PackedInt32Array()
	for way: PackedVector2Array in ways:
		var piece := -1
		if way[1].is_zero_approx():
			piece = _piece_at(grid, way[0])
		else:
			piece = _walked_in(grid, way[0], way[1])
		if piece >= 0 and not piece in landed:
			landed.append(piece)
	return landed


## The piece of [param grid] a body walking in from [param from] the way [param inward]
## first stands in, read every half a square along its middle as far as a body's width in;
## -1 where it stands in none. Not the nearest piece to a point a body's width in, which can
## lie past a wall (#561: in the Titanic's grand staircase on C deck a partition stands 0.72 m
## in from its doorway aft, and a body's width in is past it).
func _walked_in(grid: Dictionary, from: Vector2, inward: Vector2) -> int:
	var side: float = grid["side"]
	var origin: Vector2 = grid["origin"]
	var width: int = grid["width"]
	var depth: int = grid["depth"]
	var pieces: PackedInt32Array = grid["pieces"]
	var step := side * 0.5
	var along := step * 0.5
	while along <= _lead:
		var at := ((from + inward * along - origin) / side).floor()
		var x := int(at.x)
		var z := int(at.y)
		if x >= 0 and z >= 0 and x < width and z < depth and pieces[z * width + x] >= 0:
			return pieces[z * width + x]
		along += step
	return -1


## The piece of [param grid] at [param point], or the nearest one within REACH of it; -1
## where none is.
func _piece_at(grid: Dictionary, point: Vector2) -> int:
	var side: float = grid["side"]
	var origin: Vector2 = grid["origin"]
	var width: int = grid["width"]
	var depth: int = grid["depth"]
	var pieces: PackedInt32Array = grid["pieces"]
	var at := ((point - origin) / side).floor()
	var reach := ceili(REACH / side)
	var best := -1
	var best_distance := INF
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := int(at.x) + dx
			var z := int(at.y) + dz
			if x < 0 or z < 0 or x >= width or z >= depth or pieces[z * width + x] < 0:
				continue
			var middle := origin + (Vector2(x, z) + Vector2(0.5, 0.5)) * side
			var distance := middle.distance_squared_to(point)
			if distance < best_distance and distance <= REACH * REACH:
				best = pieces[z * width + x]
				best_distance = distance
	return best


## The ways into [param room], each a point and the way in from it: the middle of each
## doorway a body fits, in through it; and a body's width on past each end of a flight that
## lands on its floor in it ([param ends]), with none (Vector2.ZERO).
func _ways(room: int, ends: Array) -> Array[PackedVector2Array]:
	var ways: Array[PackedVector2Array] = []
	var data := _layout.rooms[room]
	for door: ShipRoom.Door in data.doors(_surfaces, _rules.crawl_height, _rules.step_height):
		if door.width() >= _rules.body_radius * 2.0:
			ways.append(PackedVector2Array([door.middle(), -door.outward]))
	for end: Vector3 in ends:
		var flat := Vector2(end.x, end.z)
		if absf(end.y - data.floor_height) <= _rules.step_height and data.area.has_point(flat):
			ways.append(PackedVector2Array([flat, Vector2.ZERO]))
	return ways


## Where a body stands stepping off each end of each flight, a body's width on past it.
func _flight_ends() -> Array:
	var ends := []
	for ramp: ShipRamp in _layout.ramps:
		for end in 2:
			var at := ramp.end_point(end)
			var other := ramp.end_point(1 - end)
			var out := Vector2(at.x - other.x, at.z - other.z).normalized() * _lead
			ends.append(Vector3(at.x + out.x, at.y, at.z + out.y))
	return ends


## Per square of the grid from [param origin], [param width] squares wide and [param depth]
## deep, each [param side] across, where its middle lies in [param within] and a body could
## stand with its feet there at [param height], what it stands on (_stands), else 0: in the
## game's extension where it is loaded (NativeSurfaces.stands_grid), square for square.
func _stands_grid(
	origin: Vector2, width: int, depth: int, side: float, height: float, within: Rect2
) -> PackedByteArray:
	var mirror := _surfaces.native
	if mirror != null:
		var rules := PackedFloat64Array(
			[
				_radius,
				_rules.step_height,
				_rules.body_height,
				_rules.crawl_height,
				_rules.railing_height
			]
		)
		return mirror.stands_grid(origin, width, depth, side, height, within, rules)
	var stands := PackedByteArray()
	stands.resize(width * depth)
	for index in width * depth:
		var middle := origin + (Vector2(index % width, index / width) + Vector2(0.5, 0.5)) * side
		if within.has_point(middle):
			stands[index] = _stands(Vector3(middle.x, height, middle.y))
	return stands


## What a body with its feet at [param point] would stand on: ON_FLOOR on a floor within a
## step of its height, ON_STAIR on a stair's end there, which a body walks across; 0 where
## it stands on neither, or something holds it back (BotFloorWay._stands): every obstacle and
## every railing the sim holds it by — on a stair, the floor's railings along its sides by
## its head (Surfaces.rail_contacts, #552, #561).
func _stands(point: Vector3) -> int:
	var surface := _surfaces.under(point, _rules.step_height)
	if surface == Surfaces.NONE:
		return 0
	var feet := Vector3(point.x, _surfaces.height_at(surface, point), point.z)
	var held := _surfaces.obstacle_contacts(
		feet, _radius, _rules.body_height, _rules.step_height, Surfaces.NONE, _rules.crawl_height
	)
	if not held.is_empty():
		return 0
	var railed := _surfaces.rail_contacts(
		feet, _radius, surface, _rules.step_height, _rules.railing_height
	)
	if not railed.is_empty():
		return 0
	return ON_STAIR if _surfaces.is_ramp(surface) else ON_FLOOR
