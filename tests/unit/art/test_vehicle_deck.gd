extends GutTest
## The ferry's car deck is a vehicle deck (VehicleDeck), no saloon for all its size: its
## lanes' yellow lines, its stairs' keep-clear boxes and its lashing points painted on
## its deck and nowhere over a stair's opening, its sides' stiffeners, fire hose boxes and
## notices flat on its walls — none of it where a body stands (FurnishingCheck). On main
## it was taken for a saloon, by its size, and drew banquettes round its walls.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")

var _rules: BrawlRules = load("res://data/rules/brawl.tres")
var _layout: ShipLayout
var _space: ShipSpace
var _room: ShipRoom


func before_all() -> void:
	_layout = Fleet.layout(&"ferry")
	_space = ShipSpace.new(_layout)
	for room: ShipRoom in _layout.rooms:
		if room.name == &"car deck":
			_room = room


func test_only_the_ferry_s_car_deck_is_a_vehicle_deck() -> void:
	assert_eq(RoomDressing.kind_of(_space, _room), RoomDressing.Kind.VEHICLE)
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		var space := ShipSpace.new(layout)
		for room: ShipRoom in layout.rooms:
			var vehicle := RoomDressing.kind_of(space, room) == RoomDressing.Kind.VEHICLE
			assert_eq(
				vehicle, ship == "ferry" and room.name == &"car deck", "%s's %s" % [ship, room.name]
			)


func test_its_lanes_run_down_its_length_clear_of_its_stairs() -> void:
	var deck := VehicleDeck.new(_space)
	assert_eq(VehicleDeck.lines(_room).size(), 5, "five lines, four lanes")
	var stairs := deck.stairs_of(_room)
	assert_gt(stairs.size(), 0, "its stairs")
	for z: float in VehicleDeck.lines(_room):
		var from := Vector2(_room.area.position.x + VehicleDeck.LINE_OFF_WALL, z)
		var to := Vector2(_room.area.end.x - VehicleDeck.LINE_OFF_WALL, z)
		var runs := deck.runs(_room, stairs, from, to)
		assert_gt(runs.size(), 0, "the line at z %.1f" % z)
		for run: Vector2 in runs:
			for stair: Rect2 in stairs:
				var a := from + (to - from).normalized() * run.x
				var b := from + (to - from).normalized() * run.y
				var painted := Rect2(a, Vector2.ZERO).expand(b).grow(VehicleDeck.LINE * 0.5)
				assert_false(painted.intersects(stair), "the line at z %.1f over %s" % [z, stair])


func test_its_paint_lies_on_its_deck() -> void:
	var signs := Node3D.new()
	var faces := _drawn(signs)
	signs.free()
	var low := 0
	for corner: Vector3 in faces:
		if corner.y > _room.floor_height + VehicleDeck.PAINT + 0.001:
			continue
		low += 1
		var over := false
		for platform: ShipPlatform in _layout.platforms:
			if absf(platform.height - _room.floor_height) < 0.05:
				over = over or platform.area.grow(0.01).has_point(Vector2(corner.x, corner.z))
		assert_true(over, "paint at %s over its deck" % corner)
	assert_gt(low, 0, "its paint")


func test_nothing_it_draws_stands_in_a_body_s_way() -> void:
	var signs := Node3D.new()
	var faces := _drawn(signs)
	var texts := []
	for letters: Node in signs.get_children():
		texts.append((letters as Label3D).text)
	signs.free()
	assert_gte(texts.count(VehicleDeck.NO_SMOKING), 4, "NO SMOKING towards both ends of each side")
	assert_gte(texts.count(VehicleDeck.AT_SEA), 2, "no passenger to stay: amidships on each side")
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, faces), PackedStringArray())


## Every face of the car deck's own dressing (VehicleDeck.build), its notices' letters
## under [param signs].
func _drawn(signs: Node3D) -> PackedVector3Array:
	var lines: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, lines)
	VehicleDeck.new(_space).build(mesh, signs, _room)
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
