extends GutTest
## RoomColumns: the parts of her rooms, each from its floor up to whatever roofs it,
## standing in one of her cells drawn round its rooms but in no box her cells are drawn
## in. A room no wider or deeper than twice CellBoxes.INSET — a sliver a piece's layout
## keeps where a cut runs through one of her rooms (#538) — stands in by INSET from
## nothing and holds no column, and asking of it raises no engine error: grown in by
## INSET, its area had a negative size, which Rect2 and AABB reject.

## The hold the rooms stand in: a cell poking out of her (CellBoxes.WHOLE), in a box
## barge's shell.
const HOLD_LOW := Vector3(-5.0, 0.0, -4.0)
const HOLD_HIGH := Vector3(5.0, 4.0, 4.0)
const FLOOR := 1.0


func test_a_room_narrower_than_twice_the_inset_holds_no_column() -> void:
	var store := _room(&"store", Rect2(-4.0, -3.0, 3.0, 6.0))
	var slivers: Array[ShipRoom] = [
		# Cut along her, as a piece's end cuts a room across her.
		_room(&"sliver along her", Rect2(2.0, -3.0, CellBoxes.INSET, 6.0)),
		_room(&"sliver across her", Rect2(-4.0, 3.5, 3.0, CellBoxes.INSET)),
	]
	var rooms: Array[ShipRoom] = [store]
	rooms.append_array(slivers)
	var layout := _barge(rooms)
	var found := RoomColumns.joined(layout.structure, layout, [], [])
	assert_eq(found.size(), 1, "the store's column alone: %s" % [found])
	var column: AABB = found[0][1] if not found.is_empty() else AABB()
	var inset := store.area.grow(-CellBoxes.INSET)
	assert_true(_footprint(column).is_equal_approx(inset), "the store's, in by INSET")
	for sliver: ShipRoom in slivers:
		for each: Array in found:
			var part: AABB = each[1]
			assert_false(sliver.area.intersects(_footprint(part)), "%s holds none" % sliver.name)
	assert_engine_error_count(0, "no Rect2 or AABB of a negative size")


## A box barge 20 m long, 10 m in the beam, its deck 6 m over its keel, in four
## sections, with one cell — its hold — holding [param rooms] on its floor.
func _barge(rooms: Array[ShipRoom]) -> ShipLayout:
	var structure := ShipStructure.new()
	for index in 4:
		var section := HullSection.new()
		section.x = -7.5 + 5.0 * index
		section.length = 5.0
		section.outline = PackedVector2Array(
			[Vector2(-5.0, 0.0), Vector2(5.0, 0.0), Vector2(5.0, 6.0), Vector2(-5.0, 6.0)]
		)
		structure.sections.append(section)
	var hold := FloodCell.new()
	hold.name = &"hold"
	hold.low = HOLD_LOW
	hold.high = HOLD_HIGH
	hold.kind = FloodCell.Kind.CARGO
	hold.shape = 0.5
	for room: ShipRoom in rooms:
		hold.rooms.append(room.name)
	structure.cells.append(hold)
	var layout := ShipLayout.new()
	layout.structure = structure
	layout.rooms = rooms
	return layout


func _room(room_name: StringName, area: Rect2) -> ShipRoom:
	var room := ShipRoom.new()
	room.name = room_name
	room.area = area
	room.floor_height = FLOOR
	return room


func _footprint(box: AABB) -> Rect2:
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
