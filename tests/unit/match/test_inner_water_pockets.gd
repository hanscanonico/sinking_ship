extends GutTest
## Her pockets' air is drawn walking only the cells that hold air in the pose shown, or
## held it in the last (#410, InnerWaterPockets): every other cell's water glows not,
## holds no air and has none to vent. On her real ships' sinkings, frame after frame, it
## draws what a walk of every cell draws — each glow, air, leak, vent and light alike.

const RunMatch := preload("res://tools/run_match.gd")
const SEA := preload("res://scenes/art/water.gdshader")
const SHIPS: Array[StringName] = [&"steamer", &"small_titanic"]
const SEED := 4
const STRIDE := 5
const ALPHAS: Array[float] = [0.4, 1.0]


## A walk of every cell of hers, as the pockets were drawn before #410.
class EveryCell:
	extends InnerWaterPockets

	func _walk(water: InnerWater) -> PackedInt32Array:
		return PackedInt32Array(range(water._airs.size()))


func test_the_walk_takes_the_cells_held_now_and_last_in_order() -> void:
	var walk := InnerWaterPockets.pocket_walk
	assert_eq(
		walk.call(PackedInt32Array([2, 5]), PackedInt32Array([2, 5])), PackedInt32Array([2, 5])
	)
	assert_eq(
		walk.call(PackedInt32Array([1, 4, 9]), PackedInt32Array([0, 4, 7])),
		PackedInt32Array([0, 1, 4, 7, 9]),
		"each once, ascending"
	)
	assert_eq(walk.call(PackedInt32Array(), PackedInt32Array([3])), PackedInt32Array([3]))
	assert_eq(walk.call(PackedInt32Array([3]), PackedInt32Array()), PackedInt32Array([3]))


func test_her_pockets_are_drawn_as_a_walk_of_every_cell_draws_them() -> void:
	for ship: StringName in SHIPS:
		var config := RunMatch.default_config(SEED, 2, ship)
		var schedule := config.schedule()
		var sea := ShaderMaterial.new()
		sea.shader = SEA
		var waters: Array[InnerWater] = []
		for side in 2:
			var water: InnerWater = add_child_autofree(InnerWater.new())
			water.setup(
				config.ship.structure,
				config.ship.rooms,
				config.ship,
				schedule.passages(),
				schedule.failing(),
				sea,
				{}
			)
			if side == 1:
				water._pockets = EveryCell.new()
			waters.append(water)
		var differences: Array[String] = []
		var held := 0
		for tick in range(0, schedule.end_tick(), STRIDE):
			var then := schedule.pose_at(tick)
			var now := schedule.pose_at(tick + STRIDE)
			for alpha: float in ALPHAS:
				var drawn: Array[PackedByteArray] = []
				for water: InnerWater in waters:
					water.show_water(then, now, alpha)
					drawn.append(var_to_bytes(_state(water)))
				if drawn[0] != drawn[1] and differences.size() < 4:
					differences.append("tick %d at %s" % [tick, alpha])
			held += 1 if waters[0]._airs.count(-1.0) < waters[0]._airs.size() else 0
		assert_eq(differences, [] as Array[String], "%s's pockets are drawn alike" % ship)
		assert_gt(held, 0, "%s's sinking holds air in a pocket" % ship)


## What [param water] draws of its pockets and keeps of them.
func _state(water: InnerWater) -> Array:
	var state := [
		water._airs,
		water._glows,
		water._burst_cells,
		water._burst_at,
		water._burst_ages,
		water._next_burst,
	]
	for child: Node in water.get_children():
		var drawn := child as Node3D
		if drawn == null:
			continue
		state.append(drawn.visible)
		if drawn.visible:
			state.append(drawn.transform)
		if drawn is OmniLight3D:
			state.append((drawn as OmniLight3D).omni_range)
		var mesh := drawn as MeshInstance3D
		if mesh != null:
			var material := mesh.material_override as ShaderMaterial
			for param: StringName in [&"pocket_glow", &"outdoor", &"burst", &"strength"]:
				state.append(material.get_shader_parameter(param))
	return state
