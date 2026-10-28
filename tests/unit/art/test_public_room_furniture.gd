extends GutTest
## The small Titanic's public rooms, her crew's quarters and her working passages — the
## Titanic before her plates were traced (#362) — carry furniture on their floors
## (FurnitureDressing), drawn in each room's manner: club chairs
## round the smoking room's card tables, settees with a table and armchairs in the
## lounge, writing desks in the reading and writing room, wicker tables and chairs in the
## verandah café and the reception room, settees in the after entrance, mess tables in
## the seamen's and the crew quarters, and stores stacked along the E deck working
## passages' walls. Every seat faces its table or backs onto its room's side, and a
## writing desk's drawers its chair; none stands in a doorway's way in or by a seat's
## start, no table by a pendant; and a seat is drawn in its box, its arms and back under
## a step over it, a stack of stores out to its box's sides. The Titanic's traced public
## rooms (#360) are held to the same rules.

const ArtLint := preload("res://tools/art_lint.gd")
const FurnishingCheck := preload("res://tools/furnishing_check.gd")

## The rooms furnished: [room, its tables, its armchairs, its settees, its stores].
const FURNISHED: Array[Array] = [
	[&"first-class smoking room", 8, 32, 0, 0],
	[&"first-class lounge", 6, 8, 6, 0],
	[&"reading and writing room", 4, 4, 2, 0],
	[&"verandah café", 8, 16, 0, 0],
	[&"reception room", 10, 32, 0, 0],
	[&"after entrance", 0, 0, 2, 0],
	[&"seamen's quarters", 2, 0, 0, 0],
	[&"crew quarters", 2, 0, 0, 0],
	[&"E deck working passage, engine room", 0, 0, 0, 12],
	[&"E deck working passage, turbine room", 0, 0, 0, 10],
	[&"E deck working passage, electric room", 0, 0, 0, 12],
	[&"E deck working passage, after hold, forward", 0, 0, 0, 10],
	[&"E deck working passage, after hold, aft", 0, 0, 0, 4],
]
## The Titanic's traced public rooms (#360), all of a name's rooms together: [name, its
## tables, its armchairs, its settees] — a writing desk is a table.
const TRACED: Array[Array] = [
	[&"first-class smoking room", 8, 32, 0],
	[&"first-class lounge", 15, 30, 6],
	[&"reading and writing room", 3, 3, 1],
	[&"verandah café and palm court", 4, 8, 0],
	[&"after grand staircase, A deck", 0, 0, 1],
]
## How far from a pendant, in plan, a table stands at least.
const PENDANT_CLEAR := 1.0
## How far past its box a seat's faces may stand: the models' rims and float noise.
const OUTSIDE := 0.005

var _rules: BrawlRules = load("res://data/rules/brawl.tres")
var _layout: ShipLayout = Fleet.layout(&"small_titanic")
var _space := ShipSpace.new(_layout)
var _titanic: ShipLayout = Fleet.layout(&"titanic")
var _titanic_space := ShipSpace.new(_titanic)


func test_each_public_room_has_its_furniture() -> void:
	for entry: Array in FURNISHED:
		var counts := {}
		for piece: ShipBlocker in _space.furniture(_room(entry[0])):
			var kind := FurnitureDressing.piece_of(piece)
			counts[kind] = counts.get(kind, 0) + 1
		var named: StringName = entry[0]
		assert_eq(counts.get(FurnitureDressing.Piece.TABLE, 0), entry[1], "%s: tables" % named)
		assert_eq(counts.get(FurnitureDressing.Piece.ARMCHAIR, 0), entry[2], "%s: chairs" % named)
		assert_eq(counts.get(FurnitureDressing.Piece.SETTEE, 0), entry[3], "%s: settees" % named)
		assert_eq(counts.get(FurnitureDressing.Piece.APPARATUS, 0), entry[4], "%s: stores" % named)


func test_the_titanic_s_traced_public_rooms_have_their_furniture() -> void:
	for entry: Array in TRACED:
		var counts := {}
		var rooms := 0
		for room: ShipRoom in _titanic.rooms:
			if room.name != entry[0]:
				continue
			rooms += 1
			for piece: ShipBlocker in _titanic_space.furniture(room):
				var kind := FurnitureDressing.piece_of(piece)
				counts[kind] = counts.get(kind, 0) + 1
		var named: StringName = entry[0]
		assert_gt(rooms, 0, "%s: a room of hers" % named)
		assert_eq(counts.get(FurnitureDressing.Piece.TABLE, 0), entry[1], "%s: tables" % named)
		assert_eq(counts.get(FurnitureDressing.Piece.ARMCHAIR, 0), entry[2], "%s: chairs" % named)
		assert_eq(counts.get(FurnitureDressing.Piece.SETTEE, 0), entry[3], "%s: settees" % named)


func test_every_seat_faces_its_table_or_backs_onto_its_room_s_side() -> void:
	for held: Array in _held():
		var room: ShipRoom = held[1]
		var pieces := (held[0] as ShipSpace).furniture(room)
		for piece: ShipBlocker in pieces:
			var kind := FurnitureDressing.piece_of(piece)
			if kind != FurnitureDressing.Piece.ARMCHAIR and kind != FurnitureDressing.Piece.SETTEE:
				continue
			var facing := FurnitureDressing.facing_of(room, pieces, piece)
			var middle := piece.area.get_center()
			var named := "%s: the seat at %s" % [room.name, piece.area]
			if kind == FurnitureDressing.Piece.SETTEE:
				var depth := absf(facing.dot(piece.area.size))
				var behind := middle - facing * (depth * 0.5 + FurnitureDressing.BACK_REACH)
				if not room.area.has_point(behind):
					continue
			var table := _nearest_table(pieces, middle)
			assert_true(table != Vector2.INF, named + " has a table near it")
			assert_gt(facing.dot(table - middle), 0.0, named + " faces its table")


func test_a_writing_desk_s_drawers_face_its_chair_not_its_wall() -> void:
	for held: Array in _held():
		var room: ShipRoom = held[1]
		if room.name == &"reading and writing room":
			_desks_face_their_chairs(room, (held[0] as ShipSpace).furniture(room))


func _desks_face_their_chairs(room: ShipRoom, pieces: Array[ShipBlocker]) -> void:
	for desk: ShipBlocker in pieces:
		if FurnitureDressing.piece_of(desk) != FurnitureDressing.Piece.TABLE:
			continue
		var middle := desk.area.get_center()
		var chair := Vector2.INF
		for other: ShipBlocker in pieces:
			var at := other.area.get_center()
			var armchair := FurnitureDressing.piece_of(other) == FurnitureDressing.Piece.ARMCHAIR
			if armchair and at.distance_to(middle) < chair.distance_to(middle):
				chair = at
		var front := FurnitureDressing.front_of(room, desk.area)
		assert_gt(front.dot(chair - middle), 0.0, "the desk at %s faces its chair" % desk.area)


## A body standing on a stack of stores stands in nothing hung over head height: the
## fire buckets a passage's wall would take hang past a body's reach from every stack.
func test_a_passage_s_fire_buckets_hang_out_of_reach_of_its_stores() -> void:
	var rack := RoomDressing.FIRE_BUCKETS.size
	var reach := _rules.body_radius - FurnishingCheck.TOLERANCE
	for entry: Array in FURNISHED:
		if entry[4] == 0:
			continue
		var room := _room(entry[0])
		var pieces := _space.furniture(room)
		var hung := 0
		for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
			var along := FurnitureDressing.clear_along(wall, pieces, rack.x, rack.z)
			if is_nan(along):
				continue
			hung += 1
			var area := wall.rect(along - rack.x * 0.5, along + rack.x * 0.5, 0.0, rack.z)
			for piece: ShipBlocker in pieces:
				var named := "%s: buckets at %s by the stack at %s" % [room.name, area, piece.area]
				assert_gte(_apart(area, piece.area), reach, named)
		assert_gt(hung, 0, "%s: a wall takes its buckets" % room.name)


func test_no_doorway_seat_start_or_pendant_is_crowded() -> void:
	var dressings := {
		_space: RoomDressing.new(_space), _titanic_space: RoomDressing.new(_titanic_space)
	}
	var surfaces := {_space: Surfaces.new(_layout), _titanic_space: Surfaces.new(_titanic)}
	for held: Array in _held():
		var space: ShipSpace = held[0]
		var room: ShipRoom = held[1]
		var dressing: RoomDressing = dressings[space]
		var ways: Array[Rect2] = []
		var doors := room.doors(surfaces[space], _rules.body_height, _rules.step_height)
		for door: ShipRoom.Door in doors:
			if _leads_somewhere(space.layout, room, door):
				ways.append(_way_in(door))
		for piece: ShipBlocker in space.furniture(room):
			for way: Rect2 in ways:
				var named := "%s: %s in a doorway's way %s" % [room.name, piece.area, way]
				assert_false(piece.area.intersects(way), named)
			var round := piece.area.grow(_rules.body_radius)
			for seat: Vector3 in space.layout.spawns:
				var on := round.has_point(Vector2(seat.x, seat.z))
				on = on and absf(seat.y - room.floor_height) < 0.5
				assert_false(on, "%s: a seat starts at %s by %s" % [room.name, seat, piece.area])
			if FurnitureDressing.piece_of(piece) != FurnitureDressing.Piece.TABLE:
				continue
			for light: RoomDressing.Light in dressing.lights(room):
				var lamp := Vector2(light.at.x, light.at.z)
				var nearest := lamp.clamp(piece.area.position, piece.area.end)
				var named := "%s: %s by its pendant" % [room.name, piece.area]
				assert_true(nearest.distance_to(lamp) >= PENDANT_CLEAR, named)


func test_a_seat_is_drawn_in_its_box_its_arms_and_back_under_a_step() -> void:
	var lounge := _room(&"first-class lounge")
	var pieces := _space.furniture(lounge)
	var drawn := {}
	for piece: ShipBlocker in pieces:
		var kind := FurnitureDressing.piece_of(piece)
		if kind != FurnitureDressing.Piece.ARMCHAIR and kind != FurnitureDressing.Piece.SETTEE:
			continue
		if drawn.has(kind):
			continue
		drawn[kind] = true
		var lines: Array[PackedFloat32Array] = [
			PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
		]
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, lines)
		var facing := FurnitureDressing.facing_of(lounge, pieces, piece)
		FurnitureDressing.seat(mesh, piece, facing, {})
		var faces := _faces(mesh)
		assert_gt(faces.size(), 0, "%s drawn" % piece.area)
		var area := piece.area.grow(OUTSIDE)
		var highest := piece.top + FurnitureDressing.BACK_RISE + OUTSIDE
		for corner: Vector3 in faces:
			if not area.has_point(Vector2(corner.x, corner.z)) or corner.y > highest:
				fail_test("the seat at %s: a face out of its box at %s" % [piece.area, corner])
				break
	assert_eq(drawn.size(), 2, "an armchair and a settee drawn")
	assert_lt(FurnitureDressing.BACK_RISE, _rules.step_height, "a seat's back under a step")


## Where art-lint probes a box's sides — a quarter, half and three quarters up them, a
## fifth, half and four fifths along — a stack of stores is drawn: no seam between
## two of its crates, one on another or side by side, is an open edge there. Off its
## seams its crates stand before its dark core, which shows in the seams alone.
func test_a_stack_of_stores_is_drawn_out_to_its_box_s_sides() -> void:
	var stack := _space.furniture(_room(&"E deck working passage, engine room"))[0]
	var lines: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, lines)
	FurnitureDressing.stores(mesh, stack.area, stack.bottom, stack.top)
	var faces := _faces(mesh)
	var area := stack.area
	for fraction: float in [0.2, 0.5, 0.8]:
		var x := lerpf(area.position.x, area.end.x, fraction)
		var z := lerpf(area.position.y, area.end.y, fraction)
		for share: float in [0.25, 0.5, 0.75]:
			var y := lerpf(stack.bottom, stack.top, share)
			var probes: Array[Array] = [
				[Vector3(x, y, area.position.y), Vector3.FORWARD],
				[Vector3(x, y, area.end.y), Vector3.BACK],
				[Vector3(area.position.x, y, z), Vector3.LEFT],
				[Vector3(area.end.x, y, z), Vector3.RIGHT],
			]
			for probe: Array in probes:
				var off := _off_side(faces, probe[0], probe[1])
				assert_lt(off, ArtLint.BLOCKER_TOLERANCE, "its side drawn at %s" % probe[0])
				if fraction != 0.5 and share != 0.5:
					var core := FurnitureDressing.STORES_CORE - ShipMesh.SLIVER
					assert_lt(off, core, "a crate before its core at %s" % probe[0])


## The middle of the table among [param pieces] nearest [param at] within
## FurnitureDressing.SEAT_REACH; Vector2.INF for none.
func _nearest_table(pieces: Array[ShipBlocker], at: Vector2) -> Vector2:
	var best := Vector2.INF
	for other: ShipBlocker in pieces:
		if FurnitureDressing.piece_of(other) != FurnitureDressing.Piece.TABLE:
			continue
		var middle := other.area.get_center()
		var near := middle.distance_to(at) < FurnitureDressing.SEAT_REACH
		if near and middle.distance_to(at) < best.distance_to(at):
			best = middle
	return best


## How far from [param point], on a box's side, the nearest of [param faces] stands along
## the line through it [param out] of the side, ArtLint.SIDE_REACH either way; INF for
## none — art-lint's probe.
func _off_side(faces: PackedVector3Array, point: Vector3, out: Vector3) -> float:
	var reach := ArtLint.SIDE_REACH
	var from := point + out * reach
	var nearest := INF
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			from, -out, faces[index], faces[index + 1], faces[index + 2]
		)
		if hit != null:
			var along := ((hit as Vector3) - from).dot(-out)
			if along <= reach * 2.0:
				nearest = minf(nearest, absf(along - reach))
	return nearest


## How far apart [param a] and [param b] stand across the ship plane: 0 where they meet.
func _apart(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dz := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dz).length()


## Every face [param mesh] holds, in the ship's space.
func _faces(mesh: ShipMesh) -> PackedVector3Array:
	var materials := {}
	for finish: int in ShipMesh.Finish.values():
		materials[finish] = StandardMaterial3D.new()
	var holder := Node3D.new()
	mesh.commit(holder, materials)
	var faces := PackedVector3Array()
	for child: Node in holder.get_children():
		faces.append_array((child as MeshInstance3D).mesh.get_faces())
	holder.free()
	return faces


## Every room these tests hold to their rules, each [its ship's space, the room]: the
## small Titanic's FURNISHED, and each of the Titanic's rooms TRACED names.
func _held() -> Array[Array]:
	var found: Array[Array] = []
	for entry: Array in FURNISHED:
		found.append([_space, _room(entry[0])])
	for entry: Array in TRACED:
		for room: ShipRoom in _titanic.rooms:
			if room.name == entry[0]:
				found.append([_titanic_space, room])
	return found


## Whether [param door] of [param room] of [param layout] leads somewhere: a body's
## breadth out of it, no blocker stands from the floor to over a body's knees — not a
## casing standing a hair off the room's side, which leaves no wall on the side itself.
func _leads_somewhere(layout: ShipLayout, room: ShipRoom, door: ShipRoom.Door) -> bool:
	var out := door.middle() + door.outward * _rules.body_radius * 2.0
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX or not blocker.area.has_point(out):
			continue
		var floor := room.floor_height
		if blocker.bottom <= floor + _rules.step_height and blocker.top >= floor + 0.6:
			return false
	return true


## The ship-plane strip a body takes into its room through [param door]: a body's
## breadth either side of the gap, a body's breadth deep.
func _way_in(door: ShipRoom.Door) -> Rect2:
	var breadth := _rules.body_radius * 2.0
	var along := (door.to - door.from).normalized()
	var a := door.from - along * breadth
	var b := door.to + along * breadth
	var inward := -door.outward * breadth
	return Rect2(a, Vector2.ZERO).expand(b).expand(a + inward).expand(b + inward)


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _layout.rooms:
		if room.name == room_name:
			return room
	return null
