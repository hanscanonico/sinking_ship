extends GutTest
## The observer's cells (CellOverlay) are drawn from the layout's structure: a name per
## cell over the steamer's, and nothing at all over a ship the physics does not float;
## and each cell's water as the pose has it — drawn wet, its depth and pocket under its
## name, none dry, no surface full, and that surface level with the world as she heels.


func _labels(overlay: CellOverlay) -> int:
	var count := 0
	for child: Node in overlay.get_children():
		if child is Label3D:
			count += 1
	return count


func test_every_cell_of_the_steamer_is_named() -> void:
	var overlay: CellOverlay = add_child_autofree(CellOverlay.new())
	var structure := SimFixtures.steamer().structure
	overlay.build(structure)
	assert_eq(_labels(overlay), structure.cells.size())


func test_a_ship_with_no_structure_draws_no_cells() -> void:
	var layout := SimFixtures.deck()
	assert_null(layout.structure, "the flat deck does not float")
	var overlay: CellOverlay = add_child_autofree(CellOverlay.new())
	overlay.build(layout.structure)
	assert_eq(overlay.get_child_count(), 0)


## The steamer's overlay, built, and three of her cells people walk in, each over two
## metres tall: one to stand wet, one full and one dry.
func _water_fixture() -> Array:
	var overlay: CellOverlay = add_child_autofree(CellOverlay.new())
	var structure := SimFixtures.steamer().structure
	overlay.build(structure)
	var picked: Array[StringName] = []
	for cell: FloodCell in structure.cells:
		if cell.kind != FloodCell.Kind.VOID and cell.high.y - cell.low.y > 2.0:
			picked.append(cell.name)
		if picked.size() == 3:
			break
	return [overlay, structure, picked]


## A pose of her drawn at [param drawn]: [param wet] with water 1 m over its lowest
## corner and a pocket of 2 m of sea, [param full] full, every other cell dry.
func _water_pose(structure: ShipStructure, drawn: Transform3D, wet: int, full: int) -> ShipPose:
	var pose := ShipPose.new(0.0, 0.0, 0.0, drawn)
	pose.levels.resize(structure.cells.size())
	pose.pockets.resize(structure.cells.size())
	for index in structure.cells.size():
		var cell := structure.cells[index]
		var whole := CellSurface.reach(drawn, AABB(cell.low, cell.high - cell.low))
		pose.levels[index] = whole.x
		if index == wet:
			pose.levels[index] = whole.x + 1.0
		elif index == full:
			pose.levels[index] = whole.y
	pose.pockets[wet] = 2.0
	return pose


func test_a_wet_cell_s_water_is_drawn_and_its_depth_read_under_its_name() -> void:
	var fixture := _water_fixture()
	var overlay: CellOverlay = fixture[0]
	var structure: ShipStructure = fixture[1]
	var picked: Array[StringName] = fixture[2]
	assert_eq(picked.size(), 3, "three tall cells people walk in")
	var wet := structure.cell_named(picked[0])
	var full := structure.cell_named(picked[1])
	var dry := structure.cell_named(picked[2])
	overlay.show_water(
		_water_pose(structure, Transform3D.IDENTITY, wet, full), Transform3D.IDENTITY
	)
	assert_true(overlay._water[wet].visible, "the wet cell's water")
	assert_true(overlay._levels[wet].visible, "and its surface")
	assert_string_contains(overlay._names[wet].text, "\n1.00 m")
	assert_string_contains(overlay._names[wet].text, "\npocket ", "its pocket's pressure")
	assert_true(overlay._airs[wet].visible, "its pocket's air")
	assert_false(overlay._water[dry].visible, "the dry cell draws no water")
	assert_false(overlay._levels[dry].visible, "nor a surface")
	assert_false(overlay._airs[dry].visible, "nor air")
	assert_eq(overlay._names[dry].text, overlay._words[dry], "its name alone")
	assert_true(overlay._water[full].visible, "the full cell's water")
	assert_false(overlay._levels[full].visible, "the full cell shows no surface")
	assert_string_contains(overlay._names[full].text, "\nfull")


func test_a_wet_cell_s_surface_stays_level_with_the_world_as_she_heels() -> void:
	var fixture := _water_fixture()
	var overlay: CellOverlay = fixture[0]
	var structure: ShipStructure = fixture[1]
	var picked: Array[StringName] = fixture[2]
	var wet := structure.cell_named(picked[0])
	var full := structure.cell_named(picked[1])
	var drawn := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3.ZERO)
	overlay.show_water(_water_pose(structure, drawn, wet, full), drawn)
	var surface: MeshInstance3D = overlay._levels[wet]
	assert_true(surface.visible, "the wet cell's surface, heeled")
	var normal := (drawn.basis * surface.transform.basis.y).normalized()
	assert_almost_eq(normal, Vector3.UP, Vector3.ONE * 1e-3)
