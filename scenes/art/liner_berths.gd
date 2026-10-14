class_name LinerBerths
extends RefCounted
## A liner's berths (RoomDressing.Kind.BERTHS): third class's berths, the officers'
## and the crew's quarters. Along every stretch of wall long enough, berths slung
## overhead one after another (spots()), each blanket in the next of the cabins'
## colours, and under every third a washstand and a locker flat on the wall; curtains
## drawn back from each porthole; the walls lined in pine for third class, teak under
## white for the officers, plain enamel for the crew. No berth hangs across a doorway
## or over a stair.
## Between a step over the floor and a body's height, nothing it draws stands more
## than FurnishingCheck.TOLERANCE (0.12 m) out from a wall — the berths hang over
## HEADROOM (1.85 m), where they fade near the eye, and the washstands, lockers and
## linings stand flat on the walls. The rooms have no blockers inside them, so there
## is no mid-room furniture: art-lint holds it to that, and no blocker is ever widened
## to hide a piece (D6).

## Berths one after another along a wall, BERTH.x long and PITCH apart, on a stretch of
## wall at least SHORTEST long once it keeps CORNER clear of a corner, where the next
## wall's berths hang, and DOORWAY clear of a doorway's frame. Every FITTED-th berth
## has a washstand and a locker under it.
const PITCH := RoomDressing.BERTH.x + 0.3
const SHORTEST := RoomDressing.BERTH.x + 0.1
const CORNER := RoomDressing.BERTH.y + 0.05
const DOORWAY := 0.15
const FITTED := 3
## How far a berth's board stands under its deckhead at least, for its chains.
const SLUNG := 0.5
## How far out from its wall a lining stands, and how high the officers' teak goes.
const LINING_OUT := 0.01
const DADO := 1.0
## Third class's pine lining.
const PINE := Color("c8a46c")

static var pine := ShipMesh.Paint.new(ShipMesh.Finish.CABIN, PINE)
static var teak_lining := ShipMesh.Paint.new(ShipMesh.Finish.CABIN, ArtPalette.TEAK)
static var white_lining := ShipMesh.Paint.new(ShipMesh.Finish.CABIN, ArtPalette.ENAMEL)
static var enamel_lining := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.ENAMEL)


## Where a berth hangs: along [param wall] from [param from] to BERTH.x past it.
class Spot:
	var wall: RoomDressing.Wall
	var from: float

	func _init(on: RoomDressing.Wall, start: float) -> void:
		wall = on
		from = start

	func middle() -> float:
		return from + RoomDressing.BERTH.x * 0.5


var _space: ShipSpace
## How many berths, and how many rooms of them, build() has dressed so far: the next
## one's blanket and the next room's curtains.
var _berths := 0
var _rooms := 0


## [param _cabin] is RoomDressing's lower-deck cabin, which a block of berths no
## longer takes.
func _init(space: ShipSpace, _cabin: Callable) -> void:
	_space = space


## [param room]'s furnishings, into [param mesh]; [param glass] its panes
## (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var curtains := ArtPalette.CABIN_CURTAINS
	var curtain := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, curtains[_rooms % curtains.size()])
	_rooms += 1
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		_line(mesh, wall, glass)
	var blankets := ArtPalette.CABIN_BLANKETS
	var number := 0
	for spot: Spot in spots(_space, room):
		var colour := blankets[_berths % blankets.size()]
		var blanket := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, colour)
		RoomDressing.slung_berth(mesh, _space, spot.wall, spot.from, 1.0, blanket)
		if number % FITTED == 0 and not _by_glass(spot, glass):
			CabinDressing.washstand(mesh, spot.wall, spot.middle() - 0.45)
			CabinDressing.locker(mesh, spot.wall, spot.middle() + 0.55)
		number += 1
		_berths += 1
	for pane: Array in glass:
		if pane[3]:
			CabinDressing.curtains(mesh, pane[1], pane[2], curtain)


## The lights [param room] is lit by; none keeps RoomDressing's pendants.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a block of berths lines its walls, floor, ceiling and beams with
## (RoomDressing.Part): the ship's own, since each block lines its walls its own way
## by its name (build()), which a lining by Kind cannot tell.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	return paints


## Where [param room] of [param space] hangs its berths: PITCH apart along each stretch
## of its walls long enough, in order round the room, none over a stair coming up or
## going down nor too near its deckhead to hang.
static func spots(space: ShipSpace, room: ShipRoom) -> Array[Spot]:
	var found: Array[Spot] = []
	var berth := RoomDressing.BERTH
	var floor := room.floor_height
	for wall: RoomDressing.Wall in RoomDressing.walls(space, room):
		var along_x := wall.side % 2 == 0
		var low := room.area.position.x if along_x else room.area.position.y
		var high := room.area.end.x if along_x else room.area.end.y
		var from := wall.from + (CORNER if wall.from - low < 0.2 else DOORWAY)
		var to := wall.to - (CORNER if high - wall.to < 0.2 else DOORWAY)
		if to - from < SHORTEST:
			continue
		var count := floori((to - from - SHORTEST) / PITCH) + 1
		var start := from + (to - from - (count - 1) * PITCH - berth.x) * 0.5
		for index in count:
			var a := start + index * PITCH
			var area := wall.rect(a, a + berth.x, 0.0, berth.y)
			if RoomDressing.over_a_ramp(space.layout, area, floor - 0.5, floor + 2.4):
				continue
			var hook := wall.at(a + berth.x * 0.5, 0.0, berth.y * 0.5)
			var ceiling := space.ceiling(room, hook.x, hook.z) - ShipArt.PLANK
			if ceiling < floor + RoomDressing.HEADROOM + SLUNG:
				continue
			found.append(Spot.new(wall, a))
	return found


## Whether any of [param glass] stands in the wall under [param spot]'s berth, where
## its washstand and locker would stand over it.
func _by_glass(spot: Spot, glass: Array[Array]) -> bool:
	for pane: Array in glass:
		var span := _pane_on(spot.wall, pane)
		if span != Rect2() and span.position.x < spot.from + 2.0 and span.end.x > spot.from - 0.1:
			return true
	return false


## Where [param pane] stands in [param wall], as (along, height over the floor), a
## little grown; empty when it is in another wall.
func _pane_on(wall: RoomDressing.Wall, pane: Array) -> Rect2:
	var centre: Vector3 = pane[1]
	var normal: Vector3 = pane[2]
	var half: Vector2 = pane[4]
	var along := centre.x if wall.side % 2 == 0 else centre.z
	var face := wall.at(along, 0.0)
	if normal.dot(wall.normal) < 0.7 or absf((centre - face).dot(wall.normal)) > 0.3:
		return Rect2()
	var middle := Vector2(along, centre.y - wall.floor)
	return Rect2(middle - half, half * 2.0).grow(0.04)


## [param wall]'s lining, flat on it from its floor to its deckhead, round each of
## [param glass] in it.
func _line(mesh: ShipMesh, wall: RoomDressing.Wall, glass: Array[Array]) -> void:
	var top := INF
	for along: float in [wall.from, wall.middle(), wall.to]:
		var point := wall.at(along, 0.0)
		top = minf(top, _space.ceiling(wall.room, point.x, point.z) - ShipArt.PLANK)
	top -= wall.floor
	var holes: Array[Rect2] = []
	var cuts := PackedFloat32Array([wall.from, wall.to])
	for pane: Array in glass:
		var hole := _pane_on(wall, pane)
		if hole == Rect2():
			continue
		holes.append(hole)
		cuts.append_array([clampf(hole.position.x, wall.from, wall.to)])
		cuts.append_array([clampf(hole.end.x, wall.from, wall.to)])
	cuts.sort()
	for index in cuts.size() - 1:
		var a := cuts[index]
		var b := cuts[index + 1]
		if b - a < ShipMesh.SLIVER:
			continue
		var bands := PackedFloat32Array([0.0])
		for hole: Rect2 in holes:
			if hole.position.x < (a + b) * 0.5 and hole.end.x > (a + b) * 0.5:
				bands.append_array(
					[clampf(hole.position.y, 0.0, top), clampf(hole.end.y, 0.0, top)]
				)
		bands.append(top)
		bands.sort()
		for band in range(0, bands.size() - 1, 2):
			var span := Rect2(a, bands[band], b - a, bands[band + 1] - bands[band])
			_lining(mesh, wall, span, top)


## The lining of [param wall] over [param span] (along it, over its floor), under its
## deckhead [param top] over the floor: pine in third class's berths, teak to DADO under
## white in the officers' quarters, enamel in the crew's.
func _lining(mesh: ShipMesh, wall: RoomDressing.Wall, span: Rect2, top: float) -> void:
	var name := String(wall.room.name).to_lower()
	var parts: Array[Array] = []
	if name.contains("officers"):
		var dado := clampf(DADO, span.position.y, span.end.y)
		parts.append([span.position.y, dado, teak_lining])
		parts.append([dado, span.end.y, white_lining])
	elif name.contains("third"):
		parts.append([span.position.y, span.end.y, pine])
	else:
		parts.append([span.position.y, span.end.y, enamel_lining])
	for part: Array in parts:
		var bottom: float = part[0]
		var high: float = part[1]
		if high - bottom < ShipMesh.SLIVER:
			continue
		var origin := wall.at(span.position.x, bottom, LINING_OUT)
		var u := wall.right * span.size.x
		var v := Vector3.UP * (high - bottom)
		var head := wall.floor + top
		if u.cross(v).dot(wall.normal) > 0.0:
			mesh.face(origin, u, v, part[2], 0, wall.floor, head)
		else:
			mesh.face(origin, v, u, part[2], 0, wall.floor, head)
