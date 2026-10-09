extends GutTest
## SH17's authoring path: a ship drawn as a scene of marked pieces bakes back into the
## very ShipLayout — layout and structure — her generator writes, and a scene that is
## not a ship says why.

const AUTHORING := "res://authoring"
const WEAK_HULL := "res://tests/fixtures/ships/steamer_weak.tres"


## [param layout] drawn (ShipSceneDraw), packed and instantiated as a saved scene is.
func _drawn(layout: ShipLayout) -> Node:
	var root := ShipSceneDraw.scene(layout, "ship")
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	var scene := packed.instantiate()
	autofree(scene)
	return scene


## Every problem baking the steamer finds once [param change] has been made to her scene.
func _problems_after(change: Callable) -> PackedStringArray:
	var scene := _drawn(SimFixtures.steamer())
	change.call(scene)
	return ShipSceneBake.new(scene).problems


func test_every_ship_bakes_back_field_for_field() -> void:
	var paths := [WEAK_HULL]
	for file: String in DirAccess.get_files_at("res://data/ships"):
		if file.ends_with(".tres"):
			paths.append("res://data/ships/" + file)
	for path: String in paths:
		var layout: ShipLayout = load(path)
		var baked := ShipSceneBake.new(_drawn(layout))
		assert_eq(baked.problems, PackedStringArray(), path)
		assert_eq(ShipSceneBake.differences(baked.layout, layout, path), PackedStringArray())


func test_each_authoring_scene_bakes_to_her_ship() -> void:
	var ships := DirAccess.get_directories_at(AUTHORING)
	assert_has(ships, "steamer")
	for ship: String in ships:
		var baked := ShipSceneBake.of_scene("%s/%s/%s.tscn" % [AUTHORING, ship, ship])
		var wanted: ShipLayout = load("res://data/ships/%s.tres" % ship)
		assert_eq(baked.problems, PackedStringArray(), ship)
		assert_eq(ShipSceneBake.differences(baked.layout, wanted, ship), PackedStringArray())


func test_a_piece_moved_a_millimetre_is_a_difference() -> void:
	var scene := _drawn(SimFixtures.steamer())
	(scene.get_node("Platforms/Platform_poop_deck") as Node3D).position.y += 0.001
	var baked := ShipSceneBake.new(scene)
	assert_eq(
		ShipSceneBake.differences(baked.layout, SimFixtures.steamer(), "ship"),
		PackedStringArray(["ship.platforms[1].height: 1.201, not 1.2"])
	)


func test_a_section_moved_with_its_outline_bakes_the_same() -> void:
	var scene := _drawn(SimFixtures.steamer())
	var shift := Vector2(0.37, 1.13)
	for loft: CSGPolygon3D in scene.get_node("Structure/Sections").get_children():
		var outline := loft.polygon
		for index in outline.size():
			outline[index] -= shift
		loft.polygon = outline
		loft.position += Vector3(0, shift.y, shift.x)
	var baked := ShipSceneBake.new(scene)
	assert_eq(baked.problems, PackedStringArray())
	assert_eq(
		ShipSceneBake.differences(baked.layout, SimFixtures.steamer(), "ship"), PackedStringArray()
	)


func test_a_number_changed_is_a_difference() -> void:
	var scene := _drawn(SimFixtures.steamer())
	scene.get_node("Structure/Cells/Cell_aft_peak").set_meta(&"kind", "STORES")
	var baked := ShipSceneBake.new(scene)
	assert_eq(
		ShipSceneBake.differences(baked.layout, SimFixtures.steamer(), "ship"),
		PackedStringArray(["ship.structure.cells[0].kind: 3, not 4"])
	)


func test_a_turned_box_is_a_problem() -> void:
	var problems := _problems_after(
		func(scene: Node) -> void:
			(scene.get_node("Platforms/Platform_bridge") as Node3D).rotate_y(0.1)
	)
	assert_eq(
		problems,
		PackedStringArray(
			["platform Platforms/Platform_bridge: must stand square to the ship, unturned"]
		)
	)


func test_a_wall_with_thickness_is_a_problem() -> void:
	var problems := _problems_after(
		func(scene: Node) -> void:
			(scene.get_node("Structure/Walls/Wall_bulkhead_aft") as CSGBox3D).size.x = 0.2
	)
	assert_eq(
		problems,
		PackedStringArray(["wall Structure/Walls/Wall_bulkhead_aft: must be flat across x or z"])
	)


func test_a_railing_on_no_platform_is_a_problem() -> void:
	var problems := _problems_after(
		func(scene: Node) -> void:
			scene.get_node("Railings/Railing_poop_aft_0").set_meta(&"platform", &"Nowhere")
	)
	assert_eq(
		problems,
		PackedStringArray(["railing Railings/Railing_poop_aft_0: names no platform Nowhere"])
	)


func test_two_platforms_of_one_name_are_a_problem() -> void:
	var problems := _problems_after(
		func(scene: Node) -> void:
			var deck := Node3D.new()
			deck.name = "Upper"
			scene.add_child(deck)
			deck.add_child(scene.get_node("Platforms/Platform_bridge").duplicate())
	)
	assert_eq(
		problems,
		PackedStringArray(
			["platform Upper/Platform_bridge: another platform is named Platform_bridge"]
		)
	)


func test_a_shape_given_as_a_number_is_a_problem() -> void:
	var problems := _problems_after(
		func(scene: Node) -> void:
			scene.get_node("Platforms/Platform_bridge").set_meta(&"height", 9.0)
			scene.get_node("Structure/Cells/Cell_hold").set_meta(&"depth", 1.0)
			scene.get_node("Structure/Cells/Cell_hold").set_meta(&"kind", "BILGE")
	)
	assert_eq(
		problems,
		PackedStringArray(
			[
				"platform Platforms/Platform_bridge: height is no field its metadata sets",
				"cell Structure/Cells/Cell_hold: kind has no key BILGE",
				"cell Structure/Cells/Cell_hold: depth is no field its metadata sets",
			]
		)
	)


func test_an_unknown_tag_and_a_wrong_node_are_problems() -> void:
	var problems := _problems_after(
		func(scene: Node) -> void:
			var lamp := Node3D.new()
			lamp.name = "Lamp"
			lamp.set_meta(ShipSceneBake.TAG, &"lamp")
			scene.add_child(lamp)
			var ramp := Node3D.new()
			ramp.name = "Ramp"
			ramp.set_meta(ShipSceneBake.TAG, &"ramp")
			scene.get_node("Ramps").add_child(ramp)
	)
	assert_eq(
		problems,
		PackedStringArray(
			[
				"lamp Lamp: no piece is a lamp",
				"ramp Ramps/Ramp: must be a PrismMesh wedge, its apex at one end",
			]
		)
	)
