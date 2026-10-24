extends GutTest
## The liner's public rooms, her crew's quarters and her working passages carry
## furniture on their floors (FurnitureDressing), drawn in each room's manner: club chairs
## round the smoking room's card tables, settees with a table and armchairs in the
## lounge, writing desks in the reading and writing room, wicker tables and chairs in the
## verandah café and the reception room, settees in the after entrance, mess tables in
## the seamen's and the crew quarters, and stores stacked along the E deck working
## passages' walls. Every seat faces its table or backs onto its room's side; none stands
## in a doorway's way in or by a seat's start, no table by a pendant; and a seat is drawn
## in its box, its arms and back under a step over it.

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
## How far from a pendant, in plan, a table stands at least.
const PENDANT_CLEAR := 1.0
## How far past its box a seat's faces may stand: the models' rims and float noise.
const OUTSIDE := 0.005

var _rules: BrawlRules = load("res://data/rules/brawl.tres")
var _layout: ShipLayout = Fleet.layout(&"titanic")
var _space := ShipSpace.new(_layout)


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


func test_every_seat_faces_its_table_or_backs_onto_its_room_s_side() -> void:
	for entry: Array in FURNISHED:
		var room := _room(entry[0])
		var pieces := _space.furniture(room)
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


func test_no_doorway_seat_start_or_pendant_is_crowded() -> void:
	var dressing := RoomDressing.new(_space)
	var surfaces := Surfaces.new(_layout)
	for entry: Array in FURNISHED:
		var room := _room(entry[0])
		var ways: Array[Rect2] = []
		for door: ShipRoom.Door in room.doors(surfaces, _rules.body_height, _rules.step_height):
			ways.append(_way_in(door))
		for piece: ShipBlocker in _space.furniture(room):
			for way: Rect2 in ways:
				var named := "%s: %s in a doorway's way %s" % [room.name, piece.area, way]
				assert_false(piece.area.intersects(way), named)
			var round := piece.area.grow(_rules.body_radius)
			for seat: Vector3 in _layout.spawns:
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
