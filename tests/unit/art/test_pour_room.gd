extends GutTest
## A pour is drawn only in the cell it falls into (InnerWaterSheets.rooms, keep): its
## sheet is hung level with the world across its opening's whole width, so on a ship that
## leans a wide opening's sheet leaves her. The freighter's hatches, 11.8 m across her,
## each stood a white wedge over her deck at its low end as she heeled and her port side
## went under — under the sea, and drawn over it.

const RunMatch := preload("res://tools/run_match.gd")
## How far the pose heels her, in degrees, and how far it sinks her, in metres: her
## hatch row's middle under the sea.
const HEEL := -20.0
const SUNK := 1.5

var _structure: ShipStructure
var _layout: ShipLayout
var _schedule: SinkSchedule


func before_all() -> void:
	var config := RunMatch.default_config(7, 0, &"freighter")
	_structure = config.ship.structure
	_layout = config.ship
	_schedule = config.schedule()


func _sea() -> ShaderMaterial:
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://scenes/art/inner_water.gdshader")
	return sea


func _water() -> InnerWater:
	var water: InnerWater = add_child_autofree(InnerWater.new())
	water.setup(
		_structure, _layout.rooms, _layout, _schedule.passages(), _schedule.failing(), _sea(), {}
	)
	return water


## Her heeled HEEL and SUNK under the sea, every cell dry, [param hatch] given way.
func _heeled(hatch: ShipOpening) -> ShipPose:
	var turn := Basis(Vector3.RIGHT, deg_to_rad(HEEL))
	var pose := ShipPose.new(SUNK, 0.0, HEEL, Transform3D(turn, Vector3.DOWN * SUNK))
	pose.cells = _schedule.pose_at(0).cells
	for cell: FloodCell in _structure.cells:
		pose.levels.append(pose.world_height(cell.low) - 10.0)
	pose.opened[hatch.name] = 2
	return pose


## The room [param sheet] is kept in, ship space.
func _room(sheet: MeshInstance3D) -> AABB:
	var material := sheet.material_override as ShaderMaterial
	var low: Variant = material.get_shader_parameter(&"room_low")
	var high: Variant = material.get_shader_parameter(&"room_high")
	if low == null or high == null:
		return InnerWaterSheets.ANYWHERE
	return AABB(low, high - low)


func test_a_hatch_s_pour_on_a_heeled_ship_is_drawn_nowhere_over_her_deck() -> void:
	var water := _water()
	var index := -1
	for at in water._passages.size():
		var opening := water._passages[at]
		if opening.kind == ShipOpening.Kind.HATCH and ShipOpening.SKY in opening.joins:
			index = at
			break
	assert_ne(index, -1, "the freighter has a hatch open to the sky")
	var hatch := water._passages[index]
	var pose := _heeled(hatch)
	assert_lt(pose.world_height(hatch.centre), 0.0, "its middle is under the sea")
	water.show_water(pose, pose, 1.0)
	var pour := water._pours[index]
	assert_true(pour.visible, "the sea pours down through it")
	# The sheet's top, level with the world from the hatch's middle: at her low side it
	# stands over the deck the hatch is cut in.
	var over := -INF
	for end: float in [-0.5, 0.5]:
		over = maxf(over, (pour.transform * Vector3(end, 0.5, 0.0)).y - hatch.centre.y)
	assert_gt(over, 1.0, "hung level, its low end stands metres over her deck")
	for sheet: MeshInstance3D in [pour, water._crossings[index], water._landings[index]]:
		var room := _room(sheet)
		assert_almost_eq(room.end.y, hatch.centre.y, 1e-6, "kept under her deck")
		assert_true(
			room.has_point(hatch.centre + Vector3.DOWN * 0.5), "and drawn in the hold under it"
		)
		assert_true(room.has_point(sheet.transform.origin), "where its own middle hangs")


func test_a_pour_s_room_is_the_cell_it_falls_into_and_everywhere_for_the_sea() -> void:
	var water := _water()
	var seen := 0
	for index in water._passages.size():
		var opening := water._passages[index]
		for side in 2:
			var cell := water._sides[index * 2 + side]
			var room := water._rooms[index * 2 + side]
			if cell == -1:
				assert_eq(room, InnerWaterSheets.ANYWHERE, "%s: into the sea" % opening.name)
				continue
			var own := _structure.cells[cell]
			var held := room.encloses(AABB(own.low, own.high - own.low))
			assert_true(held, "%s: all of %s" % [opening.name, own.name])
			assert_true(room.has_point(opening.centre), "%s: and its opening" % opening.name)
			seen += 1
	assert_gt(seen, 0, "she has openings into her cells")


func test_a_sheet_kept_in_the_room_it_has_is_told_nothing() -> void:
	var sheet: WaterSheet = autofree(WaterSheet.new())
	var material := ShaderMaterial.new()
	material.shader = InnerWater.SPILL_SHADER
	sheet.material_override = material
	var room := AABB(Vector3(1.0, -9.0, -8.0), Vector3(40.0, 9.0, 16.0))
	sheet.keep_in(room)
	assert_eq(material.get_shader_parameter(&"room_low"), room.position, "its low corner")
	assert_eq(material.get_shader_parameter(&"room_high"), room.end, "its high corner")
	material.set_shader_parameter(&"room_low", Vector3.ZERO)
	sheet.keep_in(room)
	assert_eq(material.get_shader_parameter(&"room_low"), Vector3.ZERO, "kept again, not set")
	sheet.forget()
	sheet.keep_in(room)
	assert_eq(material.get_shader_parameter(&"room_low"), room.position, "forgotten, set again")
