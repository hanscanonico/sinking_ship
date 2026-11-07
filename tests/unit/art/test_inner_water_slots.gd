extends GutTest
## Her water's world to ship space is set once a frame for every cell's surface (#410):
## each InnerWater takes a global slot of its own (InnerWater.TO_SHIP), which its
## surfaces read, and gives it back as it goes; one past them sets its own on every
## surface it shows, as each surface's own did before.

const RunMatch := preload("res://tools/run_match.gd")
const LIFT := 50.0

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
	water.setup(_structure, _rooms, _layout, _schedule.passages(), _schedule.failing(), sea, {})
	return water


## A pose of her heeled, LIFT over the sea, every cell's water halfway up its box.
func _pose(water: InnerWater) -> ShipPose:
	var turned := Transform3D(Basis(Vector3.BACK, deg_to_rad(8.0)), Vector3.UP * LIFT)
	var pose := ShipPose.new(-LIFT, 0.0, 0.0, turned)
	pose.cells = _schedule.pose_at(0).cells
	for cell in _structure.cells.size():
		pose.levels.append((turned * water._boxes[cell].get_center()).y)
	return pose


func _slot_of(surface: MeshInstance3D) -> int:
	return (surface.material_override as ShaderMaterial).get_shader_parameter(&"slot")


func _shown(water: InnerWater) -> Array[MeshInstance3D]:
	var shown: Array[MeshInstance3D] = []
	for surface: MeshInstance3D in water._surfaces:
		if surface != null and surface.visible:
			shown.append(surface)
	return shown


func test_each_water_reads_its_own_slot_and_gives_it_back() -> void:
	var first := _water()
	var second := _water()
	assert_ne(first._slot, -1, "a slot free")
	assert_ne(second._slot, -1, "and another")
	assert_ne(first._slot, second._slot, "each its own")
	for water: InnerWater in [first, second]:
		for surface: MeshInstance3D in water._surfaces:
			if surface != null:
				assert_eq(_slot_of(surface), water._slot, "its surfaces read its slot")
	var held := first._slot
	first.free()
	assert_eq(_water()._slot, held, "freed, its slot is taken again")


func test_past_the_slots_a_water_sets_its_own_on_what_it_shows() -> void:
	var waters: Array[InnerWater] = []
	for slot in InnerWater.TO_SHIP.size() + 1:
		waters.append(_water())
	var past := waters.back() as InnerWater
	assert_eq(past._slot, -1, "no slot left")
	var pose := _pose(past)
	past.show_water(pose, pose, 0.0)
	# The ship as InnerWater draws her between the two poses.
	var drawn := pose.transform.interpolate_with(pose.transform, 0.0)
	var shown := _shown(past)
	assert_false(shown.is_empty(), "its water shows")
	for surface: MeshInstance3D in shown:
		assert_eq(_slot_of(surface), -1)
		var own: Transform3D = (surface.material_override as ShaderMaterial).get_shader_parameter(
			&"world_to_ship"
		)
		assert_eq(own, drawn.affine_inverse(), "its own world to ship space")
	var slotted := waters[0]
	slotted.show_water(pose, pose, 0.0)
	for surface: MeshInstance3D in _shown(slotted):
		assert_eq(
			(surface.material_override as ShaderMaterial).get_shader_parameter(&"world_to_ship"),
			null,
			"a slotted surface's is the global"
		)
