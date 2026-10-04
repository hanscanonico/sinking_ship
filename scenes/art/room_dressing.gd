class_name RoomDressing
extends RefCounted
## What makes each room of a ship its own (ShipArt), placed by rules on the layout,
## never by hand: the kind of room its shape says it is — the one answer, which
## ShipFittings asks too — the lining its walls, floor and ceiling take, the lamps it
## is lit by, and its fittings. An engine room of riveted steel over checker plate,
## its engine filling the block the rules hold bodies out of, boilers in its forward
## bulkhead with their fires glowing and their steam pipes overhead; a hold of rough
## timber, framed up its hull sides, its cargo stowed on a tween deck overhead under
## a net, lit by shaded cargo lamps; lower-deck cabins, each a little different, with
## a berth slung overhead, a washstand, a locker and curtains at the portholes; a
## corridor with handrails, a lifebelt and fire buckets; a wheelhouse panelled in
## teak with its wheel, binnacle, telegraph and chart against its walls; and over
## every doorway out of a corridor, an engine room or a hold, a plate naming the room
## beyond as the HUD does. Between a step over the floor and a body's height, where a
## body walks, nothing it draws stands out from a wall further than a fitting's depth
## — the rest stands in a blocker's footprint or over HEADROOM — and art-lint holds it
## to that.

## What a room is, by its shape and where it stands.
enum Kind { PASSAGE, CUDDY, ENGINE, HOLD, STEERAGE, HELM, SALOON, CABIN }
## What of a room a face is: its walls, its floor, its ceiling, its beams.
enum Part { WALL, FLOOR, OVERHEAD, BEAM }

## A room narrower than CORRIDOR is a passage when it opens onto two rooms or more,
## else a cuddy too narrow for furniture; one below the main deck this big is a hold,
## a smaller one a cabin; one above it this big is a saloon, a smaller one a cabin,
## and the highest room, if small, the helm.
const CORRIDOR := 1.8
const HOLD_AREA := 40.0
const SALOON_AREA := 15.0
## How high over its floor anything standing out from a wall begins: nobody's head
## goes there but in a jump.
const HEADROOM := 1.85
const PIPE_SIDES := 8
## A berth slung overhead: its length and its depth out from its wall.
const BERTH := Vector2(1.9, 0.7)
## The longest piece a furnishing's box is drawn in.
const PIECE := 1.5
## A sign over a doorway: its letters' size in pixels and the metres one stands for,
## and how high its plate stands over the floor.
const SIGN_FONT := 40
const SIGN_PIXEL := 0.0028
const SIGN_HEIGHT := 2.24


## A light a room is lit by (ShipLamp): where it hangs from its ceiling or burns in a
## wall, ship space, what it is, and which way a fire faces out of its wall.
class Light:
	var at: Vector3
	var kind: ShipLamp.Kind
	var facing: Vector3

	func _init(point: Vector3, lamp: ShipLamp.Kind, out := Vector3.DOWN) -> void:
		at = point
		kind = lamp
		facing = out


## One full wall along a side of a room, seen from inside it (ShipSpace.wall_runs):
## where a point along it, over the floor and out from its face stands.
class Wall:
	var room: ShipRoom
	var side: int
	## Along the side, the way it counts, from and to.
	var from: float
	var to: float
	var floor: float
	## Into the room, and along the wall the way it counts.
	var normal: Vector3
	var right: Vector3
	var _space: ShipSpace
	var _half: float

	func _init(space: ShipSpace, of: ShipRoom, run: Array) -> void:
		_space = space
		room = of
		side = run[0]
		from = run[1]
		to = run[2]
		_half = run[3]
		floor = of.floor_height
		var out := ShipSpace.outward(side)
		normal = Vector3(-out.x, 0.0, -out.y)
		right = Vector3.RIGHT if side % 2 == 0 else Vector3.BACK

	func middle() -> float:
		return (from + to) * 0.5

	func length() -> float:
		return to - from

	## Ship point [param along] it, [param height] over the floor, [param out] from
	## its face.
	func at(along: float, height: float, out := 0.0) -> Vector3:
		var point := _space.on_side(room, side, along, _half + out)
		return Vector3(point.x, floor + height, point.y)

	## The ship-plane rectangle [param a]…[param b] along it and [param near]…
	## [param far] out from its face.
	func rect(a: float, b: float, near: float, far: float) -> Rect2:
		var low := _space.on_side(room, side, a, _half + near)
		return Rect2(low, Vector2.ZERO).expand(_space.on_side(room, side, b, _half + far))

	## Turned to face into the room, at [param point].
	func place(point: Vector3) -> Transform3D:
		return Transform3D(Basis(right, Vector3.UP, normal), point)

	## Whether what stands beyond it, at a body's middle, is outdoors: the hull side.
	func outdoors_beyond() -> bool:
		var beyond := _space.on_side(room, side, middle(), -_half - ShipMesh.PROBE)
		return _space.outdoors(Vector3(beyond.x, floor + 1.0, beyond.y))

	## The end of it by side [param hull]: where along it the light of its portholes is.
	func end_by(hull: int) -> float:
		var low_side := 0 if side % 2 == 1 else 3
		return from if hull == low_side else to


var _space: ShipSpace
var _layout: ShipLayout
## Per room, its Kind.
var _kinds: Array[Kind] = []
## The rooms, by index, that have a lining of their own, and each one's box from its
## floor to its highest ceiling.
var _lined := PackedInt32Array()
var _lined_boxes: Array[AABB] = []
## The x and the z of every edge of a room that has a lining.
var _lines: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
var _cut_above: float
var _engine: EngineRoom
var _hold: CargoHold


## Reads [param space]'s rooms; no sign at or over [param cut_above], the observer's
## cut-away, is shown.
func _init(space: ShipSpace, cut_above := INF) -> void:
	_space = space
	_layout = space.layout
	_cut_above = cut_above
	_engine = EngineRoom.new(space)
	_hold = CargoHold.new(space)
	for room: ShipRoom in _layout.rooms:
		var kind := kind_of(space, room)
		_kinds.append(kind)
		if not _linings(kind).is_empty():
			_lined.append(_kinds.size() - 1)
			_lined_boxes.append(_box_of(space, room))
			_lines[0].append_array([room.area.position.x, room.area.end.x])
			_lines[1].append_array([room.area.position.y, room.area.end.y])


## [param room]'s box on [param space], from its floor to the highest of its ceiling
## over its corners and its middle.
static func _box_of(space: ShipSpace, room: ShipRoom) -> AABB:
	var area := room.area.grow(-ShipSpace.INSIDE)
	var head := room.floor_height
	var corners: Array[Vector2] = [
		area.position,
		area.end,
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.position.y)
	]
	corners.append(area.get_center())
	for at: Vector2 in corners:
		head = maxf(head, space.ceiling(room, at.x, at.y))
	var foot := Vector3(room.area.position.x, room.floor_height, room.area.position.y)
	return AABB(foot, Vector3(room.area.size.x, head - room.floor_height, room.area.size.y))


## What [param room] is, by its shape and where it stands on [param space].
static func kind_of(space: ShipSpace, room: ShipRoom) -> Kind:
	var size := room.area.size
	if space.machinery_in(room):
		return Kind.ENGINE
	if minf(size.x, size.y) < CORRIDOR:
		var doorways := 0
		var runs := space.wall_runs(room)
		for side in 4:
			for gap: Vector2 in _gaps(room, side, runs):
				doorways += 1 if _beyond(space, room, side, gap) != -1 else 0
		return Kind.PASSAGE if doorways >= 2 else Kind.CUDDY
	var top_floor := -INF
	for other: ShipRoom in space.layout.rooms:
		top_floor = maxf(top_floor, other.floor_height)
	var area := size.x * size.y
	if room.floor_height >= top_floor and area < SALOON_AREA:
		return Kind.HELM
	if room.floor_height < 0.0:
		return Kind.HOLD if area >= HOLD_AREA else Kind.STEERAGE
	return Kind.SALOON if area >= SALOON_AREA else Kind.CABIN


## The room of [param space], by index, ship point [param point] stands in; -1 for
## none.
static func room_at(space: ShipSpace, point: Vector3) -> int:
	for index in space.layout.rooms.size():
		if _holds(space, space.layout.rooms[index], point):
			return index
	return -1


## Whether ship point [param point] stands in [param room] of [param space]: over its
## floor, under its ceiling.
static func _holds(space: ShipSpace, room: ShipRoom, point: Vector3) -> bool:
	var area := room.area
	if point.x < area.position.x or point.x > area.end.x:
		return false
	if point.z < area.position.y or point.z > area.end.y:
		return false
	if point.y < room.floor_height - ShipSpace.INSIDE:
		return false
	return point.y <= space.ceiling(room, point.x, point.z) + ShipSpace.INSIDE


## The paint [param part] of the room ship point [param point] stands in takes, when
## that room has a lining of its own; null otherwise.
func lining(point: Vector3, part: Part) -> ShipMesh.Paint:
	for index: int in _lined:
		if _holds(_space, _layout.rooms[index], point):
			return _linings(_kinds[index])[part]
	return null


## Whether [param box] (ship space) reaches into a room with a lining of its own.
func lined_near(box: AABB) -> bool:
	for room: AABB in _lined_boxes:
		if room.intersects(box):
			return true
	return false


## Where a room with a lining begins or ends along [param axis] (0 x, 1 z): where a
## face is cut so each piece lies in one room's lining or none.
func lining_lines(axis: int) -> PackedFloat32Array:
	return _lines[axis]


## What [param kind] of room lines its walls, floor, ceiling and beams with, by Part
## (null keeps the ship's own); empty when it keeps the ship's own throughout.
static func _linings(kind: Kind) -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	match kind:
		Kind.ENGINE:
			paints.assign([ShipPaints.bulkhead, ShipPaints.checker_plate])
			paints.append_array([ShipPaints.steel_overhead, ShipPaints.steel_beam])
		Kind.HOLD:
			paints.assign([ShipPaints.hold_wall, ShipPaints.hold_floor])
			paints.append_array([ShipPaints.hold_overhead, null])
		Kind.HELM:
			paints.assign([ShipPaints.panelling, null, null, null])
	return paints


## The lights [param room] is lit by: a pendant under the middle of its ceiling, but
## in an engine room (EngineRoom) or a hold (CargoHold) their own.
func lights(room: ShipRoom) -> Array[Light]:
	var found: Array[Light] = []
	var area := room.area
	var middle := area.get_center()
	match _kinds[_layout.rooms.find(room)]:
		Kind.ENGINE:
			found = _engine.lights(room)
		Kind.HOLD:
			found = _hold.lights(room)
	if found.is_empty():
		found.append(Light.new(under_ceiling(_space, room, middle), ShipLamp.Kind.PENDANT))
	return found


## Every room's furnishings, into [param mesh]; its door signs' letters under
## [param signs]. [param panes] are ShipFittings' glass, each [room, centre, normal
## into the room, whether a porthole].
func build(mesh: ShipMesh, signs: Node3D, panes: Array[Array]) -> void:
	var cabin := 0
	for index in _layout.rooms.size():
		var room := _layout.rooms[index]
		var glass: Array[Array] = []
		for pane: Array in panes:
			if pane[0] == room:
				glass.append(pane)
		match _kinds[index]:
			Kind.ENGINE:
				_engine.build(mesh, room)
			Kind.HOLD:
				_hold.build(mesh, room)
			Kind.PASSAGE:
				_passage(mesh, room)
			Kind.STEERAGE:
				_cabin(mesh, room, cabin, glass)
				cabin += 1
			Kind.HELM:
				_helm(mesh, room, glass)
		if _kinds[index] in [Kind.ENGINE, Kind.HOLD, Kind.PASSAGE]:
			_signs(mesh, signs, room)


## [param room]'s full walls on [param space] (ShipSpace.wall_runs), each a Wall.
static func walls(space: ShipSpace, room: ShipRoom) -> Array[Wall]:
	var found: Array[Wall] = []
	for run: Array in space.wall_runs(room):
		found.append(Wall.new(space, room, run))
	return found


## Fire buckets, red on a shelf over head height on [param wall] at [param along].
static func fire_buckets(mesh: ShipMesh, wall: Wall, along: float) -> void:
	var shelf := wall.rect(along - 0.45, along + 0.45, 0.0, 0.3)
	block(mesh, shelf, wall.floor + HEADROOM, wall.floor + HEADROOM + 0.03, ShipPaints.frame)
	for index in 3:
		var at := wall.at(along + (index - 1) * 0.29, HEADROOM + 0.03, 0.15)
		var spot := Vector2(at.x, at.z)
		mesh.cylinder(spot, 0.11, at.y, at.y + 0.24, 8, ShipPaints.fire_bucket, false)


## A lower-deck cabin, the [param number]th: a berth slung overhead along one of the
## walls between it and the next, its blanket in the cabin's own colour; a washstand
## under a mirror on the other, by the hull side, and a locker by the door; curtains
## drawn back from each of [param glass]; and by turns a shelf with a suitcase over
## the door, a picture or a coat on a hook.
func _cabin(mesh: ShipMesh, room: ShipRoom, number: int, glass: Array[Array]) -> void:
	var blankets := ArtPalette.CABIN_BLANKETS
	var curtains := ArtPalette.CABIN_CURTAINS
	var finish := ShipMesh.Finish.PLAIN
	var blanket := ShipMesh.Paint.new(finish, blankets[number % blankets.size()])
	var curtain := ShipMesh.Paint.new(finish, curtains[number % curtains.size()])
	var around := walls(_space, room)
	var hull := -1
	var door := -1
	for wall: Wall in around:
		if wall.outdoors_beyond():
			hull = wall.side
	var runs := _space.wall_runs(room)
	for side in 4:
		if side == hull:
			continue
		for gap: Vector2 in _gaps(room, side, runs):
			if _beyond(_space, room, side, gap) != -1:
				door = side
	var sides: Array[Wall] = []
	for wall: Wall in around:
		if wall.side != hull and wall.side != door and wall.length() >= BERTH.x + 0.1:
			sides.append(wall)
	if hull == -1 or door == -1 or sides.size() < 2:
		return
	var berth := sides[number % 2]
	var stand := sides[(number + 1) % 2]
	_berth(mesh, berth, berth.end_by(hull), blanket)
	var wash := stand.end_by(hull)
	var by_door := stand.to - 0.4
	if wash == stand.from:
		_washstand(mesh, stand, wash + 0.45)
	else:
		_washstand(mesh, stand, wash - 0.45)
		by_door = stand.from + 0.4
	_locker(mesh, stand, by_door)
	for pane: Array in glass:
		_curtains(mesh, pane[1], pane[2], curtain)
	match number % 3:
		0:
			for wall: Wall in around:
				if wall.side == door and wall.length() >= 0.8:
					_luggage_shelf(mesh, wall)
					break
		1:
			var free := berth.to - 0.5 if berth.end_by(hull) == berth.from else berth.from + 0.5
			_picture(mesh, berth, free)
		2:
			var away := -0.7 if berth.end_by(hull) > berth.middle() else 0.7
			_coat(mesh, berth, berth.middle() + away, blanket)


## The room of [param space], by index, through the gap [param gap] along
## [param side] of [param room]; -1 for none.
static func _beyond(space: ShipSpace, room: ShipRoom, side: int, gap: Vector2) -> int:
	var beyond := space.on_side(room, side, (gap.x + gap.y) * 0.5, -0.3)
	return room_at(space, Vector3(beyond.x, room.floor_height + 1.0, beyond.y))


## The gaps along [param side] of [param room] between its full walls, [param runs]
## (ShipSpace.wall_runs), at least a doorway wide, as (from, to) along it.
static func _gaps(room: ShipRoom, side: int, runs: Array) -> Array[Vector2]:
	var along_x := side % 2 == 0
	var low := room.area.position.x if along_x else room.area.position.y
	var high := room.area.end.x if along_x else room.area.end.y
	var edges := PackedFloat32Array([low + 0.1])
	for run: Array in runs:
		if run[0] == side:
			edges.append_array([run[1], run[2]])
	edges.append(high - 0.1)
	edges.sort()
	var gaps: Array[Vector2] = []
	for index in range(0, edges.size() - 1, 2):
		if edges[index + 1] - edges[index] >= 0.6:
			gaps.append(Vector2(edges[index], edges[index + 1]))
	return gaps


## A berth slung overhead along [param wall] from [param end] of it: a frame on
## chains from the deckhead with tall ends and slats under it, a mattress showing over
## its rail, a pillow and a blanket of [param blanket] folded over its foot, all over
## HEADROOM.
func _berth(mesh: ShipMesh, wall: Wall, end: float, blanket: ShipMesh.Paint) -> void:
	var low := wall.floor + HEADROOM
	var way := 1.0 if is_equal_approx(end, wall.from) else -1.0
	var head := end + way * 0.02
	var foot := end + way * BERTH.x
	var a := minf(head, foot)
	var b := maxf(head, foot)
	var depth := BERTH.y
	var frame := ShipPaints.frame
	block(mesh, wall.rect(a, b, depth - 0.05, depth), low, low + 0.08, frame)
	for at: float in [a, b - 0.05]:
		block(mesh, wall.rect(at, at + 0.05, 0.0, depth), low, low + 0.42, frame)
		block(
			mesh,
			wall.rect(at - 0.01, at + 0.06, depth - 0.06, depth + 0.01),
			low + 0.38,
			low + 0.44,
			frame
		)
	var slat := a + 0.12
	while slat < b - 0.1:
		block(mesh, wall.rect(slat - 0.03, slat + 0.03, 0.0, depth - 0.05), low, low + 0.03, frame)
		slat += 0.42
	var mattress := wall.rect(a + 0.05, b - 0.05, 0.02, depth - 0.06)
	block(mesh, mattress, low + 0.03, low + 0.17, ShipPaints.linen, ShipMesh.RIM_ALL)
	var pillow := wall.rect(
		minf(head, head + way * 0.42), maxf(head, head + way * 0.42), 0.08, 0.55
	)
	block(mesh, pillow.grow(-0.02), low + 0.17, low + 0.3, ShipPaints.linen)
	var from := minf(head + way * 0.6, foot - way * 0.06)
	var to := maxf(head + way * 0.6, foot - way * 0.06)
	block(mesh, wall.rect(from, to, 0.0, depth - 0.05), low + 0.16, low + 0.23, blanket)
	block(mesh, wall.rect(from, to, depth - 0.06, depth - 0.045), low + 0.08, low + 0.23, blanket)
	for at: float in [a + 0.03, b - 0.03]:
		var hook := wall.at(at, HEADROOM + 0.42, depth - 0.025)
		var ceiling := _space.ceiling(wall.room, hook.x, hook.z) - ShipArt.PLANK
		var chain := Vector2.ONE * 0.016
		mesh.beam(hook, Vector3(hook.x, ceiling, hook.z), chain, ShipPaints.steel, 0)


## A washstand flat on [param wall] at [param along]: a cabinet under a marble top
## with a white basin let into it, a brass tap and a jug, a towel on a rail, and a
## mirror over it.
func _washstand(mesh: ShipMesh, wall: Wall, along: float) -> void:
	var floor := wall.floor
	var cabinet := wall.rect(along - 0.25, along + 0.25, 0.0, 0.08)
	block(mesh, cabinet, floor + 0.25, floor + 0.86, ShipPaints.frame, ShipMesh.RIM_ALL)
	for side: float in [-1.0, 1.0]:
		var door := wall.at(along + side * 0.12, 0.55, 0.082)
		panel(mesh, door, wall.right, Vector2(0.1, 0.24), wall.normal, ShipPaints.teak, 0)
	var marble := wall.rect(along - 0.28, along + 0.28, 0.0, 0.1)
	block(mesh, marble, floor + 0.86, floor + 0.9, ShipPaints.enamel)
	var bowl := wall.at(along, 0.905, 0.05)
	disc(mesh, bowl, Vector3.UP, 0.045, ShipPaints.mirror, 8)
	var tap := wall.at(along, 0.97, 0.03)
	mesh.turned_box(wall.place(tap), Vector3(0.03, 0.12, 0.04), ShipPaints.brass, 0)
	var jug := wall.at(along + 0.17, 0.9, 0.05)
	mesh.cylinder(Vector2(jug.x, jug.z), 0.045, jug.y, jug.y + 0.2, 8, ShipPaints.enamel, false)
	var mirror := wall.at(along, 1.55, 0.012)
	panel(mesh, mirror, wall.right, Vector2(0.2, 0.25), wall.normal, ShipPaints.frame)
	var glass := mirror + wall.normal * 0.006
	panel(mesh, glass, wall.right, Vector2(0.16, 0.21), wall.normal, ShipPaints.mirror)
	var rail := wall.at(along - 0.27, 0.75, 0.05)
	mesh.beam(rail, rail - wall.right * 0.25, Vector2.ONE * 0.015, ShipPaints.brass, 0)
	var towel := wall.at(along - 0.4, 0.62, 0.052)
	panel(mesh, towel, wall.right, Vector2(0.1, 0.13), wall.normal, ShipPaints.linen, 0)


## A tall locker flat on [param wall] at [param along]: two panelled doors, louvred
## at the top, and a brass knob.
func _locker(mesh: ShipMesh, wall: Wall, along: float) -> void:
	var body := wall.rect(along - 0.3, along + 0.3, 0.0, 0.08)
	block(mesh, body, wall.floor, wall.floor + 1.9, ShipPaints.frame, ShipMesh.RIM_ALL)
	for side: float in [-1.0, 1.0]:
		var door := wall.at(along + side * 0.14, 0.95, 0.083)
		panel(mesh, door, wall.right, Vector2(0.12, 0.85), wall.normal, ShipPaints.teak)
		for slat in 5:
			var louvre := wall.at(along + side * 0.14, 1.5 + slat * 0.06, 0.088)
			panel(mesh, louvre, wall.right, Vector2(0.09, 0.008), wall.normal, ShipPaints.dark, 0)
	var knob := wall.at(along + 0.03, 1.0, 0.095)
	mesh.turned_box(wall.place(knob), Vector3.ONE * 0.03, ShipPaints.brass, 0)


## Curtains drawn back either side of the glass centred on [param centre] facing
## [param normal] into its room, under a brass rod, in [param paint].
func _curtains(mesh: ShipMesh, centre: Vector3, normal: Vector3, paint: ShipMesh.Paint) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var rod := centre + Vector3.UP * 0.3 + normal * 0.04
	mesh.beam(rod - right * 0.38, rod + right * 0.38, Vector2.ONE * 0.016, ShipPaints.brass, 0)
	for side: float in [-1.0, 1.0]:
		for fold in 3:
			var at := centre + right * side * (0.24 + fold * 0.045) + Vector3.UP * 0.02
			var proud := 0.025 + 0.015 * (fold % 2)
			panel(mesh, at + normal * proud, right, Vector2(0.024, 0.27), normal, paint, 0)


## A shelf over the doorway in [param wall], over head height, with a suitcase on it.
func _luggage_shelf(mesh: ShipMesh, wall: Wall) -> void:
	var middle := wall.middle()
	var low := wall.floor + 2.1
	block(
		mesh, wall.rect(middle - 0.35, middle + 0.35, 0.0, 0.3), low, low + 0.03, ShipPaints.frame
	)
	var suitcase := wall.rect(middle - 0.24, middle + 0.24, 0.04, 0.27)
	block(mesh, suitcase, low + 0.03, low + 0.21, ShipPaints.upholstery, ShipMesh.RIM_ALL)
	block(mesh, suitcase.grow(0.006), low + 0.1, low + 0.13, ShipPaints.dark)


## A framed picture flat on [param wall] at [param along]: a seascape, a band of
## sky over a band of sea, in a dark frame.
func _picture(mesh: ShipMesh, wall: Wall, along: float) -> void:
	var centre := wall.at(along, 1.45, 0.012)
	panel(mesh, centre, wall.right, Vector2(0.24, 0.18), wall.normal, ShipPaints.frame)
	var sky := centre + wall.normal * 0.004 + Vector3.UP * 0.06
	panel(mesh, sky, wall.right, Vector2(0.2, 0.08), wall.normal, ShipPaints.chart)
	var sea := centre + wall.normal * 0.004 - Vector3.UP * 0.08
	panel(mesh, sea, wall.right, Vector2(0.2, 0.06), wall.normal, ShipPaints.mirror)


## A coat with a collar of [param paint] hanging flat from a hook on [param wall] at
## [param along].
func _coat(mesh: ShipMesh, wall: Wall, along: float, paint: ShipMesh.Paint) -> void:
	var hook := wall.at(along, 1.75, 0.03)
	mesh.turned_box(wall.place(hook), Vector3(0.03, 0.06, 0.06), ShipPaints.brass, 0)
	var coat := wall.at(along, 1.33, 0.05)
	panel(mesh, coat, wall.right, Vector2(0.2, 0.38), wall.normal, ShipPaints.leather)
	var collar := wall.at(along, 1.66, 0.06)
	panel(mesh, collar, wall.right, Vector2(0.12, 0.06), wall.normal, paint)


## The corridor's own: a handrail along each long wall, sloping up its stairs; a
## lifebelt on its longest stretch clear of a stair, fire buckets on a shelf
## overhead across from it.
func _passage(mesh: ShipMesh, room: ShipRoom) -> void:
	var along_x := room.area.size.x >= room.area.size.y
	var longest: Wall = null
	var around := walls(_space, room)
	for wall: Wall in around:
		if (wall.side % 2 == 0) != along_x or wall.length() < 0.5:
			continue
		_handrail(mesh, wall)
		if _stair_beside(wall) or (longest != null and wall.length() <= longest.length()):
			continue
		longest = wall
	if longest == null:
		return
	lifebelt(mesh, longest.at(longest.middle(), 1.35), longest.normal)
	for wall: Wall in around:
		if wall.side == (longest.side + 2) % 4 and wall.length() >= 1.0:
			if not _stair_beside(wall):
				fire_buckets(mesh, wall, wall.middle())
				return


## Whether a stair stands beside [param wall] anywhere along it.
func _stair_beside(wall: Wall) -> bool:
	var area := wall.rect(wall.from, wall.to, 0.0, 0.5)
	return over_a_ramp(_layout, area, wall.floor, wall.floor + 2.5)


## Whether [param area] reaches over any ramp of [param layout] standing between
## [param low] and [param high].
static func over_a_ramp(layout: ShipLayout, area: Rect2, low: float, high: float) -> bool:
	for ramp: ShipRamp in layout.ramps:
		var top := maxf(ramp.start_height, ramp.end_height)
		if ramp.area.intersects(area) and ramp.base() < high and top > low:
			return true
	return false


## A teak handrail on brass brackets along [param wall], at a hand's height over the
## floor or over a stair beside it — straight between where a stair begins and ends —
## stopping short of the wall's top.
func _handrail(mesh: ShipMesh, wall: Wall) -> void:
	var top := wall.floor + 2.4
	var stops := PackedFloat32Array([wall.from + 0.1, wall.to - 0.1])
	for ramp: ShipRamp in _layout.ramps:
		var span := Vector2(ramp.area.position.x, ramp.area.end.x)
		if wall.side % 2 == 1:
			span = Vector2(ramp.area.position.y, ramp.area.end.y)
		for at: float in [span.x, span.y]:
			if at > wall.from + 0.1 and at < wall.to - 0.1:
				stops.append(at)
	stops.sort()
	var rail := PackedVector3Array()
	for along: float in stops:
		rail.append(_hand_height(wall, along))
	for index in rail.size() - 1:
		var from := rail[index]
		var to := rail[index + 1]
		if from.y > top and to.y > top:
			continue
		if to.y > top:
			to = from.lerp(to, (top - from.y) / (to.y - from.y))
		elif from.y > top:
			from = to.lerp(from, (top - to.y) / (from.y - to.y))
		var pieces := ceili(from.distance_to(to) / PIECE)
		for piece in pieces:
			var start := from.lerp(to, float(piece) / pieces)
			var end := from.lerp(to, float(piece + 1) / pieces)
			mesh.beam(start, end, Vector2(0.045, 0.05), ShipPaints.teak, 0)
		var brackets := maxi(1, floori(from.distance_to(to)))
		for bracket in brackets + 1:
			var at := from.lerp(to, float(bracket) / brackets) - wall.normal * 0.045
			var box := Rect2(Vector2(at.x, at.z) - Vector2.ONE * 0.02, Vector2.ONE * 0.04)
			block(mesh, box, at.y - 0.095, at.y - 0.025, ShipPaints.brass)


## Where [param wall]'s handrail runs at [param along] it: 0.065 out from its face, a
## hand's height over the floor, or over a stair beside it.
func _hand_height(wall: Wall, along: float) -> Vector3:
	var at := wall.at(along, 0.0, 0.065)
	var foot := Vector2(at.x, at.z) + Vector2(wall.normal.x, wall.normal.z) * 0.1
	var surface := wall.floor
	for ramp: ShipRamp in _layout.ramps:
		if ramp.contains(foot.x, foot.y):
			surface = maxf(surface, ramp.height_at(foot.x, foot.y))
	return Vector3(at.x, surface + 0.92, at.z)


## A lifebelt hung flat on a wall at [param centre], facing [param normal]: a red
## ring with four white bands.
static func lifebelt(mesh: ShipMesh, centre: Vector3, normal: Vector3) -> void:
	var axes := across(normal)
	var front := centre + normal * 0.075
	var segments := 12
	for index in segments:
		var turn := TAU * index / segments
		var next := TAU * (index + 1) / segments
		var a := axes[0] * cos(turn) + axes[1] * sin(turn)
		var b := axes[0] * cos(next) + axes[1] * sin(next)
		var paint := ShipPaints.white if index % 3 == 1 else ShipPaints.lifebelt
		var face := [front + a * 0.19, front + b * 0.19, front + b * 0.33, front + a * 0.33]
		var flat := PackedVector3Array([normal, normal, normal, normal])
		mesh.smooth_quad(PackedVector3Array(face), flat, paint)
		var rim := [front + a * 0.33, front + b * 0.33, centre + b * 0.33, centre + a * 0.33]
		mesh.smooth_quad(PackedVector3Array(rim), PackedVector3Array([a, b, b, a]), paint)
		var hole := [centre + a * 0.19, centre + b * 0.19, front + b * 0.19, front + a * 0.19]
		mesh.smooth_quad(PackedVector3Array(hole), PackedVector3Array([-a, -b, -b, -a]), paint)


## The wheelhouse's own, against its walls: the wheel on its steering box in the
## forward wall between a binnacle and an engine-order telegraph, a clock over it and
## voice pipes in the corners; a chart over its chart case on the after wall, between
## the windows; and a teak surround and sill at each window.
func _helm(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for wall: Wall in walls(_space, room):
		if wall.side == 1:
			_wheel_wall(mesh, wall)
		elif wall.side == 3:
			_chart_wall(mesh, wall)
	var half := ShipFittings.WINDOW_SIZE * 0.5 + Vector2.ONE * (ShipFittings.WINDOW_FRAME + 0.05)
	for pane: Array in glass:
		if pane[3]:
			continue
		var centre: Vector3 = pane[1]
		var normal: Vector3 = pane[2]
		var right := normal.cross(Vector3.UP).normalized()
		for bar: Rect2 in [
			Rect2(-half.x, half.y - 0.05, half.x * 2.0, 0.05),
			Rect2(-half.x, -half.y, 0.05, half.y * 2.0),
			Rect2(half.x - 0.05, -half.y, 0.05, half.y * 2.0),
		]:
			var middle := centre + right * bar.get_center().x + Vector3.UP * bar.get_center().y
			panel(mesh, middle + normal * 0.02, right, bar.size * 0.5, normal, ShipPaints.frame)
		var sill := centre - Vector3.UP * (half.y + 0.02)
		var at := Vector2(sill.x, sill.z)
		var across := Vector2(right.x, right.z) * half.x
		var ledge := Rect2(at - across, Vector2.ZERO).expand(
			at + across + Vector2(normal.x, normal.z) * 0.08
		)
		block(mesh, ledge, sill.y - 0.03, sill.y + 0.02, ShipPaints.frame)


## The wheelhouse's forward wall: the wheel on its steering box, the binnacle to one
## side of it with its compensating spheres, the telegraph to the other, a clock over
## the wheel and voice pipes in the corners.
func _wheel_wall(mesh: ShipMesh, wall: Wall) -> void:
	var middle := wall.middle()
	var floor := wall.floor
	var steering := wall.rect(middle - 0.12, middle + 0.12, 0.0, 0.07)
	block(mesh, steering, floor, floor + 0.92, ShipPaints.frame, ShipMesh.RIM_ALL)
	block(mesh, steering.grow(0.005), floor + 0.8, floor + 0.85, ShipPaints.brass)
	wheel(mesh, wall.at(middle, 1.0, 0.085), wall.normal, 0.32, 0.022, 8, ShipPaints.teak)
	var binnacle := middle - 0.74
	_half_column(mesh, wall, binnacle, 0.09, Vector2(0.0, 1.0), ShipPaints.teak)
	_half_column(mesh, wall, binnacle, 0.1, Vector2(1.0, 1.2), ShipPaints.brass)
	_half_column(mesh, wall, binnacle, 0.08, Vector2(1.2, 1.28), ShipPaints.brass)
	_half_column(mesh, wall, binnacle, 0.045, Vector2(1.28, 1.36), ShipPaints.brass)
	for side: float in [-1.0, 1.0]:
		var sphere := wall.at(binnacle + side * 0.19, 1.1, 0.05)
		disc(mesh, sphere, wall.normal, 0.065, ShipPaints.dark, 10)
	var telegraph := middle + 0.74
	_half_column(mesh, wall, telegraph, 0.06, Vector2(0.0, 1.02), ShipPaints.brass)
	var dial := wall.at(telegraph, 1.2, 0.07)
	disc(mesh, dial, wall.normal, 0.16, ShipPaints.enamel, 14)
	ring(mesh, dial + wall.normal * 0.004, wall.normal, 0.15, 0.18, ShipPaints.brass, 14)
	var order := dial + wall.normal * 0.006 + Vector3.UP * 0.07
	panel(mesh, order, wall.right, Vector2(0.1, 0.035), wall.normal, ShipPaints.upholstery)
	var lever := dial + wall.normal * 0.02
	var handle := lever + (wall.right + Vector3.UP).normalized() * 0.16
	mesh.beam(lever, handle, Vector2.ONE * 0.022, ShipPaints.brass, 0)
	var clock := wall.at(middle, 1.75, 0.02)
	disc(mesh, clock, wall.normal, 0.11, ShipPaints.enamel, 12)
	ring(mesh, clock + wall.normal * 0.004, wall.normal, 0.1, 0.13, ShipPaints.brass, 12)
	for corner: float in [wall.from + 0.1, wall.to - 0.1]:
		var pipe := wall.at(corner, 1.3, 0.04)
		var ceiling := _space.ceiling(wall.room, pipe.x, pipe.z) - ShipArt.PLANK
		pipe(mesh, pipe, Vector3(pipe.x, ceiling, pipe.z), 0.025, ShipPaints.brass)
		var mouth := Vector2(pipe.x, pipe.z)
		mesh.cylinder(mouth, 0.045, pipe.y - 0.08, pipe.y, 8, ShipPaints.brass)


## The wheelhouse's after wall: a chart pinned in a frame between its windows, over a
## shallow chart case of two drawers.
func _chart_wall(mesh: ShipMesh, wall: Wall) -> void:
	var middle := wall.middle()
	var chart := wall.at(middle, 1.45, 0.012)
	panel(mesh, chart, wall.right, Vector2(0.27, 0.3), wall.normal, ShipPaints.frame)
	var paper := chart + wall.normal * 0.006
	panel(mesh, paper, wall.right, Vector2(0.23, 0.26), wall.normal, ShipPaints.chart)
	for line: Vector4 in [
		Vector4(-0.2, -0.1, -0.05, 0.2),
		Vector4(0.0, -0.2, 0.2, 0.05),
		Vector4(-0.18, 0.18, 0.2, -0.2),
	]:
		var from := paper + wall.normal * 0.003 + wall.right * line.x + Vector3.UP * line.y
		var to := paper + wall.normal * 0.003 + wall.right * line.z + Vector3.UP * line.w
		mesh.beam(from, to, Vector2(0.006, 0.002), ShipPaints.dark, 0)
	var drawers := wall.rect(middle - 0.5, middle + 0.5, 0.0, 0.09)
	block(mesh, drawers, wall.floor + 0.7, wall.floor + 0.98, ShipPaints.frame, ShipMesh.RIM_ALL)
	for drawer in 2:
		var front := wall.at(middle, 0.77 + drawer * 0.13, 0.092)
		panel(mesh, front, wall.right, Vector2(0.45, 0.05), wall.normal, ShipPaints.teak, 0)
		var pull := wall.place(front + wall.normal * 0.01)
		mesh.turned_box(pull, Vector3(0.1, 0.02, 0.02), ShipPaints.brass, 0)


## A half-column of [param radius] flat against [param wall] at [param along], from
## [param span].x to [param span].y over the floor and capped: a binnacle's or a
## telegraph's pillar.
func _half_column(
	mesh: ShipMesh, wall: Wall, along: float, radius: float, span: Vector2, paint: ShipMesh.Paint
) -> void:
	var bottom := wall.at(along, span.x)
	var top := wall.at(along, span.y)
	var segments := 8
	for index in segments:
		var turn := PI * index / segments
		var next := PI * (index + 1) / segments
		var na := wall.right * cos(turn) + wall.normal * sin(turn)
		var nb := wall.right * cos(next) + wall.normal * sin(next)
		var side := [
			bottom + na * radius, bottom + nb * radius, top + nb * radius, top + na * radius
		]
		mesh.smooth_quad(PackedVector3Array(side), PackedVector3Array([na, nb, nb, na]), paint)
		var cap := PackedVector3Array([top, top + na * radius, top + nb * radius])
		mesh.triangle(cap, PackedFloat32Array([0.0, 0.0, 0.0]), Vector3.UP, paint)


## A plate over every doorway of [param room] onto another room, on the doorway's
## head, naming the room beyond as the HUD names it: an enamel plate in a brass rim
## in [param mesh], its letters a Label3D under [param signs].
func _signs(mesh: ShipMesh, signs: Node3D, room: ShipRoom) -> void:
	var font := ThemeDB.fallback_font
	var runs := _space.wall_runs(room)
	for side in 4:
		for gap: Vector2 in _gaps(room, side, runs):
			var other := _beyond(_space, room, side, gap)
			if other == -1:
				continue
			var text := String(_layout.rooms[other].name).capitalize()
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT).x
			var half := Vector2(width * SIGN_PIXEL * 0.5 + 0.05, 0.075)
			var out := ShipSpace.outward(side)
			var normal := Vector3(-out.x, 0.0, -out.y)
			var right := Vector3.RIGHT if side % 2 == 0 else Vector3.BACK
			var at := _space.on_side(room, side, (gap.x + gap.y) * 0.5, 0.1)
			var centre := Vector3(at.x, room.floor_height + SIGN_HEIGHT, at.y)
			var rim := half + Vector2.ONE * 0.012
			panel(mesh, centre + normal * 0.01, right, rim, normal, ShipPaints.brass)
			panel(mesh, centre + normal * 0.014, right, half, normal, ShipPaints.enamel)
			var letters := Label3D.new()
			letters.text = text
			letters.font_size = SIGN_FONT
			letters.pixel_size = SIGN_PIXEL
			letters.modulate = ArtPalette.INK
			letters.outline_size = 0
			letters.shaded = true
			letters.double_sided = false
			letters.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			letters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			letters.basis = Basis.looking_at(-normal)
			letters.position = centre + normal * 0.02
			letters.visible = centre.y < _cut_above
			signs.add_child(letters)


## Ship point under [param room]'s ceiling on [param space] over [param at], at its
## deck's underside: where a lamp hangs from.
static func under_ceiling(space: ShipSpace, room: ShipRoom, at: Vector2) -> Vector3:
	return Vector3(at.x, space.ceiling(room, at.x, at.y) - ShipArt.PLANK, at.y)


## A flat panel centred on [param centre], [param half] (along [param right], up)
## from it, facing [param normal], the edges [param rims] names darkened.
static func panel(
	mesh: ShipMesh,
	centre: Vector3,
	right: Vector3,
	half: Vector2,
	normal: Vector3,
	paint: ShipMesh.Paint,
	rims := ShipMesh.RIM_ALL
) -> void:
	var x := right * half.x
	var y := Vector3.UP * half.y
	mesh.quad(centre - x - y, centre + x - y, centre + x + y, centre - x + y, normal, paint, rims)


## A box over [param area] from [param bottom] to [param top], uncut — a
## furnishing, not a wall a room's lines cross — the edges [param rims] names darkened
## on each face, none on a part too small for a bevel to show. One without rims, a
## beam or a board, is drawn in pieces no longer than PIECE, so no mesh it joins
## outgrows its chunk (ShipMesh); a rimmed one is furniture, short enough whole.
static func block(
	mesh: ShipMesh, area: Rect2, bottom: float, top: float, paint: ShipMesh.Paint, rims := 0
) -> void:
	if rims != 0:
		var centre := Vector3(area.get_center().x, (bottom + top) * 0.5, area.get_center().y)
		var size := Vector3(area.size.x, top - bottom, area.size.y)
		mesh.turned_box(Transform3D(Basis.IDENTITY, centre), size, paint, rims)
		return
	var along_x := area.size.x >= area.size.y
	var pieces := maxi(1, ceili((area.size.x if along_x else area.size.y) / PIECE))
	var cut := area.size / Vector2(pieces, 1.0) if along_x else area.size / Vector2(1.0, pieces)
	var step := Vector2(cut.x, 0.0) if along_x else Vector2(0.0, cut.y)
	var size := Vector3(cut.x, top - bottom, cut.y)
	for piece in pieces:
		var middle := Rect2(area.position + step * piece, cut).get_center()
		var centre := Vector3(middle.x, (bottom + top) * 0.5, middle.y)
		mesh.turned_box(Transform3D(Basis.IDENTITY, centre), size, paint, 0)


## Two unit vectors across [param normal]: right and up on a face turned to it.
static func across(normal: Vector3) -> Array[Vector3]:
	var right := normal.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var axes: Array[Vector3] = [right, right.cross(normal).normalized()]
	return axes


## A flat disc of [param radius] centred on [param centre] facing [param normal], in
## [param segments]; its paint's bands from [param foot].
static func disc(
	mesh: ShipMesh,
	centre: Vector3,
	normal: Vector3,
	radius: float,
	paint: ShipMesh.Paint,
	segments: int,
	foot := NAN
) -> void:
	var axes := across(normal)
	var ring := PackedVector3Array()
	for index in segments:
		var angle := TAU * index / segments
		ring.append(centre + (axes[0] * cos(angle) + axes[1] * sin(angle)) * radius)
	mesh.polygon(ring, normal, paint, centre.y - radius if is_nan(foot) else foot, NAN)


## A flat ring from [param inner] to [param outer] round [param centre], facing
## [param normal].
static func ring(
	mesh: ShipMesh,
	centre: Vector3,
	normal: Vector3,
	inner: float,
	outer: float,
	paint: ShipMesh.Paint,
	segments: int
) -> void:
	var axes := across(normal)
	for index in segments:
		var turn := TAU * index / segments
		var next := TAU * (index + 1) / segments
		var a := axes[0] * cos(turn) + axes[1] * sin(turn)
		var b := axes[0] * cos(next) + axes[1] * sin(next)
		var c := centre
		mesh.quad(c + a * inner, c + b * inner, c + b * outer, c + a * outer, normal, paint, 0)


## A gauge: a white face in a brass rim, with its needle.
static func gauge(mesh: ShipMesh, centre: Vector3, normal: Vector3, radius: float) -> void:
	disc(mesh, centre, normal, radius * 0.85, ShipPaints.gauge, 8)
	ring(mesh, centre + normal * 0.004, normal, radius * 0.8, radius, ShipPaints.brass, 8)
	var axes := across(normal)
	var hub := centre + normal * 0.006
	var tip := hub + (axes[0] * 0.6 + axes[1] * 0.5) * radius * 0.7
	mesh.beam(hub, tip, Vector2(0.008, 0.002), ShipPaints.dark, 0)


## A handwheel of [param radius] round [param hub] facing [param normal], its rim
## [param thick], with [param spokes] spokes across it — handles past its rim on a
## ship's wheel of more than six.
static func wheel(
	mesh: ShipMesh,
	hub: Vector3,
	normal: Vector3,
	radius: float,
	thick: float,
	spokes: int,
	paint: ShipMesh.Paint
) -> void:
	var inner := radius - thick * 1.5
	var outer := radius + thick * 0.5
	ring(mesh, hub, normal, inner, outer, paint, 12)
	ring(mesh, hub - normal * thick, -normal, inner, outer, paint, 12)
	var axes := across(normal)
	var reach := radius + (0.09 if spokes > 6 else 0.0)
	var middle := hub - normal * thick * 0.5
	for spoke in spokes:
		var out := axes[0] * cos(PI * spoke / spokes) + axes[1] * sin(PI * spoke / spokes)
		mesh.beam(middle - out * reach, middle + out * reach, Vector2.ONE * thick, paint, 0)
	disc(mesh, hub + normal * 0.004, normal, thick * 1.6, ShipPaints.brass, 8)


## A pipe of [param radius] from [param from] to [param to], round in PIPE_SIDES
## smooth facets, open at its ends, in pieces no longer than PIECE (block()).
static func pipe(
	mesh: ShipMesh, from: Vector3, to: Vector3, radius: float, paint := ShipPaints.steel
) -> void:
	var length := from.distance_to(to)
	if length < ShipMesh.SLIVER:
		return
	var pieces := ceili(length / PIECE)
	if pieces > 1:
		for piece in pieces:
			var start := from.lerp(to, float(piece) / pieces)
			pipe(mesh, start, from.lerp(to, float(piece + 1) / pieces), radius, paint)
		return
	var axis := (to - from) / length
	var x := axis.cross(Vector3.UP)
	if x.length_squared() < 0.01:
		x = axis.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := axis.cross(x).normalized()
	for index in PIPE_SIDES:
		var turn := TAU * index / PIPE_SIDES
		var next := TAU * (index + 1) / PIPE_SIDES
		var na := x * cos(turn) + y * sin(turn)
		var nb := x * cos(next) + y * sin(next)
		var corners := [from + na * radius, from + nb * radius, to + nb * radius, to + na * radius]
		mesh.smooth_quad(PackedVector3Array(corners), PackedVector3Array([na, nb, nb, na]), paint)


## A pipe's flange at [param at] across [param axis]: a short, wider brass collar.
static func flange(mesh: ShipMesh, at: Vector3, axis: Vector3, radius: float) -> void:
	pipe(mesh, at - axis * 0.025, at + axis * 0.025, radius + 0.025, ShipPaints.brass)
