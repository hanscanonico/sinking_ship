extends GutTest
## Her water's sheets are made as each first shows water, not up front (#640): a dry box
## has none, and one made late is the sheet it would have been had it been made at the
## start and told everything since — its material today's, its cell's churn, glow and
## fronts and the waders with it.

const RunMatch := preload("res://tools/run_match.gd")
const LIFT := 50.0
const WADERS := [Vector4(1.0, LIFT, 2.0, 0.5)]

var _structure: ShipStructure
var _rooms: Array[ShipRoom]
var _layout: ShipLayout
var _schedule: SinkSchedule


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_structure = config.ship.structure
	_rooms = config.ship.rooms
	_layout = config.ship
	_schedule = config.schedule()


func _water() -> InnerWater:
	var water: InnerWater = add_child_autofree(InnerWater.new())
	var sea := ShaderMaterial.new()
	sea.shader = InnerWater.WATER_SHADER
	for colour: StringName in InnerWater.COLOURS:
		sea.set_shader_parameter(colour, Color(0.1, 0.3, 0.4))
	water.setup(_structure, _rooms, _layout, _schedule.passages(), _schedule.failing(), sea, {})
	return water


## A pose of her level, LIFT over the sea, every cell's water [param share] of the way up
## its box; dry, under every box of hers, where [param share] is negative.
func _pose(water: InnerWater, share: float) -> ShipPose:
	var lifted := Transform3D(Basis.IDENTITY, Vector3.UP * LIFT)
	var pose := ShipPose.new(-LIFT, 0.0, 0.0, lifted)
	pose.cells = _schedule.pose_at(0).cells
	for cell in _structure.cells.size():
		var box := water._boxes[cell]
		var low := box.position.y if box.size != Vector3.ZERO else _structure.cells[cell].low.y
		pose.levels.append(LIFT + low + box.size.y * share if share >= 0.0 else -LIFT)
	return pose


## Every water sheet [param water] has made: its surfaces' and its stacks'.
func _sheets(water: InnerWater) -> Array[MeshInstance3D]:
	var sheets: Array[MeshInstance3D] = []
	for child: Node in water.get_children():
		var sheet := child as MeshInstance3D
		if sheet != null and sheet.material_override is ShaderMaterial:
			var material := sheet.material_override as ShaderMaterial
			if material.shader == InnerWater.WATER_SHADER:
				sheets.append(sheet)
	return sheets


func test_a_dry_ship_makes_no_sheet() -> void:
	var water := _water()
	assert_eq(_sheets(water).size(), 0, "none made at the start")
	var dry := _pose(water, -1.0)
	water.show_water(dry, dry, 0.0)
	assert_eq(_sheets(water).size(), 0, "none made while every box is dry")


func test_a_box_holding_water_has_its_sheet_drawn_with_today_s_material() -> void:
	var water := _water()
	water.show_waders(PackedVector4Array(WADERS))
	var cell := water._boxes.find_custom(func(box: AABB) -> bool: return box.size.y > 1.0)
	assert_ne(cell, -1, "a cell drawn in a box of its own")
	InnerWaterSheets.tell(water, cell, &"inflow", 0.4)
	assert_null(water._surfaces[cell], "dry, its sheet is not made")
	var wet := _pose(water, 0.5)
	water.show_water(wet, wet, 0.0)
	var sheet := water._surfaces[cell]
	assert_not_null(sheet, "holding water, its sheet is made")
	assert_true(sheet.visible, "and shown")
	# Today's sheet as setup made it, told the waders and the churn as they came.
	var under_sky := _structure.cells[cell].kind == FloodCell.Kind.OPEN_WELL
	var today := InnerWaterSheets.surface(water, water._boxes[cell], under_sky)
	InnerWaterSheets.show_waders_on(today, SeaAndSky.padded_waders(PackedVector4Array(WADERS)), 1)
	InnerWater._param(today, &"inflow", 0.4)
	var made := sheet.material_override as ShaderMaterial
	var expected := today.material_override as ShaderMaterial
	assert_eq(made.shader, expected.shader, "the water's shader")
	assert_eq(sheet.mesh.get_aabb(), today.mesh.get_aabb(), "the cell surface's sheet")
	assert_eq(sheet.cast_shadow, today.cast_shadow, "casting no shadow")
	for uniform: Dictionary in made.shader.get_shader_uniform_list():
		var name: StringName = uniform["name"]
		if name == &"world_to_ship":
			continue
		assert_eq(
			made.get_shader_parameter(name), expected.get_shader_parameter(name), String(name)
		)


func test_a_stacked_box_s_sheet_is_made_as_its_water_reaches_it() -> void:
	var water := _water()
	assert_gt(water._stacks.size(), 0, "a cell drawn in a stack of boxes")
	for stack: Array in water._stacks:
		assert_null(stack[2], "none made at the start")
	var wet := _pose(water, -1.0)
	var lowest: AABB = water._stacks[0][1]
	wet.levels[water._stacks[0][0]] = LIFT + lowest.position.y + lowest.size.y * 0.5
	water.show_water(wet, wet, 0.0)
	var first: Array = water._stacks[0]
	var sheet: MeshInstance3D = first[2]
	assert_not_null(sheet, "its water halfway up the box: made")
	assert_true(sheet.visible, "and shown")
	var box: AABB = first[1]
	var made := sheet.material_override as ShaderMaterial
	assert_eq(made.get_shader_parameter(&"clip_low"), box.position, "clipped to its box")
	assert_eq(made.get_shader_parameter(&"clip_high"), box.end, "both ends")
	assert_eq(made.get_shader_parameter(&"outdoor"), 0.0, "under her decks")
