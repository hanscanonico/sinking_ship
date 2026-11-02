extends GutTest
## A hold too low for it stows nothing over head height: the Titanic's orlop forward of D,
## under 2 m to its deck, its racks' sacks once through the deck into the rooms over it.

const SHIP := "res://data/ships/titanic.tres"
const LOW_HOLD := &"first- and second-class baggage room"


func test_a_hold_no_taller_than_head_height_has_no_racks_through_its_deck() -> void:
	var ship: ShipLayout = load(SHIP)
	var space := ShipSpace.new(ship)
	var hold := CargoHold.new(space)
	var checked := 0
	for room: ShipRoom in ship.rooms:
		if room.name != LOW_HOLD:
			continue
		checked += 1
		var middle := room.area.get_center()
		var head := space.ceiling(room, middle.x, middle.y)
		assert_lt(head - room.floor_height, RoomDressing.HEADROOM + 0.2, "she is that low there")
		var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, space.room_lines())
		hold.build(mesh, room)
		var parent := Node3D.new()
		var materials := {}
		for finish: int in ShipMesh.Finish.values():
			materials[finish] = StandardMaterial3D.new()
		mesh.commit(parent, materials)
		var highest := -INF
		for node: Node in parent.get_children():
			for corner: Vector3 in (node as MeshInstance3D).mesh.get_faces():
				highest = maxf(highest, corner.y)
		parent.free()
		assert_lte(highest, head + 0.001, "nothing of it through its deck")
	assert_gt(checked, 0, "she has the room")
