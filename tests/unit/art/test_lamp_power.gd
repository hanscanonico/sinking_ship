extends GutTest
## Her rooms' lamps lit pose by pose (#410, LampPower): the loop over every lamp in the
## game's extension against the GDScript it stands in for, bit for bit — on her real
## ships' sinkings, tick after tick, every lamp handed the same power and drowning, and
## the same kept — and the lamps woken round the eye found among those in its stretch
## of her alone, as a walk of every lamp finds them. Where the extension is not loaded
## there is nothing to hold it to; CI sets SINKING_NATIVE_REQUIRED, so a missing library
## there fails.

const RunMatch := preload("res://tools/run_match.gd")
const SHIPS: Array[StringName] = [&"steamer", &"small_titanic"]
const SEED := 4
const STRIDE := 7


func test_her_lamps_are_lit_alike_as_she_sinks() -> void:
	if not _loaded():
		return
	for ship: StringName in SHIPS:
		var config := RunMatch.default_config(SEED, 2, ship)
		var schedule := config.schedule()
		var at := _points(config.ship)
		var powers: Array[LampPower] = []
		var lamps: Array[Array] = []
		for side in 2:
			var own: Array[ShipLamp] = []
			for _index in at.size():
				own.append(autofree(ShipLamp.new()))
			var power := LampPower.new(own, at)
			if side == 1:
				power.water = null
			powers.append(power)
			lamps.append(own)
		assert_not_null(powers[0].water, "%s's lamps are lit natively" % ship)
		var differences: Array[String] = []
		var drowned := 0
		for tick in range(0, schedule.end_tick(), STRIDE):
			var pose := schedule.pose_at(tick)
			if pose.levels.is_empty():
				continue
			var lit: Array[PackedByteArray] = []
			for side in 2:
				powers[side].show(pose)
				var state := [powers[side]._shown]
				for lamp: ShipLamp in lamps[side]:
					state.append([lamp.power, lamp.drowned])
				lit.append(var_to_bytes(state))
			if lit[0] != lit[1] and differences.size() < 4:
				differences.append("tick %d" % tick)
			drowned += powers[0]._shown.count(ShipPower.Power.MAIN * 2 + 1)
		assert_eq(differences, [] as Array[String], "%s's lamps are lit alike" % ship)
		assert_gt(drowned, 0, "%s's water reaches a lamp" % ship)


func test_the_lamps_woken_are_those_a_walk_of_every_lamp_finds() -> void:
	var config := RunMatch.default_config(SEED, 2, &"small_titanic")
	var at := _points(config.ship)
	var power := LampPower.new([] as Array[ShipLamp], at)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var low := at[0]
	var high := at[0]
	for point in at:
		low = low.min(point)
		high = high.max(point)
	var eyes := PackedVector3Array([at[0], at[at.size() - 1], Vector3(low.x - 39.5, 0.0, 0.0)])
	for _eye in 200:
		eyes.append(
			Vector3(
				rng.randf_range(low.x - 60.0, high.x + 60.0),
				rng.randf_range(low.y, high.y),
				rng.randf_range(low.z, high.z)
			)
		)
	var reach := LampPower.WAKE_REACH * LampPower.WAKE_REACH
	var found := 0
	for eye in eyes:
		var walked := PackedInt32Array()
		for index in at.size():
			if at[index].distance_squared_to(eye) <= reach:
				walked.append(index)
		assert_eq(power.near(eye), walked, "round %s" % eye)
		found += walked.size()
	assert_gt(found, 0)


## Points spread through [param layout]'s cells, a lamp at each: their middles, their
## floors and their tops.
func _points(layout: ShipLayout) -> PackedVector3Array:
	var at := PackedVector3Array()
	for cell: FloodCell in layout.structure.cells:
		var middle := cell.low.lerp(cell.high, 0.5)
		at.append(middle)
		at.append(Vector3(middle.x, cell.low.y + 0.3, middle.z))
		at.append(Vector3(middle.x, cell.high.y - 0.2, middle.z))
	return at


func _loaded() -> bool:
	if StillPoints.native_water() != null:
		return true
	assert_false(
		OS.get_environment("SINKING_NATIVE_REQUIRED") == "1",
		"the extension is required here but not loaded (make native)"
	)
	pass_test("the game's extension is not loaded: nothing to hold it to")
	return false
